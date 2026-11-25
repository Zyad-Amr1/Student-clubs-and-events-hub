"""PostgreSQL-backed CAMP-14/17 student event reservation tests."""

from concurrent.futures import ThreadPoolExecutor
from datetime import datetime, timedelta, timezone
from threading import Barrier
from uuid import uuid4

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import text
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.main import app
from app.models.user import AccountType, User
from test_event_creation import (
    draft_client,
    draft_test_engine,
    grant_admin,
    payload,
    scenario,
    synthetic_test_password_hash,
)


@pytest.fixture
def published_event(draft_client, draft_test_engine, scenario):
    ids, headers = scenario["ids"], scenario["headers"]
    grant_admin(draft_test_engine, ids["club"], ids["owner"])
    event_payload = payload()
    event_payload["seat_capacity"] = 1
    created = draft_client.post(
        f"/api/v1/clubs/{ids['club']}/events",
        json=event_payload,
        headers=headers["owner"],
    )
    assert created.status_code == 201, created.text
    event_id = created.json()["id"]
    submitted = draft_client.post(
        f"/api/v1/clubs/{ids['club']}/events/{event_id}/submit",
        headers=headers["owner"],
    )
    assert submitted.status_code == 200, submitted.text
    approved = draft_client.post(
        f"/api/v1/student-affairs/events/{event_id}/review",
        headers=headers["affairs"],
        json={"decision": "approve"},
    )
    assert approved.status_code == 200, approved.text
    assert approved.json()["is_published"] is True
    return approved.json()


def post_reservation(client, event_id, headers):
    return client.post(
        f"/api/v1/events/{event_id}/reservations", headers=headers
    )


def cancel_reservation(client, event_id, headers):
    return client.delete(
        f"/api/v1/events/{event_id}/reservations", headers=headers
    )


def add_student(client, engine, password_hash, suffix):
    with Session(engine) as session:
        student = User(
            full_name=f"Additional Student {suffix}",
            email=f"reservation-{suffix}@example.edu",
            university_id=f"RESERVATION-{suffix.upper()}",
            password_hash=password_hash,
            account_type=AccountType.STUDENT,
        )
        session.add(student)
        session.flush()
        student_id = student.id
        session.commit()

    password = "SyntheticEventTestPassword#123"
    login = client.post(
        "/api/v1/auth/login",
        json={"email": f"reservation-{suffix}@example.edu", "password": password},
    )
    assert login.status_code == 200, login.text
    return student_id, {"Authorization": f"Bearer {login.json()['access_token']}"}


def reservations_for(engine, event_id):
    with engine.connect() as connection:
        return connection.execute(
            text(
                "SELECT user_id, status FROM event_reservations "
                "WHERE event_id=:event_id ORDER BY id"
            ),
            {"event_id": event_id},
        ).all()


def test_openapi_documents_student_reservation_contract():
    paths = app.openapi()["paths"]
    event_path = "/api/v1/events/{event_id}/reservations"
    assert {"post", "delete"} <= set(paths[event_path])
    assert "get" in paths["/api/v1/me/reservations"]
    assert paths[event_path]["post"]["security"] == [{"HTTPBearer": []}]
    assert paths["/api/v1/me/reservations"]["get"]["security"] == [
        {"HTTPBearer": []}
    ]


def test_student_reserves_published_event_and_duplicate_is_rejected(
    draft_client, draft_test_engine, scenario, published_event
):
    event_id = published_event["id"]
    headers = scenario["headers"]["student"]

    first = post_reservation(draft_client, event_id, headers)
    assert first.status_code == 201, first.text
    assert first.json()["status"] == "confirmed"
    assert first.json()["waitlist_position"] is None
    assert first.json()["event"]["title"] == published_event["title"]

    duplicate = post_reservation(draft_client, event_id, headers)
    assert duplicate.status_code == 409
    assert len(reservations_for(draft_test_engine, event_id)) == 1
    with pytest.raises(IntegrityError):
        with draft_test_engine.begin() as connection:
            connection.execute(
                text(
                    "INSERT INTO event_reservations (event_id,user_id,status) "
                    "VALUES (:event_id,:user_id,'confirmed')"
                ),
                {"event_id": event_id, "user_id": scenario["ids"]["student"]},
            )


def test_capacity_is_enforced_for_concurrent_students(
    draft_test_engine, scenario, published_event
):
    event_id = published_event["id"]
    barrier = Barrier(2, timeout=15)
    headers = [scenario["headers"]["owner"], scenario["headers"]["student"]]

    def register(student_headers):
        with TestClient(app) as client:
            barrier.wait()
            response = post_reservation(client, event_id, student_headers)
            return response.status_code, response.json()

    with ThreadPoolExecutor(max_workers=2) as pool:
        results = list(pool.map(register, headers))

    assert [status for status, _ in results] == [201, 201]
    assert sorted(body["status"] for _, body in results) == ["confirmed", "waitlisted"]
    assert sum(row.status == "confirmed" for row in reservations_for(draft_test_engine, event_id)) == 1


