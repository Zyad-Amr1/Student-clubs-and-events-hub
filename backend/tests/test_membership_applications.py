from test_event_creation import (
    draft_client, draft_test_engine, grant_admin, scenario, synthetic_test_password_hash,
)


def test_membership_application_and_club_scope(draft_client, draft_test_engine, scenario):
    ids, headers = scenario["ids"], scenario["headers"]
    club_id = ids["club"]
    owner, student, affairs = (headers[role] for role in ("owner", "student", "affairs"))
    path = f"/api/v1/clubs/{club_id}/applications"
    review = f"/api/v1/club-admin/clubs/{club_id}/applications"
    assert draft_client.post(path).status_code == 401
    assert draft_client.post(path, headers=affairs).status_code == 403
    assert draft_client.post(f"/api/v1/clubs/{ids['inactive']}/applications", headers=student).status_code == 404
    result = draft_client.post(path, headers=student)
    assert result.status_code == 201, result.text
    assert result.json()["status"] == "pending"
    application = result.json()["id"]
    assert draft_client.post(path, headers=student).status_code == 409
    assert draft_client.get("/api/v1/me/applications", headers=owner).json()["applications"] == []
    assert draft_client.get(review, headers=owner).status_code == 404

    grant_admin(draft_test_engine, club_id, ids["owner"])
    assert draft_client.get(review, headers=owner).json()["applications"][0]["id"] == application
    assert draft_client.get(f"/api/v1/club-admin/clubs/{ids['other']}/applications",
                            headers=owner).status_code == 404
    assert draft_client.post(f"{review}/{application}/decision", headers=student,
                             json={"decision": "accepted"}).status_code == 404
    reviewed = draft_client.post(f"{review}/{application}/decision", headers=owner,
                                 json={"decision": "interview_required"})
    assert reviewed.status_code == 200, reviewed.text
    assert reviewed.json()["interview_required_at"] is not None
    assert draft_client.get("/api/v1/me/memberships", headers=student).json()["applications"] == []
    assert draft_client.get("/api/v1/me/applications", headers=student).json()["applications"][0][
        "status"
    ] == "interview_required"

    other_club = ids["other"]
    grant_admin(draft_test_engine, other_club, ids["owner"])
    second = draft_client.post(f"/api/v1/clubs/{other_club}/applications", headers=student)
    assert second.status_code == 201, second.text
    accepted = draft_client.post(
        f"/api/v1/club-admin/clubs/{other_club}/applications/{second.json()['id']}/decision",
        headers=owner, json={"decision": "accepted"},
    )
    assert accepted.status_code == 200, accepted.text
    assert [item["id"] for item in draft_client.get(
        "/api/v1/me/memberships", headers=student
    ).json()["applications"]] == [second.json()["id"]]
