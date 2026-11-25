"""Executable pytest-bdd coverage for the public Club APIs."""

from datetime import datetime, timedelta, timezone
from pathlib import Path
from uuid import uuid4

from pytest_bdd import given, scenario, then, when
from sqlalchemy.orm import Session

from app.auth.passwords import hash_password
from app.models.club import Club, ClubApprovalStatus
from app.models.event import Event, EventApprovalStatus
from app.models.user import AccountType, User

FEATURE_FILE = Path(__file__).resolve().parents[3] / "features" / "club_discovery.feature"
PUBLIC_CLUB_FIELDS = {"id", "name", "description", "category", "logo_url"}
PUBLIC_EVENT_FIELDS = {
    "id",
    "title",
    "description",
    "venue",
    "starts_at",
    "ends_at",
    "seat_capacity",
}


def _student_headers(client):
    password = "BddStudentPassphrase#123"
    registered = client.post(
        "/api/v1/auth/register",
        json={
            "full_name": "BDD Student",
            "email": "bdd-student@example.edu",
            "university_id": "BDD-STUDENT-01",
            "password": password,
            "confirm_password": password,
        },
    )
    assert registered.status_code == 201, registered.text
    login = client.post(
        "/api/v1/auth/login",
        json={"email": "bdd-student@example.edu", "password": password},
    )
    assert login.status_code == 200, login.text
    return {"Authorization": f"Bearer {login.json()['access_token']}"}


def _club(name, *, approval_status=ClubApprovalStatus.APPROVED, is_active=True):
    return Club(
        name=name,
        description=f"Description for {name}",
        category="Academic",
        approval_status=approval_status,
        is_active=is_active,
    )


@scenario(str(FEATURE_FILE), "Approved Club Discovery")
def test_approved_club_discovery():
    pass


@given("an authenticated Student and clubs in mixed approval and activity states")
def seed_mixed_clubs(auth_client, migrated_engine, bdd_context):
    bdd_context["headers"] = _student_headers(auth_client)
    clubs = [
        _club("Approved Active BDD Club"),
        _club("Pending BDD Club", approval_status=ClubApprovalStatus.PENDING),
        _club("Rejected BDD Club", approval_status=ClubApprovalStatus.REJECTED),
        _club("Inactive BDD Club", is_active=False),
    ]
    with Session(migrated_engine) as session:
        session.add_all(clubs)
        session.flush()
        bdd_context["visible_club_id"] = str(clubs[0].id)
        bdd_context["hidden_club_names"] = [club.name for club in clubs[1:]]
        session.commit()


@when('the Student requests "GET /api/v1/clubs"')
def request_club_list(auth_client, bdd_context):
    bdd_context["response"] = auth_client.get(
        "/api/v1/clubs", headers=bdd_context.get("headers")
    )


@then("only approved active clubs are returned with the public response schema")
def verify_club_list(bdd_context):
    response = bdd_context["response"]
    assert response.status_code == 200, response.text
    body = response.json()
    assert set(body) == {"clubs", "page", "page_size", "total"}
    assert body["page"] == 1
    assert body["total"] == 1
    assert len(body["clubs"]) == 1
    assert body["clubs"][0]["id"] == bdd_context["visible_club_id"]
    assert set(body["clubs"][0]) == PUBLIC_CLUB_FIELDS
    assert all(name not in response.text for name in bdd_context["hidden_club_names"])
    assert not {"approval_status", "is_active", "created_at", "updated_at"}.intersection(
        body["clubs"][0]
    )


@scenario(str(FEATURE_FILE), "Unauthorized Access")
def test_unauthorized_access():
    pass


@given("a caller without valid bearer credentials and a private club in the database")
def seed_private_club_for_unauthenticated_request(auth_client, migrated_engine, bdd_context):
    with Session(migrated_engine) as session:
        session.add(_club("Private BDD Club"))
        session.commit()
    bdd_context["private_marker"] = "Private BDD Club"


@when('the caller requests "GET /api/v1/clubs" without an Authorization header')
def request_club_list_without_auth(auth_client, bdd_context):
    bdd_context["response"] = auth_client.get("/api/v1/clubs")


