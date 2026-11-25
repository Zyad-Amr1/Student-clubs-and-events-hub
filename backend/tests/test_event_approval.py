"""CAMP-12/13 PostgreSQL-backed Student Affairs review and publication tests.

Runs only with the isolated, non-default-port test database in test_event_creation.
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


@pytest.fixture
def pending_event(draft_client, draft_test_engine, scenario):
    ids, headers = scenario["ids"], scenario["headers"]
    grant_admin(draft_test_engine, ids["club"], ids["owner"])
    creation = draft_client.post(
        f"/api/v1/clubs/{ids['club']}/events",
        json=payload(), headers=headers["owner"],
    )
    assert creation.status_code == 201, creation.text
    event_id = creation.json()["id"]
    submitted = draft_client.post(
        f"/api/v1/clubs/{ids['club']}/events/{event_id}/submit",
        headers=headers["owner"],
    )
    assert submitted.status_code == 200, submitted.text
    assert submitted.json()["approval_status"] == "pending"
    assert submitted.json()["is_published"] is False
    return event_id


def decide(client, event_id, headers, decision):
    return client.post(
        f"/api/v1/student-affairs/events/{event_id}/review",
        headers=headers, json={"decision": decision},
    )


def queue(client, headers, query=""):
    return client.get(f"/api/v1/student-affairs/events/pending{query}", headers=headers)


def details(client, ids, headers):
    return client.get(f"/api/v1/clubs/{ids['club']}", headers=headers)


def persisted(engine, event_id):
    with engine.connect() as connection:
        return connection.execute(
            text("SELECT approval_status,is_published FROM events WHERE id=:id"),
            {"id": event_id},
        ).one()


def test_approve_publishes_future_pending_event_and_public_details(
    draft_client, draft_test_engine, scenario, pending_event
):
    ids, headers = scenario["ids"], scenario["headers"]
    before = details(draft_client, ids, headers["student"])
    assert before.status_code == 200
    assert before.json()["events"] == []
    listed = queue(draft_client, headers["affairs"])
    assert listed.status_code == 200
    assert listed.json()["total"] == 1
    assert [e["id"] for e in listed.json()["events"]] == [pending_event]
    approved = decide(draft_client, pending_event, headers["affairs"], "approve")
    assert approved.status_code == 200, approved.text
    assert approved.json()["approval_status"] == "approved"
    assert approved.json()["is_published"] is True
    row = persisted(draft_test_engine, pending_event)
    assert (row.approval_status, row.is_published) == ("approved", True)
    after = details(draft_client, ids, headers["student"])
    assert after.status_code == 200
    assert [e["id"] for e in after.json()["events"]] == [pending_event]
    assert queue(draft_client, headers["affairs"]).json()["total"] == 0


def test_rejection_keeps_event_unpublished_and_hidden(
    draft_client, draft_test_engine, scenario, pending_event
):
    headers, ids = scenario["headers"], scenario["ids"]
    result = decide(draft_client, pending_event, headers["affairs"], "reject")
    assert result.status_code == 200, result.text
    assert result.json()["approval_status"] == "rejected"
    assert result.json()["is_published"] is False
    row = persisted(draft_test_engine, pending_event)
    assert (row.approval_status, row.is_published) == ("rejected", False)
    public = details(draft_client, ids, headers["student"])
    assert public.status_code == 200
    assert pending_event not in public.text
    assert public.json()["events"] == []
    assert queue(draft_client, headers["affairs"]).json()["total"] == 0


@pytest.mark.parametrize("role", ["owner", "student"])
def test_student_and_club_admin_cannot_view_queue_or_review(
    draft_client, draft_test_engine, scenario, pending_event, role
):
    headers = scenario["headers"][role]
    assert queue(draft_client, headers).status_code == 403
    assert decide(draft_client, pending_event, headers, "approve").status_code == 403
    assert persisted(draft_test_engine, pending_event).approval_status == "pending"


def test_missing_invalid_or_logged_out_affairs_session_denied(
    draft_client, draft_test_engine, scenario, pending_event
):
    assert queue(draft_client, {}).status_code == 401
    assert decide(draft_client, pending_event, {}, "approve").status_code == 401
    invalid = {"Authorization": "Bearer invalid"}
    assert queue(draft_client, invalid).status_code == 401
    assert decide(draft_client, pending_event, invalid, "reject").status_code == 401
    headers = scenario["headers"]["affairs"]
    assert draft_client.post("/api/v1/auth/logout", headers=headers).status_code == 204
    assert queue(draft_client, headers).status_code == 401
    assert decide(draft_client, pending_event, headers, "approve").status_code == 401
    assert persisted(draft_test_engine, pending_event).approval_status == "pending"


def test_cannot_directly_review_draft_and_cannot_repeat_decision(
    draft_client, draft_test_engine, scenario, pending_event
):
    ids, headers = scenario["ids"], scenario["headers"]
    draft = draft_client.post(
        f"/api/v1/clubs/{ids['club']}/events",
        json=payload(), headers=headers["owner"],
    )
    assert draft.status_code == 201
    assert decide(draft_client, draft.json()["id"], headers["affairs"], "approve").status_code == 409
    assert queue(draft_client, headers["affairs"]).json()["total"] == 1
    assert decide(draft_client, pending_event, headers["affairs"], "approve").status_code == 200
    assert decide(draft_client, pending_event, headers["affairs"], "reject").status_code == 409
    assert decide(draft_client, pending_event, headers["affairs"], "approve").status_code == 409


def test_rejected_events_cannot_be_reapproved(
    draft_client, draft_test_engine, scenario, pending_event
):
    headers = scenario["headers"]["affairs"]
    assert decide(draft_client, pending_event, headers, "reject").status_code == 200
    assert decide(draft_client, pending_event, headers, "approve").status_code == 409
    assert persisted(draft_test_engine, pending_event).is_published is False


@pytest.mark.parametrize("club_status,active", [
    ("pending", True), ("rejected", True), ("approved", False),
])
def test_unapproved_or_inactive_club_cannot_publish_pending_event(
    draft_client, draft_test_engine, scenario, pending_event, club_status, active
):
    ids, headers = scenario["ids"], scenario["headers"]
    with draft_test_engine.begin() as connection:
        connection.execute(
            text("UPDATE clubs SET approval_status=:s,is_active=:a WHERE id=:id"),
            {"s": club_status, "a": active, "id": ids["club"]},
        )
    assert queue(draft_client, headers["affairs"]).json()["total"] == 0
    response = decide(draft_client, pending_event, headers["affairs"], "approve")
    assert response.status_code == 404
    assert persisted(draft_test_engine, pending_event).approval_status == "pending"
    assert persisted(draft_test_engine, pending_event).is_published is False


def test_expired_pending_event_cannot_be_published(
    draft_client, draft_test_engine, scenario, pending_event
):
    start = datetime.now(timezone.utc) - timedelta(hours=3)
    with draft_test_engine.begin() as connection:
        connection.execute(text(
            "UPDATE events SET starts_at=:s,ends_at=:e WHERE id=:id"
        ), {"s": start, "e": start + timedelta(hours=2), "id": pending_event})
    response = decide(draft_client, pending_event, scenario["headers"]["affairs"], "approve")
    assert response.status_code == 422
    assert persisted(draft_test_engine, pending_event).approval_status == "pending"
    assert persisted(draft_test_engine, pending_event).is_published is False
    # Student Affairs can reject an expired submission, without publishing it.
    rejected = decide(draft_client, pending_event, scenario["headers"]["affairs"], "reject")
    assert rejected.status_code == 200
    assert rejected.json()["is_published"] is False


@pytest.mark.parametrize("bad", [
    {"decision": "approved"}, {"decision": "draft"},
    {"decision": "approve", "is_published": True},
    {}, [],
])
def test_review_input_must_only_contain_supported_decision(
    draft_client, draft_test_engine, scenario, pending_event, bad
):
    response = draft_client.post(
        f"/api/v1/student-affairs/events/{pending_event}/review",
        headers=scenario["headers"]["affairs"], json=bad,
    )
    assert response.status_code == 422
    assert persisted(draft_test_engine, pending_event).approval_status == "pending"


def test_queue_pagination_and_only_pending_filter(
    draft_client, draft_test_engine, scenario, pending_event
):
    headers, ids = scenario["headers"], scenario["ids"]
    draft = draft_client.post(
        f"/api/v1/clubs/{ids['club']}/events",
        json=payload(), headers=headers["owner"],
    )
    assert draft.status_code == 201
    result = queue(draft_client, headers["affairs"], "?page=1&page_size=1")
    assert result.status_code == 200
    assert result.json()["page"] == 1
    assert result.json()["page_size"] == 1
    assert result.json()["total"] == 1
    assert [x["id"] for x in result.json()["events"]] == [pending_event]
    empty_page = queue(draft_client, headers["affairs"], "?page=2&page_size=1")
    assert empty_page.status_code == 200
    assert empty_page.json()["events"] == []
    assert queue(draft_client, headers["affairs"], "?page=0").status_code == 422


def test_unknown_event_returns_404(draft_client, scenario):
    assert decide(draft_client, uuid4(), scenario["headers"]["affairs"], "approve").status_code == 404


def test_concurrent_review_decisions_have_one_winner(
    draft_client, draft_test_engine, scenario, pending_event
):
    barrier = Barrier(2, timeout=15)
    headers = scenario["headers"]["affairs"]

    def review(choice):
        with TestClient(app) as client:
            barrier.wait()
            result = decide(client, pending_event, headers, choice)
            return result.status_code, result.json()

    with ThreadPoolExecutor(max_workers=2) as pool:
        first = pool.submit(review, "approve")
        second = pool.submit(review, "reject")
        outcomes = [first.result(timeout=30), second.result(timeout=30)]

    assert sorted(x[0] for x in outcomes) == [200, 409], outcomes
    row = persisted(draft_test_engine, pending_event)
    assert row.approval_status in {"approved", "rejected"}
    assert row.is_published is (row.approval_status == "approved")


def test_review_openapi_requires_bearer_security():
    op = app.openapi()["paths"]["/api/v1/student-affairs/events/{event_id}/review"]["post"]
    assert op["security"] == [{"HTTPBearer": []}]
    assert {"200", "401", "403", "404", "409", "422"} <= set(op["responses"])
