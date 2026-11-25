"""CAMP-10 acceptance tests: club-scoped draft creation on disposable PostgreSQL only."""

from datetime import datetime, timedelta, timezone
from pathlib import Path
from uuid import uuid4

import pytest
from alembic import command
from alembic.config import Config
from fastapi.testclient import TestClient
from sqlalchemy import URL, create_engine, inspect, text
from sqlalchemy.orm import Session

from app.auth.passwords import hash_password
from app.database import get_db
from app.main import app
from app.models.club import Club, ClubApprovalStatus
from app.models.user import AccountType, User


@pytest.fixture(scope="module")
def draft_test_engine():
    """Own an empty, non-default-port test database; never use campusconnect_db."""
    import os

    port = os.getenv("CAMPUSCONNECT_AUTH_TEST_PG_PORT")
    if port is None:
        if os.getenv("GITHUB_ACTIONS") == "true":
            pytest.fail("Disposable PostgreSQL service is required in CI")
        pytest.skip("CAMPUSCONNECT_AUTH_TEST_PG_PORT must identify disposable PostgreSQL")
    if not port.isdecimal() or int(port) == 5432 or not 1024 <= int(port) <= 65535:
        pytest.fail("CAMP-10 tests require a separate, non-default PostgreSQL port")

    url = URL.create(
        "postgresql+psycopg",
        username="postgres",
        host="127.0.0.1",
        port=int(port),
        database="campusconnect_auth_test",
    )
    engine = create_engine(url, connect_args={"connect_timeout": 3}, hide_parameters=True)
    config = Config(str(Path(__file__).resolve().parents[1] / "alembic.ini"))
    try:
        if inspect(engine).get_table_names():
            pytest.fail("Disposable test database must be empty before migrations")
        with pytest.MonkeyPatch.context() as patch:
            patch.setattr("app.config.get_database_url", lambda: url)
            command.upgrade(config, "head")
            try:
                command.check(config)
                yield engine
            finally:
                command.downgrade(config, "base")
                with engine.begin() as connection:
                    assert not inspect(connection).has_table("users")
                    assert not inspect(connection).has_table("clubs")
                    assert not inspect(connection).has_table("events")
                    assert not inspect(connection).has_table("club_administrators")
                    assert not inspect(connection).has_table("event_reservations")
                    connection.execute(text("DROP TABLE alembic_version"))
    finally:
        engine.dispose()


@pytest.fixture
def draft_client(draft_test_engine, monkeypatch):
    monkeypatch.setenv("JWT_SECRET_KEY", "only-for-tests-camp-10-0123456789-abcdefghijk")
    def isolated_session():
        with Session(draft_test_engine) as session:
            yield session

    previous = app.dependency_overrides.get(get_db)
    app.dependency_overrides[get_db] = isolated_session
    try:
        with TestClient(app) as client:
            yield client
    finally:
        if previous is None:
            app.dependency_overrides.pop(get_db, None)
        else:
            app.dependency_overrides[get_db] = previous
        with draft_test_engine.begin() as connection:
            connection.execute(text("DELETE FROM membership_applications"))
            connection.execute(text("DELETE FROM events"))
            connection.execute(text("DELETE FROM clubs"))
            connection.execute(text("DELETE FROM users"))


@pytest.fixture(scope="module")
def synthetic_test_password_hash():
    """Reuse the same valid test password hash, retaining per-test user isolation."""
    return hash_password("SyntheticEventTestPassword#123")