@then("the request is rejected without disclosing club data")
def verify_unauthenticated_request(bdd_context):
    response = bdd_context["response"]
    assert response.status_code == 401, response.text
    assert response.json() == {"detail": "Invalid or expired session"}
    assert bdd_context["private_marker"] not in response.text


@scenario(str(FEATURE_FILE), "Student Affairs Cannot Browse Clubs")
def test_student_affairs_cannot_browse_clubs():
    pass


@given("an authenticated Student Affairs account and a private club")
def student_affairs_headers(auth_client, migrated_engine, bdd_context):
    with Session(migrated_engine) as session:
        session.add(_club("Staff-Only BDD Club"))
        session.add(
            User(
                full_name="Synthetic BDD Staff",
                email="bdd-staff@example.edu",
                university_id="BDD-STAFF-01",
                password_hash=hash_password("BddStaffPassphrase#123"),
                account_type=AccountType.STUDENT_AFFAIRS,
            )
        )
        session.commit()
    login = auth_client.post(
        "/api/v1/auth/login",
        json={"email": "bdd-staff@example.edu", "password": "BddStaffPassphrase#123"},
    )
    assert login.status_code == 200, login.text
    bdd_context["headers"] = {"Authorization": f"Bearer {login.json()['access_token']}"}
    bdd_context["private_marker"] = "Staff-Only BDD Club"


@when('the authenticated account requests "GET /api/v1/clubs"')
def request_club_list_as_non_student(auth_client, bdd_context):
    bdd_context["response"] = auth_client.get("/api/v1/clubs", headers=bdd_context["headers"])


@then("the request is forbidden without disclosing club data")
def verify_non_student_forbidden(bdd_context):
    response = bdd_context["response"]
    assert response.status_code == 403, response.text
    assert response.json() == {"detail": "Insufficient permissions"}
    assert bdd_context["private_marker"] not in response.text


@scenario(str(FEATURE_FILE), "Club Details Hide Nonpublic Events")
def test_club_details_hide_nonpublic_events():
    pass


@given("an authenticated Student, a visible club, and mixed event visibility states")
def seed_events_for_club_details(auth_client, migrated_engine, bdd_context):
    bdd_context["headers"] = _student_headers(auth_client)
    starts_at = datetime.now(timezone.utc) + timedelta(days=2)
    past_at = datetime.now(timezone.utc) - timedelta(days=2)
    visible_club = _club("Visible Events BDD Club")
    other_club = _club("Other Events BDD Club")
    with Session(migrated_engine) as session:
        session.add_all([visible_club, other_club])
        session.flush()
        bdd_context["club_id"] = str(visible_club.id)
        bdd_context["event_markers"] = [
            "Visible Future BDD Event",
            "Draft BDD Event",
            "Pending BDD Event",
            "Rejected BDD Event",
            "Unpublished BDD Event",
            "Past BDD Event",
            "Other Club BDD Event",
        ]
        session.add_all(
            [
                Event(
                    club_id=visible_club.id,
                    title="Visible Future BDD Event",
                    description="Public future event",
                    venue="Main Hall",
                    starts_at=starts_at,
                    seat_capacity=30,
                    approval_status=EventApprovalStatus.APPROVED,
                    is_published=True,
                ),
                Event(
                    club_id=visible_club.id,
                    title="Draft BDD Event",
                    description="Draft event details",
                    venue="Draft Room",
                    starts_at=starts_at,
                    seat_capacity=10,
                    approval_status=EventApprovalStatus.DRAFT,
                    is_published=True,
                ),
                Event(
                    club_id=visible_club.id,
                    title="Pending BDD Event",
                    description="Pending event details",
                    venue="Pending Room",
                    starts_at=starts_at,
                    seat_capacity=10,
                    approval_status=EventApprovalStatus.PENDING,
                    is_published=True,
                ),
                Event(
                    club_id=visible_club.id,
                    title="Rejected BDD Event",
                    description="Rejected event details",
                    venue="Rejected Room",
                    starts_at=starts_at,
                    seat_capacity=10,
                    approval_status=EventApprovalStatus.REJECTED,
                    is_published=True,
                ),
                Event(
                    club_id=visible_club.id,
                    title="Unpublished BDD Event",
                    description="Unpublished event details",
                    venue="Private Room",
                    starts_at=starts_at,
                    seat_capacity=10,
                    approval_status=EventApprovalStatus.APPROVED,
                    is_published=False,
                ),
                Event(
                    club_id=visible_club.id,
                    title="Past BDD Event",
                    description="Past event details",
                    venue="Old Hall",
                    starts_at=past_at,
                    seat_capacity=10,
                    approval_status=EventApprovalStatus.APPROVED,
                    is_published=True,
                ),
                Event(
                    club_id=other_club.id,
                    title="Other Club BDD Event",
                    description="Another club's event details",
                    venue="Other Hall",
                    starts_at=starts_at,
                    seat_capacity=10,
                    approval_status=EventApprovalStatus.APPROVED,
                    is_published=True,
                ),
            ]
        )
        session.commit()


