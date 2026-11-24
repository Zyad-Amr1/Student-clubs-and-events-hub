"""CAMP-11: PostgreSQL-backed TDD for submitting drafts for Student Affairs approval.

The imported fixtures own the same disposable, non-default-port PostgreSQL setup as
CAMP-10. No test may target campusconnect_db or port 5432.
"""

from concurrent.futures import ThreadPoolExecutor
from datetime import datetime, timedelta, timezone
from threading import Barrier
from uuid import uuid4

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import text

from app.main import app
from test_event_creation import (
    draft_client,
    draft_test_engine,
    grant_admin,
    payload,
    scenario,
    synthetic_test_password_hash,
)


def submit(client, club_id, event_id, headers=None, **kwargs):
    return client.post(
        f"/api/v1/clubs/{club_id}/events/{event_id}/submit",
        headers=headers or {},
        **kwargs,
    )


@pytest.fixture
def owned_draft(draft_client, draft_test_engine, scenario):
    ids = scenario["ids"]
    grant_admin(draft_test_engine, ids["club"], ids["owner"])
    created = draft_client.post(
        f"/api/v1/clubs/{ids['club']}/events",
        json=payload(),
        headers=scenario["headers"]["owner"],
    )
    assert created.status_code == 201, created.text
    return created.json()


def state(engine, event_id):
    with engine.connect() as connection:
        return connection.execute(
            text(
                "SELECT approval_status, is_published, club_id, updated_at "
                "FROM events WHERE id = :event_id"
            ),
            {"event_id": event_id},
        ).one()


def assert_nonpublic(draft_client, scenario, event_id):
    club_id = scenario["ids"]["club"]
    response = draft_client.get(
        f"/api/v1/clubs/{club_id}",
        headers=scenario["headers"]["owner"],
    )
    assert response.status_code == 200, response.text
    assert response.json()["events"] == []
    assert response.json()["total"] == 0
    assert event_id not in response.text


def test_draft_submits_once_and_remains_unpublished(
    draft_client, draft_test_engine, scenario, owned_draft
):
    ids = scenario["ids"]
    before = state(draft_test_engine, owned_draft["id"])
    assert (before.approval_status, before.is_published) == ("draft", False)
    result = submit(
        draft_client, ids["club"], owned_draft["id"],
        scenario["headers"]["owner"],
    )
    assert result.status_code == 200, result.text
    body = result.json()
    assert set(body) == {
        "id", "club_id", "title", "description", "venue", "starts_at",
        "ends_at", "seat_capacity", "approval_status", "is_published",
        "created_at", "updated_at",
    }
    assert body["id"] == owned_draft["id"]
    assert body["club_id"] == str(ids["club"])
    assert body["approval_status"] == "pending"
    assert body["is_published"] is False
    assert datetime.fromisoformat(body["starts_at"].replace("Z", "+00:00")).tzinfo
    after = state(draft_test_engine, owned_draft["id"])
    assert (after.approval_status, after.is_published) == ("pending", False)
    assert after.updated_at >= before.updated_at
    assert_nonpublic(draft_client, scenario, owned_draft["id"])
    repeat = submit(
        draft_client, ids["club"], owned_draft["id"],
        scenario["headers"]["owner"],
    )
    assert repeat.status_code == 409
    assert state(draft_test_engine, owned_draft["id"]).approval_status == "pending"


def test_cross_club_submission_is_indistinguishable_from_missing_event(
    draft_client, draft_test_engine, scenario, owned_draft
):
    ids = scenario["ids"]
    wrong_club = submit(
        draft_client, ids["other"], owned_draft["id"],
        scenario["headers"]["owner"],
    )
    nonexistent = submit(
        draft_client, ids["club"], uuid4(),
        scenario["headers"]["owner"],
    )
    assert wrong_club.status_code == nonexistent.status_code == 404
    assert wrong_club.json() == nonexistent.json()
    assert state(draft_test_engine, owned_draft["id"]).approval_status == "draft"