@pytest.fixture
def scenario(draft_test_engine, draft_client, synthetic_test_password_hash):
    password = "SyntheticEventTestPassword#123"
    with Session(draft_test_engine) as session:
        club = Club(
            name="Authorized BDD Robotics Club", description="Club for draft tests",
            category="Academic", approval_status=ClubApprovalStatus.APPROVED, is_active=True,
        )
        other = Club(
            name="Other Club", description="Unrelated club",
            category="Sports", approval_status=ClubApprovalStatus.APPROVED, is_active=True,
        )
        inactive = Club(
            name="Inactive Club", description="Inactive test club",
            category="Academic", approval_status=ClubApprovalStatus.APPROVED, is_active=False,
        )
        owner = User(
            full_name="Synthetic Club Owner", email="draft-owner@example.edu",
            university_id="DRAFT-OWNER", password_hash=synthetic_test_password_hash,
            account_type=AccountType.STUDENT,
        )
        student = User(
            full_name="Synthetic Regular Student", email="draft-student@example.edu",
            university_id="DRAFT-STUDENT", password_hash=synthetic_test_password_hash,
            account_type=AccountType.STUDENT,
        )
        affairs = User(
            full_name="Synthetic Affairs Officer", email="draft-affairs@example.edu",
            university_id="DRAFT-AFFAIRS", password_hash=synthetic_test_password_hash,
            account_type=AccountType.STUDENT_AFFAIRS,
        )
        session.add_all([club, other, inactive, owner, student, affairs])
        session.commit()
        ids = {
            "club": club.id, "other": other.id, "inactive": inactive.id,
            "owner": owner.id, "student": student.id, "affairs": affairs.id,
        }
    headers = {}
    for role in ("owner", "student", "affairs"):
        response = draft_client.post("/api/v1/auth/login", json={
            "email": f"draft-{role}@example.edu", "password": password,
        })
        assert response.status_code == 200, response.text
        headers[role] = {"Authorization": f"Bearer {response.json()['access_token']}"}
    return {"ids": ids, "headers": headers}


def grant_admin(engine, club_id, user_id):
    """Only the trusted test setup creates associations, never the public API."""
    with engine.begin() as connection:
        connection.execute(
            text("INSERT INTO club_administrators (club_id, user_id) VALUES (:club_id, :user_id)"),
            {"club_id": club_id, "user_id": user_id},
        )


def payload():
    start = datetime.now(timezone.utc) + timedelta(days=20)
    return {
        "title": "  Engineering Workshop  ",
        "description": "  Practical robotics session  ",
        "venue": "  Engineering Hall  ",
        "starts_at": start.isoformat(),
        "ends_at": (start + timedelta(hours=2)).isoformat(),
        "seat_capacity": 40,
    }


def post_event(client, club_id, data, headers=None):
    return client.post(f"/api/v1/clubs/{club_id}/events", json=data, headers=headers or {})


def test_authorized_club_admin_creates_draft_and_public_browse_hides_it(
    draft_client, draft_test_engine, scenario
):
    ids = scenario["ids"]
    grant_admin(draft_test_engine, ids["club"], ids["owner"])
    response = post_event(draft_client, ids["club"], payload(), scenario["headers"]["owner"])
    assert response.status_code == 201, response.text
    body = response.json()
    assert set(body) == {
        "id", "club_id", "title", "description", "venue", "starts_at", "ends_at",
        "seat_capacity", "approval_status", "is_published", "created_at", "updated_at",
    }
    assert body["club_id"] == str(ids["club"])
    assert body["title"] == "Engineering Workshop"
    assert body["description"] == "Practical robotics session"
    assert body["venue"] == "Engineering Hall"
    assert body["approval_status"] == "draft"
    assert body["is_published"] is False
    with Session(draft_test_engine) as session:
        stored = session.execute(
            text("SELECT club_id, approval_status, is_published, seat_capacity FROM events WHERE id=:id"),
            {"id": body["id"]},
        ).one()
        assert str(stored.club_id) == str(ids["club"])
        assert stored.approval_status == "draft"
        assert stored.is_published is False
        assert stored.seat_capacity == 40
    details = draft_client.get(
        f"/api/v1/clubs/{ids['club']}", headers=scenario["headers"]["owner"]
    )
    assert details.status_code == 200, details.text
    assert details.json()["events"] == []
    assert details.json()["total"] == 0


