from concurrent.futures import ThreadPoolExecutor
from datetime import datetime, timedelta, timezone
from threading import Barrier

from fastapi.testclient import TestClient

from app.main import app
from test_event_creation import (
    draft_client, draft_test_engine, grant_admin, scenario, synthetic_test_password_hash,
)
from test_event_reservations import add_student


def test_interview_booking_capacity_fcfs_and_partial_publication(
    draft_client, draft_test_engine, scenario, synthetic_test_password_hash,
):
    club = scenario["ids"]["club"]
    owner = scenario["headers"]["owner"]
    first = scenario["headers"]["student"]
    _, second = add_student(draft_client, draft_test_engine, synthetic_test_password_hash, "interview-second")
    _, third = add_student(draft_client, draft_test_engine, synthetic_test_password_hash, "interview-third")
    grant_admin(draft_test_engine, club, scenario["ids"]["owner"])
    admin = f"/api/v1/club-admin/clubs/{club}"
    days = f"{admin}/interview-days"
    date = datetime.now(timezone.utc).date() + timedelta(days=2)
    day_url = f"{days}/by-date/{date}"
    setup = {"capacity": 1, "duration_minutes": 20, "periods": [
        {"start_minute": 540, "end_minute": 560},
        {"start_minute": 600, "end_minute": 620},
    ]}
    assert draft_client.put(day_url, headers=first, json=setup).status_code == 404
    assert draft_client.put(day_url, headers=owner, json={**setup, "periods": [
        {"start_minute": 540, "end_minute": 580},
        {"start_minute": 550, "end_minute": 590},
    ]}).status_code == 422
    day = draft_client.put(day_url, headers=owner, json=setup)
    assert day.status_code == 200, day.text
    day_id = day.json()["id"]
    assert draft_client.get(days, headers=owner).json()["days"][0]["id"] == day_id
    schedule_path = f"{days}/{day_id}/schedule"

    paths = []
    for credentials in (first, second, third):
        created = draft_client.post(f"/api/v1/clubs/{club}/applications", headers=credentials)
        assert created.status_code == 201, created.text
        application = created.json()["id"]
        path = f"/api/v1/me/applications/{application}/interview"
        assert draft_client.put(path, headers=credentials, json={"day_id": day_id}).status_code == 409
        assert draft_client.post(f"{admin}/applications/{application}/decision", headers=owner,
                                 json={"decision": "interview_required"}).status_code == 200
        paths.append(path)

    barrier = Barrier(2, timeout=10)

    def select_day(index, headers):
        with TestClient(app) as client:
            barrier.wait()
            return client.put(paths[index], headers=headers, json={"day_id": day_id})

    with ThreadPoolExecutor(max_workers=2) as pool:
        actions = [pool.submit(select_day, index, headers)
                   for index, headers in enumerate((first, second))]
        responses = [action.result(timeout=20) for action in actions]
    assert sorted(item.status_code for item in responses) == [200, 409]
    winner = next(i for i, response in enumerate(responses) if response.status_code == 200)
    assert responses[winner].json()["starts_at"] is None
    assert draft_client.delete(paths[winner], headers=(first, second)[winner]).status_code == 204
    alternate = draft_client.put(f"{days}/by-date/{date + timedelta(days=1)}",
                                  headers=owner, json=setup).json()
    assert draft_client.put(paths[0], headers=first, json={"day_id": alternate["id"]}).status_code == 200
    assert draft_client.put(paths[0], headers=first, json={"day_id": day_id}).status_code == 200
    assert draft_client.put(paths[1], headers=second, json={"day_id": alternate["id"]}).status_code == 200

    assert draft_client.put(day_url, headers=owner, json={**setup, "capacity": 3}).status_code == 200
    for index, credentials in ((2, third), (1, second), (0, first)):
        response = draft_client.put(paths[index], headers=credentials, json={"day_id": day_id})
        assert response.status_code == 200, response.text
        assert response.json()["status"] == "unscheduled"
    assert draft_client.get(paths[0], headers=second).status_code == 404
    assert draft_client.put(day_url, headers=owner, json=setup).status_code == 409
    preview = draft_client.get(schedule_path, headers=owner).json()["slots"]
    assert [row["status"] for row in preview] == ["proposed", "proposed", "unscheduled"]
    assert preview[0]["applicant_name"] == "Synthetic Regular Student"
    assert preview[1]["applicant_name"] == "Additional Student interview-second"
    assert datetime.fromisoformat(preview[0]["starts_at"]).astimezone(timezone.utc).hour == 9
    assert datetime.fromisoformat(preview[1]["starts_at"]).astimezone(timezone.utc).hour == 10

    def publish(slot):
        return {"appointments": [{key: slot[key] for key in ("selection_id", "starts_at", "ends_at")}]}

    assert draft_client.get("/api/v1/me/interview-appointments", headers=first).json()["appointments"] == []
    assert draft_client.post(schedule_path, headers=owner, json=publish(preview[0])).status_code == 204
    appointments = draft_client.get("/api/v1/me/interview-appointments", headers=first).json()["appointments"]
    assert len(appointments) == 1 and appointments[0]["notice"]
    assert draft_client.get("/api/v1/me/interview-appointments", headers=second).json()["appointments"] == []
    assert draft_client.delete(paths[0], headers=first).status_code == 409
    box = draft_client.get(paths[0], headers=first).json()["booking"]
    assert box["status"] == "confirmed"
    assert draft_client.put(day_url, headers=owner, json={**setup, "capacity": 3, "periods": []}).status_code == 409

    rerun = draft_client.get(schedule_path, headers=owner).json()["slots"]
    assert rerun[0]["status"] == "confirmed"
    assert datetime.fromisoformat(rerun[0]["starts_at"]) == datetime.fromisoformat(preview[0]["starts_at"])
    assert rerun[1]["status"] == "proposed"
    assert rerun[2]["status"] == "unscheduled"
    assert draft_client.post(schedule_path, headers=owner, json=publish(rerun[1])).status_code == 204

    other = scenario["ids"]["other"]
    grant_admin(draft_test_engine, other, scenario["ids"]["owner"])
    other_admin = f"/api/v1/club-admin/clubs/{other}"
    other_days = f"{other_admin}/interview-days"
    other_day = draft_client.put(f"{other_days}/by-date/{date}", headers=owner,
                                 json={**setup, "periods": setup["periods"][:1]}).json()["id"]
    other_application = draft_client.post(f"/api/v1/clubs/{other}/applications",
                                          headers=first).json()["id"]
    assert draft_client.post(f"{other_admin}/applications/{other_application}/decision",
                             headers=owner, json={"decision": "interview_required"}).status_code == 200
    assert draft_client.put(f"/api/v1/me/applications/{other_application}/interview",
                            headers=first, json={"day_id": other_day}).status_code == 200
    other_schedule = draft_client.get(f"{other_days}/{other_day}/schedule", headers=owner).json()
    assert other_schedule["slots"][0]["status"] == "unscheduled"
