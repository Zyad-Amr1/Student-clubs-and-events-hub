from concurrent.futures import ThreadPoolExecutor
from datetime import datetime, timedelta, timezone
from threading import Barrier

from fastapi.testclient import TestClient
from sqlalchemy import text

from app.clubs import interview_router
from app.main import app
from test_event_creation import (
    draft_client, draft_test_engine, grant_admin, scenario, synthetic_test_password_hash,
)
from test_event_reservations import add_student


def setup_club(engine, scenario):
    club = scenario["ids"]["club"]
    grant_admin(engine, club, scenario["ids"]["owner"])
    return club, f"/api/v1/club-admin/clubs/{club}", scenario["headers"]["owner"]


def eligible(client, club, admin, owner, student):
    created = client.post(f"/api/v1/clubs/{club}/applications", headers=student)
    assert created.status_code == 201, created.text
    app_id = created.json()["id"]
    path = f"/api/v1/me/applications/{app_id}/interview"
    reviewed = client.post(f"{admin}/applications/{app_id}/decision",
                           headers=owner, json={"decision": "interview_required"})
    assert reviewed.status_code == 200, reviewed.text
    return path


def setup_day(client, admin, owner, day, periods, capacity=3):
    payload = {"capacity": capacity, "duration_minutes": 20, "periods": [
        {"start_minute": start, "end_minute": end} for start, end in periods
    ]}
    result = client.put(f"{admin}/interview-days/by-date/{day}", headers=owner, json=payload)
    assert result.status_code == 200, result.text
    return result.json()["id"], payload


def choose(client, path, student, day_id):
    return client.put(path, headers=student, json={"day_id": day_id})


def confirm(client, day_path, owner):
    slots = client.get(f"{day_path}/schedule", headers=owner).json()["slots"]
    appointments = [{key: row[key] for key in ("selection_id", "starts_at", "ends_at")}
                    for row in slots if row["status"] == "proposed"]
    result = client.post(f"{day_path}/schedule", headers=owner, json={"appointments": appointments})
    assert result.status_code == 204, result.text
    return appointments


def preview(client, day_path, owner, target):
    result = client.post(f"{day_path}/cancellation-preview", headers=owner, json=target)
    assert result.status_code == 200, result.text
    return result.json()


def test_expiry_new_day_notices_and_attendance(
    draft_client, draft_test_engine, scenario, synthetic_test_password_hash, monkeypatch,
):
    client = draft_client
    club, admin, owner = setup_club(draft_test_engine, scenario)
    student = scenario["headers"]["student"]
    _, second = add_student(client, draft_test_engine, synthetic_test_password_hash, "attendance-second")
    path = eligible(client, club, admin, owner, student)
    other_path = eligible(client, club, admin, owner, second)
    now = datetime.now(timezone.utc)
    date = now.date() + timedelta(days=2)
    day, payload = setup_day(client, admin, owner, date, [])
    assert choose(client, path, student, day).json()["status"] == "unscheduled"
    notice_url = "/api/v1/me/interview-notices"
    assert [row["kind"] for row in client.get(notice_url, headers=student).json()["notices"]] == ["day_posted"]
    assert client.get(notice_url, headers=owner).json()["notices"] == []
    assert client.put(f"{admin}/interview-days/by-date/{date}", headers=owner, json=payload).status_code == 200
    assert len(client.get(notice_url, headers=student).json()["notices"]) == 1

    now = datetime.combine(date + timedelta(days=1), datetime.min.time(), timezone.utc)
    monkeypatch.setattr(interview_router, "utcnow", lambda: now)
    state = client.get(path, headers=student).json()
    assert state["booking"]["status"] == "expired"
    assert state["booking"]["starts_at"] is None and state["days"] == []
    assert choose(client, path, student, day).status_code == 409
    schedule = f"{admin}/interview-days/{day}"
    expired_id = client.get(f"{schedule}/schedule", headers=owner).json()["slots"][0]["selection_id"]
    assert client.put(f"{schedule}/appointments/{expired_id}/attendance", headers=owner,
                      json={"status": "no_show"}).status_code == 409

    new_date = now.date() + timedelta(days=1)
    new_day, _ = setup_day(client, admin, owner, new_date, [(540, 580)])
    assert choose(client, path, student, new_day).status_code == 200
    assert choose(client, other_path, second, new_day).status_code == 200
    new_path = f"{admin}/interview-days/{new_day}"
    slots = confirm(client, new_path, owner)
    assert len(slots) == 2
    assert client.post(f"{new_path}/schedule", headers=owner, json={"appointments": slots}).status_code == 409
    assert [r["kind"] for r in client.get(notice_url, headers=student).json()["notices"]].count("confirmed") == 1

    attendance_urls = [f"{new_path}/appointments/{slot['selection_id']}/attendance" for slot in slots]
    assert client.put(attendance_urls[0], headers=owner, json={"status": "attended"}).status_code == 409
    assert client.put(attendance_urls[0], headers=student, json={"status": "attended"}).status_code == 404
    now = datetime.fromisoformat(slots[1]["ends_at"])
    for url, status in zip(attendance_urls, ("attended", "no_show"), strict=True):
        assert client.put(url, headers=owner, json={"status": status}).status_code == 204
    assert client.get(path, headers=student).json()["booking"]["status"] == "attended"
    assert client.get(other_path, headers=second).json()["booking"]["status"] == "no_show"
    assert client.get("/api/v1/me/memberships", headers=student).json()["applications"] == []
    with draft_test_engine.connect() as conn:
        assert conn.scalar(text("SELECT count(*) FROM interview_selections WHERE expired_at IS NOT NULL")) == 1