def test_concurrent_duplicate_rsvps_create_only_one_active_reservation(
    draft_test_engine, scenario, published_event
):
    event_id = published_event["id"]
    barrier = Barrier(2, timeout=15)
    headers = scenario["headers"]["student"]

    def register():
        with TestClient(app) as client:
            barrier.wait()
            response = post_reservation(client, event_id, headers)
            return response.status_code

    with ThreadPoolExecutor(max_workers=2) as pool:
        outcomes = list(pool.map(lambda _: register(), range(2)))

    assert sorted(outcomes) == [201, 409]
    assert len(reservations_for(draft_test_engine, event_id)) == 1


def test_fifo_waitlist_promotion_is_atomic_and_returns_to_next_student(
    draft_client,
    draft_test_engine,
    scenario,
    published_event,
    synthetic_test_password_hash,
):
    event_id = published_event["id"]
    owner = scenario["headers"]["owner"]
    first_waiter = scenario["headers"]["student"]
    _, second_waiter = add_student(
        draft_client, draft_test_engine, synthetic_test_password_hash, "second"
    )

    assert post_reservation(draft_client, event_id, owner).json()["status"] == "confirmed"
    first = post_reservation(draft_client, event_id, first_waiter)
    second = post_reservation(draft_client, event_id, second_waiter)
    assert first.json()["status"] == "waitlisted"
    assert first.json()["waitlist_position"] == 1
    assert second.json()["status"] == "waitlisted"
    assert second.json()["waitlist_position"] == 2
    assert post_reservation(draft_client, event_id, first_waiter).status_code == 409

    assert cancel_reservation(draft_client, event_id, owner).status_code == 204
    first_state = draft_client.get("/api/v1/me/reservations", headers=first_waiter).json()
    second_state = draft_client.get("/api/v1/me/reservations", headers=second_waiter).json()
    assert first_state["reservations"][0]["status"] == "confirmed"
    assert second_state["reservations"][0]["status"] == "waitlisted"
    assert second_state["reservations"][0]["waitlist_position"] == 1
    assert sum(row.status == "confirmed" for row in reservations_for(draft_test_engine, event_id)) == 1

    assert cancel_reservation(draft_client, event_id, first_waiter).status_code == 204
    second_state = draft_client.get("/api/v1/me/reservations", headers=second_waiter).json()
    assert second_state["reservations"][0]["status"] == "confirmed"


def test_concurrent_cancellations_promote_distinct_waiters_without_overbooking(
    draft_client,
    draft_test_engine,
    scenario,
    published_event,
    synthetic_test_password_hash,
):
    event_id = published_event["id"]
    with draft_test_engine.begin() as connection:
        connection.execute(
            text("UPDATE events SET seat_capacity=2 WHERE id=:id"),
            {"id": event_id},
        )
    owner = scenario["headers"]["owner"]
    student = scenario["headers"]["student"]
    first_waiter_id, first_waiter = add_student(
        draft_client, draft_test_engine, synthetic_test_password_hash, "concurrent-first"
    )
    second_waiter_id, second_waiter = add_student(
        draft_client, draft_test_engine, synthetic_test_password_hash, "concurrent-second"
    )
    assert post_reservation(draft_client, event_id, owner).json()["status"] == "confirmed"
    assert post_reservation(draft_client, event_id, student).json()["status"] == "confirmed"
    assert post_reservation(draft_client, event_id, first_waiter).json()["status"] == "waitlisted"
    assert post_reservation(draft_client, event_id, second_waiter).json()["status"] == "waitlisted"

    barrier = Barrier(2, timeout=15)
    def cancel(student_headers):
        with TestClient(app) as client:
            barrier.wait()
            return cancel_reservation(client, event_id, student_headers).status_code

    with ThreadPoolExecutor(max_workers=2) as pool:
        outcomes = list(pool.map(cancel, [owner, student]))

    assert outcomes == [204, 204]
    rows = reservations_for(draft_test_engine, event_id)
    assert len(rows) == 2
    assert all(row.status == "confirmed" for row in rows)
    assert {str(row.user_id) for row in rows} == {
        str(first_waiter_id),
        str(second_waiter_id),
    }


def test_promotion_skips_a_waitlisted_account_that_is_no_longer_active(
    draft_client,
    draft_test_engine,
    scenario,
    published_event,
    synthetic_test_password_hash,
):
    event_id = published_event["id"]
    owner = scenario["headers"]["owner"]
    first_waiter_id = scenario["ids"]["student"]
    first_waiter = scenario["headers"]["student"]
    second_waiter_id, second_waiter = add_student(
        draft_client, draft_test_engine, synthetic_test_password_hash, "active-second"
    )
    assert post_reservation(draft_client, event_id, owner).json()["status"] == "confirmed"
    assert post_reservation(draft_client, event_id, first_waiter).json()["status"] == "waitlisted"
    assert post_reservation(draft_client, event_id, second_waiter).json()["status"] == "waitlisted"

    with draft_test_engine.begin() as connection:
        connection.execute(
            text("UPDATE users SET is_active=false WHERE id=:id"),
            {"id": first_waiter_id},
        )
    assert cancel_reservation(draft_client, event_id, owner).status_code == 204
    rows = reservations_for(draft_test_engine, event_id)
    statuses = {str(row.user_id): row.status for row in rows}
    assert statuses[str(first_waiter_id)] == "waitlisted"
    assert statuses[str(second_waiter_id)] == "confirmed"


