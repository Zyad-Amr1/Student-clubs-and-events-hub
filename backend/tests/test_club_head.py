from concurrent.futures import ThreadPoolExecutor
from threading import Barrier

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import text
from sqlalchemy.exc import IntegrityError

from app.main import app
from test_event_creation import draft_client, draft_test_engine, scenario, synthetic_test_password_hash


def test_student_affairs_singleton_includes_inactive_accounts(draft_test_engine, scenario):
    with pytest.raises(IntegrityError), draft_test_engine.begin() as db:
        db.execute(text("UPDATE users SET is_active=false WHERE account_type='student_affairs'"))
        db.execute(text("UPDATE users SET account_type='student_affairs' WHERE id=:id"),
                   {"id": scenario["ids"]["student"]})


def test_club_head_race_rejection_reopening_and_assignment(draft_client, draft_test_engine, scenario):
    club = scenario["ids"]["club"]
    headers = scenario["headers"]
    apply = f"/api/v1/clubs/{club}/head-requests"
    vacancy = f"/api/v1/clubs/{club}/head-vacancy"
    queue = "/api/v1/student-affairs/club-head-requests"
    mine = "/api/v1/me/club-head-requests"
    assert draft_client.get(vacancy, headers=headers["student"]).json()["availability"] == "open"
    assert draft_client.post(apply, headers=headers["affairs"]).status_code == 403
    barrier = Barrier(2, timeout=10)

    def submit(role):
        with TestClient(app) as client:
            barrier.wait()
            return client.post(apply, headers=headers[role])

    with ThreadPoolExecutor(max_workers=2) as pool:
        roles = ("owner", "student")
        results = list(pool.map(submit, roles))
    assert sorted(response.status_code for response in results) == [201, 409]
    winner, loser = (roles if results[0].status_code == 201 else roles[::-1])
    assert draft_client.get(vacancy, headers=headers[loser]).json()["availability"] == "locked"
    assert draft_client.get(queue, headers=headers[winner]).status_code == 403
    rows = draft_client.get(queue, headers=headers["affairs"]).json()["requests"]
    assert len(rows) == 1 and rows[0]["applicant_name"]
    review = f"{queue}/{rows[0]['id']}/decision"
    assert draft_client.post(review, headers=headers[winner], json={"decision": "approve"}).status_code == 403
    assert draft_client.post(review, headers=headers["affairs"], json={"decision": "reject"}).status_code == 422
    rejected = draft_client.post(review, headers=headers["affairs"],
                                 json={"decision": "reject", "reason": "Experience required"})
    assert rejected.status_code == 200
    assert draft_client.get(mine, headers=headers[winner]).json()["requests"][0]["reason"] == "Experience required"
    assert draft_client.get(mine, headers=headers[loser]).json()["requests"] == []
    assert draft_client.get(vacancy, headers=headers[loser]).json()["availability"] == "open"
    request = draft_client.post(apply, headers=headers[loser])
    assert request.status_code == 201
    path = f"{queue}/{request.json()['id']}/decision"
    assert draft_client.post(path, headers=headers["affairs"], json={"decision": "approve"}).status_code == 200
    assert draft_client.post(path, headers=headers["affairs"], json={"decision": "approve"}).status_code == 409
    assert draft_client.get(vacancy, headers=headers[winner]).json()["availability"] == "assigned"
    assert draft_client.post(apply, headers=headers[winner]).status_code == 409
    assert draft_client.get("/api/v1/auth/me/managed-clubs", headers=headers[loser]).json()["clubs"][0]["id"] == str(club)
    assert draft_client.get("/api/v1/auth/me", headers=headers[loser]).json()["account_type"] == "student"
