from concurrent.futures import ThreadPoolExecutor
from threading import Barrier

from fastapi.testclient import TestClient

from app.main import app
from test_event_creation import (
    draft_client, draft_test_engine, scenario, synthetic_test_password_hash,
)


def test_club_request_workflow_and_scope(draft_client, scenario):
    headers = scenario["headers"]
    student, other, affairs = headers["student"], headers["owner"], headers["affairs"]
    my = "/api/v1/me/club-requests"
    review = "/api/v1/student-affairs/club-requests"
    data = {"name": "  Demo   Space Society ", "description": "Astronomy", "category": "Academic"}
    assert draft_client.post(my, json=data).status_code == 401
    request = draft_client.post(my, headers=student, json=data)
    assert request.status_code == 201, request.text
    request_id = request.json()["id"]
    assert request.json()["name"] == "Demo Space Society"
    own_path = f"{my}/{request_id}"
    decision = f"{review}/{request_id}/decision"
    assert draft_client.post(my, headers=student, json={**data, "name": "Different Name"}).status_code == 409
    assert draft_client.post(my, headers=other, json={**data, "name": "demo space society"}).status_code == 409
    assert draft_client.get(my, headers=other).json()["requests"] == []
    assert draft_client.put(own_path, headers=other, json=data).status_code == 404
    assert draft_client.post(f"{own_path}/withdraw", headers=other).status_code == 404
    assert draft_client.get(review, headers=student).status_code == 403
    assert draft_client.post(decision, headers=student, json={"decision": "approve"}).status_code == 403
    assert draft_client.post(decision, headers=affairs, json={"decision": "reject"}).status_code == 422

    edited = draft_client.put(own_path, headers=student, json={**data, "description": "Weekly observations"})
    assert edited.status_code == 200, edited.text
    assert draft_client.get(f"{review}/{request_id}/similar", headers=affairs).status_code == 200
    assert draft_client.get(review, headers=affairs).json()["requests"][0]["id"] == request_id
    approved = draft_client.post(decision, headers=affairs, json={"decision": "approve"})
    assert approved.status_code == 200, approved.text
    club_id = approved.json()["club_id"]
    assert draft_client.get(f"/api/v1/clubs/{club_id}", headers=other).status_code == 200
    assert draft_client.get("/api/v1/auth/me/managed-clubs", headers=student).json()["clubs"] == [
        {"id": club_id, "name": "Demo Space Society", "is_active": True, "archive_reason": None}
    ]
    assert draft_client.post(my, headers=other, json=data).status_code == 409
    assert draft_client.put(own_path, headers=student, json=data).status_code == 409
    assert draft_client.post(f"{own_path}/withdraw", headers=student).status_code == 409

    published = f"/api/v1/club-admin/clubs/{club_id}/profile"
    profile = {"description": "Updated club details", "category": "Science"}
    assert draft_client.put(published, headers=other, json=profile).status_code == 404
    assert draft_client.put(published, headers=student, json={**profile, "name": "Rename"}).status_code == 422
    updated = draft_client.put(published, headers=student, json=profile)
    assert updated.status_code == 200, updated.text
    assert updated.json()["name"] == "Demo Space Society"
    assert updated.json()["description"] == profile["description"]

    second = draft_client.post(my, headers=student, json={**data, "name": "Other Society"})
    assert second.status_code == 201, second.text
    second_id = second.json()["id"]
    rejection = draft_client.post(f"{review}/{second_id}/decision", headers=affairs,
                                  json={"decision": "reject", "reason": "Existing activity overlaps."})
    assert rejection.status_code == 200, rejection.text
    history = draft_client.get(my, headers=student).json()["requests"]
    assert [row["status"] for row in history] == ["rejected", "approved"]
    assert history[0]["rejection_reason"] == "Existing activity overlaps."


def test_approval_and_withdrawal_have_one_winner(draft_client, scenario):
    headers = scenario["headers"]
    result = draft_client.post("/api/v1/me/club-requests", headers=headers["student"],
                               json={"name": "Concurrent Club", "description": "Demo", "category": "Arts"})
    assert result.status_code == 201, result.text
    request_id = result.json()["id"]
    barrier = Barrier(2, timeout=15)

    def transition(path, role, body=None):
        with TestClient(app) as client:
            barrier.wait()
            return client.post(path, headers=headers[role], json=body)

    with ThreadPoolExecutor(max_workers=2) as pool:
        approved = pool.submit(transition, f"/api/v1/student-affairs/club-requests/{request_id}/decision",
                               "affairs", {"decision": "approve"})
        withdrawn = pool.submit(transition, f"/api/v1/me/club-requests/{request_id}/withdraw", "student")
        responses = [approved.result(timeout=30), withdrawn.result(timeout=30)]
    assert sorted(response.status_code for response in responses) == [200, 409]
    winner = next(response.json() for response in responses if response.status_code == 200)
    assert winner["status"] in {"approved", "withdrawn"}
    assert (winner["club_id"] is not None) == (winner["status"] == "approved")
