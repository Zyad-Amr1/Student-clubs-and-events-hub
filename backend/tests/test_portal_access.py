"""Club-scoped portal access must be computed from current DB grants, not client input."""

from sqlalchemy import text

from test_event_creation import (
    draft_client,
    draft_test_engine,
    grant_admin,
    scenario,
    synthetic_test_password_hash,
)


def route(client, headers=None):
    return client.get(
        "/api/v1/auth/club-admin/clubs",
        headers=headers or {},
    )


def test_member_sees_only_active_assigned_clubs(
    draft_client, draft_test_engine, scenario
):
    ids = scenario["ids"]
    grant_admin(draft_test_engine, ids["club"], ids["owner"])
    grant_admin(draft_test_engine, ids["inactive"], ids["owner"])
    response = route(draft_client, scenario["headers"]["owner"])
    assert response.status_code == 200, response.text
    assert response.json() == {
        "clubs": [
            {
                "id": str(ids["club"]),
                "name": "Authorized BDD Robotics Club",
            }
        ]
    }
    assert "password" not in response.text
    assert "user_id" not in response.text
    assert "is_active" not in response.text


def test_student_without_membership_cannot_enter_admin_portal(draft_client, scenario):
    assert route(draft_client, scenario["headers"]["student"]).status_code == 403


def test_student_affairs_cannot_claim_club_admin_even_when_assigned(
    draft_client, draft_test_engine, scenario
):
    ids = scenario["ids"]
    grant_admin(draft_test_engine, ids["club"], ids["affairs"])
    assert route(draft_client, scenario["headers"]["affairs"]).status_code == 403


def test_missing_and_invalid_jwt_are_rejected(draft_client, scenario):
    assert route(draft_client).status_code == 401
    assert route(
        draft_client, {"Authorization": "Bearer invalid"}
    ).status_code == 401


def test_revoked_grant_immediately_revokes_admin_portal_access(
    draft_client, draft_test_engine, scenario
):
    ids = scenario["ids"]
    grant_admin(draft_test_engine, ids["club"], ids["owner"])
    assert route(draft_client, scenario["headers"]["owner"]).status_code == 200
    with draft_test_engine.begin() as connection:
        connection.execute(
            text("DELETE FROM club_administrators WHERE club_id=:c AND user_id=:u"),
            {"c": ids["club"], "u": ids["owner"]},
        )
    assert route(draft_client, scenario["headers"]["owner"]).status_code == 403


def test_an_inactive_club_only_does_not_grant_portal_access(
    draft_client, draft_test_engine, scenario
):
    ids = scenario["ids"]
    grant_admin(draft_test_engine, ids["inactive"], ids["owner"])
    assert route(draft_client, scenario["headers"]["owner"]).status_code == 403


def test_other_memberships_and_spoofed_query_cannot_expand_scope(
    draft_client, draft_test_engine, scenario
):
    ids = scenario["ids"]
    grant_admin(draft_test_engine, ids["club"], ids["owner"])
    result = draft_client.get(
        f"/api/v1/auth/club-admin/clubs?club_id={ids['other']}&role=student_affairs",
        headers=scenario["headers"]["owner"],
    )
    assert result.status_code == 200
    assert [club["id"] for club in result.json()["clubs"]] == [str(ids["club"])]


def test_protected_affairs_endpoint_still_enforces_global_account_type(
    draft_client, scenario
):
    assert draft_client.get(
        "/api/v1/auth/student-affairs",
        headers=scenario["headers"]["affairs"],
    ).status_code == 200
    assert draft_client.get(
        "/api/v1/auth/student-affairs",
        headers=scenario["headers"]["owner"],
    ).status_code == 403