def test_cannot_create_for_another_club(draft_client, draft_test_engine, scenario):
    ids = scenario["ids"]
    grant_admin(draft_test_engine, ids["club"], ids["owner"])
    response = post_event(
        draft_client, ids["other"], payload(), scenario["headers"]["owner"]
    )
    assert response.status_code == 404
    with draft_test_engine.connect() as connection:
        assert connection.scalar(text("SELECT count(*) FROM events")) == 0


def test_ordinary_student_cannot_create_event(draft_client, draft_test_engine, scenario):
    ids = scenario["ids"]
    grant_admin(draft_test_engine, ids["club"], ids["owner"])
    response = post_event(
        draft_client, ids["club"], payload(), scenario["headers"]["student"]
    )
    assert response.status_code == 404


def test_student_affairs_cannot_bypass_club_scope_even_if_assigned(
    draft_client, draft_test_engine, scenario
):
    ids = scenario["ids"]
    grant_admin(draft_test_engine, ids["club"], ids["affairs"])
    response = post_event(
        draft_client, ids["club"], payload(), scenario["headers"]["affairs"]
    )
    assert response.status_code == 403


def test_missing_auth_returns_401(draft_client, scenario):
    assert post_event(draft_client, scenario["ids"]["club"], payload()).status_code == 401


def test_inactive_club_cannot_receive_draft(draft_client, draft_test_engine, scenario):
    ids = scenario["ids"]
    grant_admin(draft_test_engine, ids["inactive"], ids["owner"])
    assert post_event(
        draft_client, ids["inactive"], payload(), scenario["headers"]["owner"]
    ).status_code == 404


def test_nonexistent_club_is_not_disclosed(draft_client, scenario):
    response = post_event(
        draft_client, uuid4(), payload(), scenario["headers"]["owner"]
    )
    assert response.status_code == 404


@pytest.mark.parametrize("overrides", [
    {"title": " \t "},
    {"description": " \n "},
    {"venue": "  "},
    {"title": "x" * 161},
    {"venue": "v" * 201},
    {"seat_capacity": 0},
    {"seat_capacity": -1},
    {"seat_capacity": True},
    {"starts_at": "2030-01-01T12:00:00"},
    {"starts_at": "2020-01-01T12:00:00+00:00"},
    {"ends_at": "2020-01-01T12:00:00+00:00"},
    {"is_published": True},
    {"approval_status": "approved"},
    {"club_id": str(uuid4())},
    {"user_id": str(uuid4())},
])
def test_invalid_input_is_rejected_without_insert(
    draft_client, draft_test_engine, scenario, overrides
):
    ids = scenario["ids"]
    grant_admin(draft_test_engine, ids["club"], ids["owner"])
    submitted = payload()
    submitted.update(overrides)
    response = post_event(
        draft_client, ids["club"], submitted, scenario["headers"]["owner"]
    )
    assert response.status_code == 422, response.text
    with draft_test_engine.connect() as connection:
        assert connection.scalar(text("SELECT count(*) FROM events")) == 0


def test_duplicate_club_admin_membership_is_rejected(draft_test_engine, scenario):
    ids = scenario["ids"]
    grant_admin(draft_test_engine, ids["club"], ids["owner"])
    from sqlalchemy.exc import IntegrityError
    with pytest.raises(IntegrityError):
        grant_admin(draft_test_engine, ids["club"], ids["owner"])


def test_club_admin_membership_has_foreign_keys_and_no_global_account_role(
    draft_test_engine, scenario
):
    inspector = inspect(draft_test_engine)
    assert "club_administrators" in inspector.get_table_names()
    pk = inspector.get_pk_constraint("club_administrators")
    assert set(pk["constrained_columns"]) == {"club_id", "user_id"}
    fks = inspector.get_foreign_keys("club_administrators")
    assert {fk["referred_table"] for fk in fks} == {"clubs", "users"}
    assert {role.value for role in AccountType} == {"student", "student_affairs"}
