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
    with pytest.raises(IntegrityError), draft_test_engine.begin() as db:
        db.execute(text("INSERT INTO club_administrators (club_id, user_id) VALUES (:club, :student)"),
                   {"club": club, "student": scenario["ids"][loser]})
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
    with pytest.raises(IntegrityError), draft_test_engine.begin() as db:
        db.execute(text("INSERT INTO club_head_requests (club_id, student_id) VALUES (:club, :student)"),
                   {"club": club, "student": scenario["ids"][winner]})
    assert draft_client.get("/api/v1/auth/me/managed-clubs", headers=headers[loser]).json()["clubs"][0]["id"] == str(club)
    assert draft_client.get("/api/v1/auth/me", headers=headers[loser]).json()["account_type"] == "student"


def test_concurrent_head_approval_and_rejection_has_one_transactional_winner(
    draft_client, draft_test_engine, scenario,
):
    ids, headers = scenario["ids"], scenario["headers"]
    club_id = ids["club"]
    submitted = draft_client.post(f"/api/v1/clubs/{club_id}/head-requests",
                                  headers=headers["student"])
    assert submitted.status_code == 201, submitted.text
    request_id = submitted.json()["id"]
    path = f"/api/v1/student-affairs/club-head-requests/{request_id}/decision"
    barrier = Barrier(2, timeout=10)

    def decide(decision):
        with TestClient(app) as client:
            barrier.wait()
            body = {"decision": decision}
            if decision == "reject":
                body["reason"] = "Selected another applicant."
            return client.post(path, headers=headers["affairs"], json=body)

    with ThreadPoolExecutor(max_workers=2) as pool:
        responses = list(pool.map(decide, ("approve", "reject")))
    assert sorted(response.status_code for response in responses) == [200, 409]

    with draft_test_engine.connect() as db:
        request = db.execute(text(
            "SELECT status, reason, reviewed_by, decided_at FROM club_head_requests WHERE id=:id"
        ), {"id": request_id}).one()
        grants = db.execute(text(
            "SELECT user_id FROM club_administrators WHERE club_id=:club"
        ), {"club": club_id}).scalars().all()
    assert request.status == next(response.json()["status"] for response in responses
                                  if response.status_code == 200)
    assert request.reviewed_by == ids["affairs"] and request.decided_at is not None
    if request.status == "approved":
        assert request.reason is None and [str(user) for user in grants] == [str(ids["student"])]
        expected_vacancy = "assigned"
    else:
        assert request.reason == "Selected another applicant." and grants == []
        expected_vacancy = "open"
    assert len(grants) <= 1
    assert draft_client.get(f"/api/v1/clubs/{club_id}/head-vacancy",
                            headers=headers["owner"]).json()["availability"] == expected_vacancy


def test_club_head_application_racing_direct_assignment_has_one_winner(
    draft_client, draft_test_engine, scenario,
):
    ids, headers = scenario["ids"], scenario["headers"]
    club_id = ids["club"]
    barrier = Barrier(2, timeout=10)

    def apply():
        with TestClient(app) as client:
            barrier.wait()
            return client.post(f"/api/v1/clubs/{club_id}/head-requests",
                               headers=headers["student"])

    def assign():
        with TestClient(app) as client:
            barrier.wait()
            return client.put(f"/api/v1/auth/student-affairs/clubs/{club_id}/administrator",
                              headers=headers["affairs"], json={"student_id": str(ids["owner"])})

    with ThreadPoolExecutor(max_workers=2) as pool:
        application_future, assignment_future = pool.submit(apply), pool.submit(assign)
        application, assignment = application_future.result(), assignment_future.result()
    assert (application.status_code, assignment.status_code) in {(201, 409), (409, 200)}

    with draft_test_engine.connect() as db:
        pending = db.execute(text(
            "SELECT count(*) FROM club_head_requests WHERE club_id=:club AND status='pending'"
        ), {"club": club_id}).scalar_one()
        grants = db.execute(text(
            "SELECT user_id FROM club_administrators WHERE club_id=:club"
        ), {"club": club_id}).scalars().all()
    assert pending + len(grants) == 1 and len(grants) <= 1
    assert draft_client.get(f"/api/v1/clubs/{club_id}/head-vacancy",
                            headers=headers["student"]).json()["availability"] == (
                                "locked" if pending else "assigned"
                            )
    if assignment.status_code == 200:
        assert [str(user) for user in grants] == [str(ids["owner"])]
        assert draft_client.get(f"/api/v1/club-admin/clubs/{club_id}/applications",
                                headers=headers["owner"]).status_code == 200
    else:
        assert application.status_code == 201 and grants == []
        assert draft_client.get(f"/api/v1/club-admin/clubs/{club_id}/applications",
                                headers=headers["owner"]).status_code == 404


def test_pending_head_application_can_be_rejected_after_club_archival(
    draft_client, draft_test_engine, scenario,
):
    ids, headers = scenario["ids"], scenario["headers"]
    club_id = ids["club"]
    submitted = draft_client.post(f"/api/v1/clubs/{club_id}/head-requests",
                                  headers=headers["student"])
    assert submitted.status_code == 201, submitted.text
    club_path = f"/api/v1/student-affairs/clubs/{club_id}"
    preview = draft_client.post(club_path + "/archive-preview", headers=headers["affairs"])
    assert preview.status_code == 200, preview.text
    archived = draft_client.post(club_path + "/archive", headers=headers["affairs"], json={
        "reason": "Department closed", "preview_token": preview.json()["preview_token"],
    })
    assert archived.status_code == 200, archived.text

    decision = f"/api/v1/student-affairs/club-head-requests/{submitted.json()['id']}/decision"
    assert draft_client.post(decision, headers=headers["student"], json={
        "decision": "reject", "reason": "Unauthorized",
    }).status_code == 403
    rejected = draft_client.post(decision, headers=headers["affairs"], json={
        "decision": "reject", "reason": "Club archived: Department closed",
    })
    assert rejected.status_code == 200, rejected.text
    assert rejected.json()["status"] == "rejected"
    assert rejected.json()["reason"] == "Club archived: Department closed"
    assert draft_client.get(f"/api/v1/clubs/{club_id}/head-vacancy",
                            headers=headers["student"]).status_code == 404
    with draft_test_engine.connect() as db:
        request = db.execute(text(
            "SELECT status, reason, reviewed_by, decided_at FROM club_head_requests WHERE id=:id"
        ), {"id": submitted.json()["id"]}).one()
        grants = db.execute(text(
            "SELECT count(*) FROM club_administrators WHERE club_id=:club"
        ), {"club": club_id}).scalar_one()
        is_active = db.execute(text("SELECT is_active FROM clubs WHERE id=:club"),
                               {"club": club_id}).scalar_one()
    assert request.status == "rejected" and request.reason == "Club archived: Department closed"
    assert request.reviewed_by == ids["affairs"] and request.decided_at is not None
    assert grants == 0 and is_active is False