def test_started_event_cancellation_does_not_promote_into_a_past_event(
    draft_client, draft_test_engine, scenario, published_event
):
    event_id = published_event["id"]
    owner = scenario["headers"]["owner"]
    waiter = scenario["headers"]["student"]
    assert post_reservation(draft_client, event_id, owner).json()["status"] == "confirmed"
    assert post_reservation(draft_client, event_id, waiter).json()["status"] == "waitlisted"
    with draft_test_engine.begin() as connection:
        connection.execute(
            text("UPDATE events SET starts_at=:past WHERE id=:id"),
            {"id": event_id, "past": datetime.now(timezone.utc) - timedelta(hours=1)},
        )

    assert cancel_reservation(draft_client, event_id, owner).status_code == 204
    rows = reservations_for(draft_test_engine, event_id)
    assert len(rows) == 1
    assert rows[0].status == "waitlisted"


def test_cancelling_waitlist_entry_keeps_confirmed_seat_and_is_owner_scoped(
    draft_client,
    draft_test_engine,
    scenario,
    published_event,
    synthetic_test_password_hash,
):
    event_id = published_event["id"]
    owner = scenario["headers"]["owner"]
    waiter = scenario["headers"]["student"]
    _, stranger = add_student(
        draft_client, draft_test_engine, synthetic_test_password_hash, "stranger"
    )
    assert post_reservation(draft_client, event_id, owner).json()["status"] == "confirmed"
    assert post_reservation(draft_client, event_id, waiter).json()["status"] == "waitlisted"

    assert cancel_reservation(draft_client, event_id, stranger).status_code == 404
    assert cancel_reservation(draft_client, event_id, waiter).status_code == 204
    rows = reservations_for(draft_test_engine, event_id)
    assert len(rows) == 1
    assert rows[0].status == "confirmed"
    assert str(rows[0].user_id) == str(scenario["ids"]["owner"])


def test_reservation_list_is_current_student_scoped_and_contains_event_details(
    draft_client, scenario, published_event
):
    event_id = published_event["id"]
    assert post_reservation(
        draft_client, event_id, scenario["headers"]["owner"]
    ).status_code == 201
    assert post_reservation(
        draft_client, event_id, scenario["headers"]["student"]
    ).json()["status"] == "waitlisted"

    result = draft_client.get(
        "/api/v1/me/reservations", headers=scenario["headers"]["student"]
    )
    assert result.status_code == 200
    reservation = result.json()["reservations"][0]
    assert reservation["event_id"] == event_id
    assert reservation["status"] == "waitlisted"
    assert reservation["waitlist_position"] == 1
    assert reservation["event"] == {
        "id": event_id,
        "club_id": published_event["club_id"],
        "title": published_event["title"],
        "description": published_event["description"],
        "venue": published_event["venue"],
        "starts_at": published_event["starts_at"],
        "ends_at": published_event["ends_at"],
        "seat_capacity": published_event["seat_capacity"],
        "cancelled_at": None,
        "cancellation_reason": None,
    }
    owner_result = draft_client.get(
        "/api/v1/me/reservations", headers=scenario["headers"]["owner"]
    )
    assert owner_result.json()["reservations"][0]["status"] == "confirmed"


@pytest.mark.parametrize(
    ("change", "sets_past"),
    [
        ("UPDATE events SET approval_status='pending',is_published=false WHERE id=:id", False),
        ("UPDATE events SET is_published=false WHERE id=:id", False),
        ("UPDATE events SET starts_at=:past WHERE id=:id", True),
    ],
)
def test_only_approved_published_future_events_accept_reservations(
    draft_client, draft_test_engine, scenario, published_event, change, sets_past
):
    event_id = published_event["id"]
    parameters = {"id": event_id}
    if sets_past:
        parameters["past"] = datetime.now(timezone.utc) - timedelta(days=1)
    with draft_test_engine.begin() as connection:
        connection.execute(text(change), parameters)

    response = post_reservation(
        draft_client, event_id, scenario["headers"]["student"]
    )
    assert response.status_code == 404
    assert reservations_for(draft_test_engine, event_id) == []


def test_missing_or_non_student_identity_cannot_reserve(
    draft_client, draft_test_engine, scenario, published_event
):
    event_id = published_event["id"]
    assert post_reservation(draft_client, event_id, {}).status_code == 401
    assert draft_client.get("/api/v1/me/reservations").status_code == 401
    assert post_reservation(
        draft_client, event_id, scenario["headers"]["affairs"]
    ).status_code == 403
    assert draft_client.get(
        "/api/v1/me/reservations", headers=scenario["headers"]["affairs"]
    ).status_code == 403
    assert post_reservation(draft_client, uuid4(), scenario["headers"]["student"]).status_code == 404
    assert reservations_for(draft_test_engine, event_id) == []