def test_revoked_other_club_membership_does_not_authorize_submission(
    draft_client, draft_test_engine, scenario, owned_draft
):
    ids = scenario["ids"]
    grant_admin(draft_test_engine, ids["other"], ids["owner"])
    created = draft_client.post(
        f"/api/v1/clubs/{ids['other']}/events",
        json=payload(),
        headers=scenario["headers"]["owner"],
    )
    assert created.status_code == 201, created.text
    other_id = created.json()["id"]
    with draft_test_engine.begin() as connection:
        connection.execute(
            text(
                "DELETE FROM club_administrators "
                "WHERE club_id=:club AND user_id=:user"
            ),
            {"club": ids["other"], "user": ids["owner"]},
        )
    response = submit(
        draft_client, ids["other"], other_id,
        scenario["headers"]["owner"],
    )
    assert response.status_code == 404
    assert state(draft_test_engine, other_id).approval_status == "draft"
    assert state(draft_test_engine, owned_draft["id"]).approval_status == "draft"


def test_published_draft_cannot_be_submitted(
    draft_client, draft_test_engine, scenario, owned_draft
):
    with draft_test_engine.begin() as connection:
        connection.execute(
            text("UPDATE events SET is_published=true WHERE id=:id"),
            {"id": owned_draft["id"]},
        )
    result = submit(
        draft_client, scenario["ids"]["club"], owned_draft["id"],
        scenario["headers"]["owner"],
    )
    assert result.status_code == 409
    current = state(draft_test_engine, owned_draft["id"])
    assert current.approval_status == "draft"
    assert current.is_published is True
    assert_nonpublic(draft_client, scenario, owned_draft["id"])


def test_student_without_club_grant_cannot_submit(
    draft_client, draft_test_engine, scenario, owned_draft
):
    ids = scenario["ids"]
    response = submit(
        draft_client, ids["club"], owned_draft["id"],
        scenario["headers"]["student"],
    )
    assert response.status_code == 404
    assert state(draft_test_engine, owned_draft["id"]).approval_status == "draft"


def test_student_affairs_has_no_bypass_even_if_granted(
    draft_client, draft_test_engine, scenario, owned_draft
):
    ids = scenario["ids"]
    grant_admin(draft_test_engine, ids["club"], ids["affairs"])
    response = submit(
        draft_client, ids["club"], owned_draft["id"],
        scenario["headers"]["affairs"],
    )
    assert response.status_code == 403
    assert state(draft_test_engine, owned_draft["id"]).approval_status == "draft"


def test_missing_and_invalid_token_return_401(
    draft_client, draft_test_engine, scenario, owned_draft
):
    ids = scenario["ids"]
    assert submit(draft_client, ids["club"], owned_draft["id"]).status_code == 401
    invalid = submit(
        draft_client, ids["club"], owned_draft["id"],
        {"Authorization": "Bearer invalid-signature"},
    )
    assert invalid.status_code == 401
    assert state(draft_test_engine, owned_draft["id"]).approval_status == "draft"


def test_inactive_club_cannot_submit_even_with_own_grant(
    draft_client, draft_test_engine, scenario, owned_draft
):
    ids = scenario["ids"]
    with draft_test_engine.begin() as connection:
        connection.execute(
            text("UPDATE clubs SET is_active = false WHERE id = :id"),
            {"id": ids["club"]},
        )
    response = submit(
        draft_client, ids["club"], owned_draft["id"],
        scenario["headers"]["owner"],
    )
    assert response.status_code == 404
    assert state(draft_test_engine, owned_draft["id"]).approval_status == "draft"


def test_unknown_event_returns_404(draft_client, scenario, owned_draft):
    result = submit(
        draft_client, scenario["ids"]["club"], uuid4(),
        scenario["headers"]["owner"],
    )
    assert result.status_code == 404