def test_cancellation_scopes_audit_and_selection_race(
    draft_client, draft_test_engine, scenario, synthetic_test_password_hash,
):
    client = draft_client
    club, admin, owner = setup_club(draft_test_engine, scenario)
    first = scenario["headers"]["student"]
    _, second = add_student(client, draft_test_engine, synthetic_test_password_hash, "cancel-second")
    _, third = add_student(client, draft_test_engine, synthetic_test_password_hash, "cancel-third")
    paths = [eligible(client, club, admin, owner, headers) for headers in (first, second, third)]
    date = datetime.now(timezone.utc).date() + timedelta(days=2)
    day, _ = setup_day(client, admin, owner, date, [(540, 560), (600, 620)])
    day_path = f"{admin}/interview-days/{day}"
    for path, headers in zip(paths[:2], (first, second), strict=True):
        assert choose(client, path, headers, day).status_code == 200
    appointments = confirm(client, day_path, owner)

    def cancel(target, token, reason="Campus closure"):
        return client.post(f"{day_path}/cancel", headers=owner, json={
            "target": target, "preview_token": token, "reason": reason,
        })

    period = {"scope": "period", "period": {"start_minute": 540, "end_minute": 560}}
    impact = preview(client, day_path, owner, period)
    assert len(impact["affected"]) == 1
    assert cancel(period, impact["preview_token"], "  ").status_code == 422
    assert cancel(period, impact["preview_token"]).json() == {"cancelled_count": 1}
    calendar = client.get("/api/v1/me/interview-appointments", headers=first).json()["appointments"]
    assert calendar[0]["status"] == "cancelled" and calendar[0]["cancellation_reason"] == "Campus closure"
    url = f"{day_path}/appointments/{appointments[0]['selection_id']}/attendance"
    assert client.put(url, headers=owner, json={"status": "no_show"}).status_code == 409

    appointment = {"scope": "appointment", "selection_id": appointments[1]["selection_id"]}
    impact = preview(client, day_path, owner, appointment)
    assert cancel(appointment, impact["preview_token"]).json() == {"cancelled_count": 1}
    assert cancel(appointment, impact["preview_token"]).status_code == 409
    assert choose(client, paths[0], first, day).json()["status"] == "unscheduled"
    all_day = {"scope": "day"}
    token = preview(client, day_path, owner, all_day)["preview_token"]
    assert client.post(f"{day_path}/cancellation-preview", headers=third, json=all_day).status_code == 404
    barrier = Barrier(2, timeout=10)

    def race(action):
        with TestClient(app) as api:
            barrier.wait()
            if action == "choose":
                return choose(api, paths[2], third, day)
            return api.post(f"{day_path}/cancel", headers=owner, json={
                "target": all_day, "preview_token": token, "reason": "Day cancelled",
            })

    with ThreadPoolExecutor(max_workers=2) as pool:
        results = list(pool.map(race, ["choose", "cancel"]))
    assert sorted(result.status_code for result in results) == [200, 409]
    if results[1].status_code == 409:
        fresh = preview(client, day_path, owner, all_day)
        assert {item["status"] for item in fresh["affected"]} == {"unscheduled"}
        assert cancel(all_day, fresh["preview_token"]).json() == {"cancelled_count": 2}
    assert client.get(paths[0], headers=first).json()["booking"]["status"] == "cancelled"
    assert client.get(paths[0], headers=first).json()["days"] == []
    assert choose(client, paths[0], first, day).status_code == 409
    assert client.get("/api/v1/me/applications", headers=first).json()["applications"][0]["status"] == "interview_required"
    notices = client.get("/api/v1/me/interview-notices", headers=first).json()["notices"]
    assert [notice["kind"] for notice in notices].count("cancelled") == 2
    with draft_test_engine.connect() as conn:
        assert conn.scalar(text("SELECT count(*) FROM interview_cancellations")) == 3
        assert conn.scalar(text("SELECT count(*) FROM interview_selections WHERE released_at IS NULL")) == 0


def test_archiving_club_cancels_interviews_without_rejecting_applications(
    draft_client, draft_test_engine, scenario,
):
    client = draft_client
    club, admin, owner = setup_club(draft_test_engine, scenario)
    student = scenario["headers"]["student"]
    application_path = eligible(client, club, admin, owner, student)
    date = datetime.now(timezone.utc).date() + timedelta(days=2)
    day, _ = setup_day(client, admin, owner, date, [(600, 620)])
    assert choose(client, application_path, student, day).json()["status"] == "unscheduled"
    day_path = f"{admin}/interview-days/{day}"
    appointments = confirm(client, day_path, owner)
    assert len(appointments) == 1

    club_path = f"/api/v1/student-affairs/clubs/{club}"
    preview = client.post(club_path + "/archive-preview", headers=scenario["headers"]["affairs"])
    assert preview.status_code == 200
    assert preview.json()["interview_days"][0]["students"] == 1
    archived = client.post(club_path + "/archive", headers=scenario["headers"]["affairs"], json={
        "reason": "Building closed", "preview_token": preview.json()["preview_token"],
    })
    assert archived.status_code == 200, archived.text
    calendar = client.get("/api/v1/me/interview-appointments", headers=student).json()["appointments"]
    assert calendar[0]["status"] == "cancelled"
    assert calendar[0]["cancellation_reason"] == "Building closed"
    app_state = client.get("/api/v1/me/applications", headers=student).json()["applications"][0]
    assert app_state["status"] == "interview_required"
    attendance = client.put(
        f"{day_path}/appointments/{appointments[0]['selection_id']}/attendance",
        headers=owner, json={"status": "no_show"},
    )
    assert attendance.status_code == 404
