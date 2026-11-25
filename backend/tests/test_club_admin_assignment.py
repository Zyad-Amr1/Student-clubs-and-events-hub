"""MVP contract: at most one club administrator, assigned only by Student Affairs.

Uses the existing disposable PostgreSQL fixture; never touches campusconnect_db.
"""
from concurrent.futures import ThreadPoolExecutor

import pytest
from sqlalchemy import text
from sqlalchemy.exc import IntegrityError

from test_event_creation import (
    draft_client,
    draft_test_engine,
    payload,
    post_event,
    scenario,
    synthetic_test_password_hash,
)


def assign(client, club_id, student_id, headers=None, **extra):
    return client.put(
        f"/api/v1/auth/student-affairs/clubs/{club_id}/administrator",
        headers=headers or {},
        json={"student_id": str(student_id), **extra},
    )


def assignments(engine, club_id):
    with engine.connect() as connection:
        return connection.execute(
            text(
                "SELECT user_id FROM club_administrators "
                "WHERE club_id = :club_id"
            ),
            {"club_id": club_id},
        ).scalars().all()


def test_affairs_assigns_an_existing_student_only_once(
    draft_client, draft_test_engine, scenario
):
    ids = scenario["ids"]
    response = assign(
        draft_client, ids["club"], ids["owner"], scenario["headers"]["affairs"]
    )
    assert response.status_code == 200, response.text
    assert response.json() == {
        "club_id": str(ids["club"]),
        "user_id": str(ids["owner"]),
    }
    assert [str(user_id) for user_id in assignments(draft_test_engine, ids["club"])] == [
        str(ids["owner"])
    ]
    repeated = assign(
        draft_client, ids["club"], ids["owner"], scenario["headers"]["affairs"]
    )
    assert repeated.status_code == 200
    assert repeated.json() == response.json()
    assert len(assignments(draft_test_engine, ids["club"])) == 1


def test_student_affairs_replaces_admin_atomically_and_old_admin_loses_access(
    draft_client, draft_test_engine, scenario
):
    ids = scenario["ids"]
    headers = scenario["headers"]
    assert assign(draft_client, ids["club"], ids["owner"], headers["affairs"]).status_code == 200
    assert post_event(draft_client, ids["club"], payload(), headers["owner"]).status_code == 201
    response = assign(draft_client, ids["club"], ids["student"], headers["affairs"])
    assert response.status_code == 200, response.text
    assert response.json()["user_id"] == str(ids["student"])
    assert [str(uid) for uid in assignments(draft_test_engine, ids["club"])] == [
        str(ids["student"])
    ]
    assert post_event(draft_client, ids["club"], payload(), headers["owner"]).status_code == 404
    assert post_event(draft_client, ids["club"], payload(), headers["student"]).status_code == 201


def test_student_and_club_admin_cannot_assign_privileges(
    draft_client, draft_test_engine, scenario
):
    ids, headers = scenario["ids"], scenario["headers"]
    for applicant in ("student", "owner"):
        response = assign(draft_client, ids["club"], ids["owner"], headers[applicant])
        assert response.status_code == 403
    assert assignments(draft_test_engine, ids["club"]) == []


def test_anonymous_and_invalid_jwt_cannot_assign(
    draft_client, draft_test_engine, scenario
):
    ids = scenario["ids"]
    assert assign(draft_client, ids["club"], ids["owner"]).status_code == 401
    assert assign(
        draft_client, ids["club"], ids["owner"], {"Authorization": "Bearer fake"}
    ).status_code == 401
    assert assignments(draft_test_engine, ids["club"]) == []


def test_student_affairs_account_cannot_become_a_club_admin(
    draft_client, draft_test_engine, scenario
):
    ids, headers = scenario["ids"], scenario["headers"]
    response = assign(draft_client, ids["club"], ids["affairs"], headers["affairs"])
    assert response.status_code == 422
    assert assignments(draft_test_engine, ids["club"]) == []


def test_inactive_target_student_is_not_eligible(
    draft_client, draft_test_engine, scenario
):
    ids, headers = scenario["ids"], scenario["headers"]
    with draft_test_engine.begin() as connection:
        connection.execute(
            text("UPDATE users SET is_active = false WHERE id = :id"),
            {"id": ids["owner"]},
        )
    response = assign(draft_client, ids["club"], ids["owner"], headers["affairs"])
    assert response.status_code == 422
    assert assignments(draft_test_engine, ids["club"]) == []


def test_unknown_or_inactive_club_cannot_receive_a_grant(
    draft_client, draft_test_engine, scenario
):
    from uuid import uuid4

    ids, headers = scenario["ids"], scenario["headers"]
    assert assign(
        draft_client, uuid4(), ids["owner"], headers["affairs"]
    ).status_code == 404
    assert assign(
        draft_client, ids["inactive"], ids["owner"], headers["affairs"]
    ).status_code == 404
    assert assignments(draft_test_engine, ids["inactive"]) == []


def test_unknown_student_and_unexpected_role_fields_are_rejected(
    draft_client, draft_test_engine, scenario
):
    from uuid import uuid4

    ids, headers = scenario["ids"], scenario["headers"]
    assert assign(
        draft_client, ids["club"], uuid4(), headers["affairs"]
    ).status_code == 422
    assert assign(
        draft_client,
        ids["club"],
        ids["owner"],
        headers["affairs"],
        account_type="student_affairs",
    ).status_code == 422
    assert assignments(draft_test_engine, ids["club"]) == []


def test_database_prevents_a_second_admin_for_same_club(
    draft_client, draft_test_engine, scenario
):
    ids, headers = scenario["ids"], scenario["headers"]
    assert assign(
        draft_client, ids["club"], ids["owner"], headers["affairs"]
    ).status_code == 200
    with pytest.raises(IntegrityError):
        with draft_test_engine.begin() as connection:
            connection.execute(
                text(
                    "INSERT INTO club_administrators (club_id, user_id) "
                    "VALUES (:club_id, :user_id)"
                ),
                {"club_id": ids["club"], "user_id": ids["student"]},
            )
    assert len(assignments(draft_test_engine, ids["club"])) == 1


def test_one_student_can_administer_different_clubs_with_independent_scopes(
    draft_client, draft_test_engine, scenario
):
    ids, headers = scenario["ids"], scenario["headers"]
    assert assign(
        draft_client, ids["club"], ids["owner"], headers["affairs"]
    ).status_code == 200
    assert assign(
        draft_client, ids["other"], ids["owner"], headers["affairs"]
    ).status_code == 200
    assert len(assignments(draft_test_engine, ids["club"])) == 1
    assert len(assignments(draft_test_engine, ids["other"])) == 1
    assert post_event(
        draft_client, ids["club"], payload(), headers["student"]
    ).status_code == 404


def test_simultaneous_replacements_leave_exactly_one_admin(
    draft_client, draft_test_engine, scenario
):
    ids, headers = scenario["ids"], scenario["headers"]
    with ThreadPoolExecutor(max_workers=2) as pool:
        one = pool.submit(
            assign, draft_client, ids["club"], ids["owner"], headers["affairs"]
        )
        two = pool.submit(
            assign, draft_client, ids["club"], ids["student"], headers["affairs"]
        )
        statuses = [one.result().status_code, two.result().status_code]
    assert statuses == [200, 200]
    final = assignments(draft_test_engine, ids["club"])
    assert len(final) == 1
    assert str(final[0]) in {str(ids["owner"]), str(ids["student"])}