@pytest.mark.parametrize("status_value", ["pending", "approved", "rejected"])
def test_only_draft_can_be_submitted(
    draft_client, draft_test_engine, scenario, owned_draft, status_value
):
    ids = scenario["ids"]
    with draft_test_engine.begin() as connection:
        connection.execute(
            text("UPDATE events SET approval_status=:state WHERE id=:id"),
            {"state": status_value, "id": owned_draft["id"]},
        )
    result = submit(
        draft_client, ids["club"], owned_draft["id"],
        scenario["headers"]["owner"],
    )
    assert result.status_code == 409
    current = state(draft_test_engine, owned_draft["id"])
    assert current.approval_status == status_value
    assert current.is_published is False


def test_expired_start_is_rejected_without_state_change(
    draft_client, draft_test_engine, scenario, owned_draft
):
    past_start = datetime.now(timezone.utc) - timedelta(days=2)
    with draft_test_engine.begin() as connection:
        connection.execute(
            text("UPDATE events SET starts_at=:start, ends_at=:end WHERE id=:id"),
            {
                "start": past_start,
                "end": past_start + timedelta(hours=2),
                "id": owned_draft["id"],
            },
        )
    result = submit(
        draft_client, scenario["ids"]["club"], owned_draft["id"],
        scenario["headers"]["owner"],
    )
    assert result.status_code == 422
    assert state(draft_test_engine, owned_draft["id"]).approval_status == "draft"


def test_unexpected_payload_cannot_approve_or_publish(
    draft_client, draft_test_engine, scenario, owned_draft
):
    result = submit(
        draft_client, scenario["ids"]["club"], owned_draft["id"],
        scenario["headers"]["owner"],
        json={"approval_status": "approved", "is_published": True},
    )
    assert result.status_code == 422
    assert result.json() == {"detail": "Request body is not allowed"}
    current = state(draft_test_engine, owned_draft["id"])
    assert current.approval_status == "draft"
    assert current.is_published is False



@pytest.mark.parametrize("unexpected_json", [{}, {"is_published": False}, []])
def test_any_request_body_is_rejected_without_state_change(
    draft_client, draft_test_engine, scenario, owned_draft, unexpected_json
):
    result = submit(
        draft_client, scenario["ids"]["club"], owned_draft["id"],
        scenario["headers"]["owner"],
        json=unexpected_json,
    )
    assert result.status_code == 422
    assert result.json() == {"detail": "Request body is not allowed"}
    current = state(draft_test_engine, owned_draft["id"])
    assert current.approval_status == "draft"
    assert current.is_published is False

def test_concurrent_submissions_have_single_winner(
    draft_client, draft_test_engine, scenario, owned_draft
):
    ids = scenario["ids"]
    barrier = Barrier(2, timeout=15)

    def attempt():
        with TestClient(app) as client:
            barrier.wait()
            response = submit(
                client, ids["club"], owned_draft["id"],
                scenario["headers"]["owner"],
            )
            return response.status_code, response.json()

    with ThreadPoolExecutor(max_workers=2) as executor:
        futures = [executor.submit(attempt) for _ in range(2)]
        outcomes = [future.result(timeout=30) for future in futures]

    assert sorted(code for code, _ in outcomes) == [200, 409], outcomes
    assert any(
        body.get("approval_status") == "pending" and body.get("is_published") is False
        for code, body in outcomes if code == 200
    )
    current = state(draft_test_engine, owned_draft["id"])
    assert current.approval_status == "pending"
    assert current.is_published is False
    assert_nonpublic(draft_client, scenario, owned_draft["id"])


def test_submit_endpoint_openapi_auth_contract():
    operation = app.openapi()["paths"]["/api/v1/clubs/{club_id}/events/{event_id}/submit"]["post"]
    assert operation["security"] == [{"HTTPBearer": []}]
    assert {"200", "401", "403", "404", "409", "422"} <= set(operation["responses"])
    assert {p["name"] for p in operation["parameters"]} == {"club_id", "event_id"}