@when("the Student requests the visible club details")
def request_visible_club_details(auth_client, bdd_context):
    bdd_context["response"] = auth_client.get(
        f"/api/v1/clubs/{bdd_context['club_id']}", headers=bdd_context["headers"]
    )


@then("only its approved published future events are returned with public fields")
def verify_public_upcoming_events(bdd_context):
    response = bdd_context["response"]
    assert response.status_code == 200, response.text
    body = response.json()
    assert set(body) == {"club", "events", "page", "page_size", "total"}
    assert body["club"]["id"] == bdd_context["club_id"]
    assert set(body["club"]) == PUBLIC_CLUB_FIELDS
    assert body["total"] == 1
    assert len(body["events"]) == 1
    event = body["events"][0]
    assert event["title"] == "Visible Future BDD Event"
    assert set(event) == PUBLIC_EVENT_FIELDS
    starts_at = datetime.fromisoformat(event["starts_at"].replace("Z", "+00:00"))
    assert starts_at.utcoffset() == timedelta(0)
    assert all(marker not in response.text for marker in bdd_context["event_markers"][1:])
    assert not {"approval_status", "is_published", "created_at", "updated_at"}.intersection(
        event
    )


@scenario(str(FEATURE_FILE), "Hidden Clubs Are Not Disclosed")
def test_hidden_clubs_are_not_disclosed():
    pass


@given("an authenticated Student and clubs that must remain hidden")
def seed_hidden_clubs(auth_client, migrated_engine, bdd_context):
    bdd_context["headers"] = _student_headers(auth_client)
    hidden_clubs = [
        _club("Pending Detail BDD Club", approval_status=ClubApprovalStatus.PENDING),
        _club("Rejected Detail BDD Club", approval_status=ClubApprovalStatus.REJECTED),
        _club("Inactive Detail BDD Club", is_active=False),
    ]
    with Session(migrated_engine) as session:
        session.add_all(hidden_clubs)
        session.flush()
        bdd_context["hidden_clubs"] = [(club.id, club.name) for club in hidden_clubs]
        session.commit()
    bdd_context["unknown_club_id"] = uuid4()


@when("the Student requests each hidden club and a nonexistent club")
def request_hidden_club_details(auth_client, bdd_context):
    club_ids = [club_id for club_id, _name in bdd_context["hidden_clubs"]]
    club_ids.append(bdd_context["unknown_club_id"])
    bdd_context["responses"] = [
        auth_client.get(f"/api/v1/clubs/{club_id}", headers=bdd_context["headers"])
        for club_id in club_ids
    ]


@then("all responses are indistinguishable not-found results without private club data")
def verify_hidden_club_responses(bdd_context):
    responses = bdd_context["responses"]
    assert all(response.status_code == 404 for response in responses)
    assert all(response.json() == {"detail": "Club not found"} for response in responses)
    assert all(
        name not in response.text
        for response in responses
        for _club_id, name in bdd_context["hidden_clubs"]
    )
