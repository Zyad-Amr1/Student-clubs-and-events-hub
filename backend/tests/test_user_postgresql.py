import os
from datetime import datetime, timedelta, timezone
from pathlib import Path
from uuid import UUID, uuid4

import pytest
import jwt
from fastapi.testclient import TestClient

from app.auth.accounts import DuplicateAccountError, create_account
from app.auth.passwords import hash_password, verify_password
from app.auth.schemas import AccountCreationInput
from app.auth.tokens import JWT_AUDIENCE, JWT_ISSUER
from app.config import get_jwt_secret
from app.database import get_db
from app.main import app
from alembic import command
from alembic.config import Config
from sqlalchemy import URL, create_engine, inspect, text
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.models.user import AccountType, User


@pytest.fixture(scope="module")
def migrated_engine():
    port = os.getenv("CAMPUSCONNECT_AUTH_TEST_PG_PORT")
    if port is None:
        if os.getenv("GITHUB_ACTIONS") == "true":
            pytest.fail("GitHub Actions must configure its disposable PostgreSQL service")
        pytest.skip("Set CAMPUSCONNECT_AUTH_TEST_PG_PORT for a disposable PostgreSQL instance")
    if not port.isdecimal() or not 1024 <= int(port) <= 65535 or int(port) == 5432:
        pytest.fail("Use a separate PostgreSQL instance on a non-default test port")

    url = URL.create(
        "postgresql+psycopg",
        username="postgres",
        host="127.0.0.1",
        port=int(port),
        database="campusconnect_auth_test",
    )
    engine = create_engine(url, connect_args={"connect_timeout": 3}, hide_parameters=True)
    alembic_config = Config(str(Path(__file__).resolve().parents[1] / "alembic.ini"))
    try:
        if inspect(engine).get_table_names():
            pytest.fail("The disposable PostgreSQL database must be empty")
        with pytest.MonkeyPatch.context() as patch:
            patch.setattr("app.config.get_database_url", lambda: url)
            command.upgrade(alembic_config, "head")
            try:
                command.check(alembic_config)
                yield engine
            finally:
                command.downgrade(alembic_config, "base")
                with engine.begin() as connection:
                    assert not inspect(connection).has_table("users")
                    assert connection.scalar(text(
                        "SELECT to_regprocedure('campusconnect_users_before_update()')"
                    )) is None
                    # The fixture started with an empty database and owns this table.
                    connection.execute(text("DROP TABLE alembic_version"))
    finally:
        engine.dispose()


def new_user(email="Student@Example.EDU", university_id=" id-01 "):
    return User(
        full_name="Example Student",
        email=email,
        university_id=university_id,
        password_hash="synthetic-hash-for-test",
    )


def test_postgresql_defaults_and_profile_updates(migrated_engine):
    with Session(migrated_engine) as session:
        session.execute(text("SET LOCAL TIME ZONE 'UTC'"))
        user = new_user()
        session.add(user)
        session.flush()
        assert isinstance(user.id, UUID)
        assert user.account_type is AccountType.STUDENT
        assert user.is_active is True
        assert user.created_at.utcoffset() == timedelta(0)
        assert user.created_at == user.updated_at

        original_update = user.updated_at
        user.full_name = "Updated Student"
        user.faculty = "Engineering"
        user.department = "Software Engineering"
        user.academic_year = 2
        user.profile_picture_url = "https://example.edu/avatar.png"
        session.flush()
        session.refresh(user)
        assert user.full_name == "Updated Student"
        assert user.faculty == "Engineering"
        assert user.department == "Software Engineering"
        assert user.academic_year == 2
        assert user.profile_picture_url == "https://example.edu/avatar.png"
        assert user.updated_at > original_update
        assert user.updated_at.utcoffset() == timedelta(0)

        affairs = new_user("affairs@example.edu", "AF-02")
        affairs.account_type = AccountType.STUDENT_AFFAIRS
        session.add(affairs)
        session.flush()
        session.expire(affairs)
        assert affairs.account_type is AccountType.STUDENT_AFFAIRS


@pytest.mark.parametrize(
    ("email", "university_id", "constraint"),
    [
        (" STUDENT@example.edu ", "ID-02", "uq_users_email"),
        ("other@example.edu", " id-01 ", "uq_users_university_id"),
    ],
)
def test_postgresql_rejects_duplicate_normalized_identifiers(
    migrated_engine, email, university_id, constraint
):
    with Session(migrated_engine) as session:
        session.add(new_user())
        session.flush()
        session.add(new_user(email, university_id))
        with pytest.raises(IntegrityError) as error:
            session.flush()
        assert error.value.orig.diag.constraint_name == constraint


@pytest.mark.parametrize(
    ("column", "replacement"),
    [("email", "new@example.edu"), ("university_id", "ID-02")],
)
def test_postgresql_rejects_identifier_changes(migrated_engine, column, replacement):
    with Session(migrated_engine) as session:
        user = new_user()
        session.add(user)
        session.flush()
        with pytest.raises(IntegrityError) as error:
            session.execute(
                User.__table__.update()
                .where(User.id == user.id)
                .values({column: replacement})
            )
        assert error.value.orig.sqlstate == "23514"


def test_postgresql_rejects_unnormalized_direct_insert(migrated_engine):
    with Session(migrated_engine) as session:
        with pytest.raises(IntegrityError) as error:
            session.execute(
                text(
                    "INSERT INTO users (full_name, email, university_id, password_hash) "
                    "VALUES ('Example Student', ' Student@example.edu', 'ID-01', 'example-hash')"
                )
            )
        assert error.value.orig.diag.constraint_name == "ck_users_email_normalized"


def test_postgresql_unicode_identifiers_ignore_database_locale(migrated_engine):
    with Session(migrated_engine) as session:
        session.add(new_user("Straße@example.edu", "é-01"))
        session.flush()
        session.add(new_user("STRASSE@example.edu", "ID-02"))
        with pytest.raises(IntegrityError) as error:
            session.flush()
        assert error.value.orig.diag.constraint_name == "uq_users_email"


@pytest.mark.parametrize(
    ("field", "value", "constraint"),
    [
        ("email", "\u00a0student@example.edu", "ck_users_email_normalized"),
        ("university_id", "é-01", "ck_users_university_id_normalized"),
        ("full_name", "\t\n", "ck_users_full_name_nonblank"),
        ("password_hash", "\t\n", "ck_users_password_hash_nonblank"),
        ("account_type", "club_admin", "ck_users_account_type"),
    ],
)
def test_postgresql_rejects_noncanonical_direct_values(migrated_engine, field, value, constraint):
    values = {
        "full_name": "Example Student",
        "email": "student@example.edu",
        "university_id": "ID-01",
        "password_hash": "synthetic-hash-for-test",
        "account_type": "student",
        field: value,
    }
    with Session(migrated_engine) as session:
        with pytest.raises(IntegrityError) as error:
            session.execute(
                text(
                    "INSERT INTO users (full_name, email, university_id, password_hash, account_type) "
                    "VALUES (:full_name, :email, :university_id, :password_hash, :account_type)"
                ),
                values,
            )
        assert error.value.orig.diag.constraint_name == constraint


@pytest.fixture
def registration_client(migrated_engine):
    """Route requests to the disposable PostgreSQL database; clean up committed rows."""
    def isolated_session():
        with Session(migrated_engine) as session:
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
        with migrated_engine.begin() as connection:
            connection.execute(text("DELETE FROM users"))


def registration_body(**changes):
    return {
        "full_name": "  Example Student  ",
        "email": " Student@Example.EDU ",
        "university_id": " ab-123 ",
        "password": "StrongPassphrase#123",
        "confirm_password": "StrongPassphrase#123",
        **changes,
    }


def test_registration_creates_only_student_without_returning_secrets(registration_client, migrated_engine):
    response = registration_client.post("/api/v1/auth/register", json=registration_body())
    assert response.status_code == 201, response.text
    body = response.json()
    assert body["email"] == "student@example.edu"
    assert body["university_id"] == "AB-123"
    assert body["full_name"] == "Example Student"
    assert body["account_type"] == "student"
    assert body["is_active"] is True
    assert "password" not in response.text.lower()
    assert "hash" not in response.text.lower()
    with Session(migrated_engine) as session:
        stored = session.query(User).filter_by(email="student@example.edu").one()
        assert stored.account_type is AccountType.STUDENT
        assert stored.password_hash != "StrongPassphrase#123"
        assert verify_password("StrongPassphrase#123", stored.password_hash)


@pytest.mark.parametrize(
    "changes",
    [
        {"email": "student@example.edu", "university_id": "SECOND-ID"},
        {"email": "another@example.edu", "university_id": "AB-123"},
    ],
)
def test_registration_rejects_duplicates_atomically(registration_client, changes):
    assert registration_client.post("/api/v1/auth/register", json=registration_body()).status_code == 201
    duplicate = registration_client.post("/api/v1/auth/register", json=registration_body(**changes))
    assert duplicate.status_code == 409
    assert duplicate.json() == {"detail": "An account with these details already exists"}


@pytest.mark.parametrize(
    "changes",
    [
        {"confirm_password": "MismatchSecret#456"},
        {"account_type": "student_affairs"},
        {"password": "short", "confirm_password": "short"},
        {"email": "invalid-email"},
    ],
)
def test_registration_errors_do_not_echo_submitted_secrets(registration_client, changes):
    payload = registration_body(**changes)
    response = registration_client.post("/api/v1/auth/register", json=payload)
    assert response.status_code == 422, response.text
    assert "StrongPassphrase#123" not in response.text
    assert "MismatchSecret#456" not in response.text
    assert all("input" not in error for error in response.json()["detail"])


# Login, JWT authorization, and server-side logout integration tests.
# These always run on the disposable PostgreSQL test instance from migrated_engine.

@pytest.fixture
def auth_client(registration_client, monkeypatch):
    monkeypatch.setenv("JWT_SECRET_KEY", "only-for-tests-0123456789-abcdefghijklmnopqrstuv")
    return registration_client


def login_body(**changes):
    return {"email": " STUDENT@EXAMPLE.EDU ", "password": "StrongPassphrase#123", **changes}


def access_headers(token):
    return {"Authorization": f"Bearer {token}"}


def test_login_me_and_logout_revoke_session(auth_client, migrated_engine):
    assert auth_client.post("/api/v1/auth/register", json=registration_body()).status_code == 201
    response = auth_client.post("/api/v1/auth/login", json=login_body())
    assert response.status_code == 200, response.text
    tokens = response.json()
    assert tokens["token_type"] == "bearer"
    assert tokens["expires_in"] == 3600
    access_token = tokens["access_token"]
    assert access_token.count(".") == 2
    assert "StrongPassphrase#123" not in response.text

    profile = auth_client.get("/api/v1/auth/me", headers=access_headers(access_token))
    assert profile.status_code == 200, profile.text
    assert profile.json()["email"] == "student@example.edu"
    assert profile.json()["account_type"] == "student"
    assert "password" not in profile.text.lower()

    outcome = auth_client.post("/api/v1/auth/logout", headers=access_headers(access_token))
    assert outcome.status_code == 204
    assert outcome.content == b""
    assert auth_client.get("/api/v1/auth/me", headers=access_headers(access_token)).status_code == 401
    with Session(migrated_engine) as session:
        assert session.query(User).count() == 1


def test_login_invalid_or_unknown_email_same_response(auth_client):
    assert auth_client.post("/api/v1/auth/register", json=registration_body()).status_code == 201
    wrong = auth_client.post("/api/v1/auth/login", json=login_body(password="wrong password"))
    unknown = auth_client.post(
        "/api/v1/auth/login", json=login_body(email="unknown@example.edu")
    )
    assert wrong.status_code == unknown.status_code == 401
    assert wrong.json() == unknown.json() == {"detail": "Invalid email or password"}


def test_disabled_account_cannot_login(auth_client, migrated_engine):
    assert auth_client.post("/api/v1/auth/register", json=registration_body()).status_code == 201
    with Session(migrated_engine) as session:
        user = session.query(User).filter_by(email="student@example.edu").one()
        user.is_active = False
        session.commit()
    response = auth_client.post("/api/v1/auth/login", json=login_body())
    assert response.status_code == 401
    assert response.json() == {"detail": "Invalid email or password"}


def test_disabling_account_invalidates_existing_session(auth_client, migrated_engine):
    auth_client.post("/api/v1/auth/register", json=registration_body())
    token = auth_client.post("/api/v1/auth/login", json=login_body()).json()["access_token"]
    with Session(migrated_engine) as session:
        user = session.query(User).filter_by(email="student@example.edu").one()
        user.is_active = False
        session.commit()
    assert auth_client.get("/api/v1/auth/me", headers=access_headers(token)).status_code == 401


def test_logout_revokes_only_current_device(auth_client):
    auth_client.post("/api/v1/auth/register", json=registration_body())
    first = auth_client.post("/api/v1/auth/login", json=login_body()).json()["access_token"]
    second = auth_client.post("/api/v1/auth/login", json=login_body()).json()["access_token"]
    assert first != second
    assert auth_client.post("/api/v1/auth/logout", headers=access_headers(first)).status_code == 204
    assert auth_client.get("/api/v1/auth/me", headers=access_headers(first)).status_code == 401
    assert auth_client.get("/api/v1/auth/me", headers=access_headers(second)).status_code == 200


@pytest.mark.parametrize("authorization", [None, "Basic abc", "Bearer garbage"])
def test_protected_endpoints_reject_missing_or_invalid_tokens(auth_client, authorization):
    headers = {"Authorization": authorization} if authorization is not None else {}
    response = auth_client.get("/api/v1/auth/me", headers=headers)
    assert response.status_code == 401
    assert response.headers["www-authenticate"] == "Bearer"
    assert auth_client.post("/api/v1/auth/logout", headers=headers).status_code == 401


def test_expired_and_unregistered_tokens_cannot_access_me(auth_client):
    auth_client.post("/api/v1/auth/register", json=registration_body())
    original = auth_client.post("/api/v1/auth/login", json=login_body()).json()["access_token"]
    claims = jwt.decode(original, options={"verify_signature": False})
    secret = "only-for-tests-0123456789-abcdefghijklmnopqrstuv"

    expired = {**claims, "exp": int(datetime.now(timezone.utc).timestamp()) - 100}
    expired_token = jwt.encode(expired, secret, algorithm="HS256")
    assert auth_client.get("/api/v1/auth/me", headers=access_headers(expired_token)).status_code == 401

    never_issued = {**claims, "jti": str(uuid4())}
    forged_token = jwt.encode(never_issued, secret, algorithm="HS256")
    assert auth_client.get("/api/v1/auth/me", headers=access_headers(forged_token)).status_code == 401

    wrong_audience = {**claims, "aud": "not-our-client"}
    wrong_aud_token = jwt.encode(wrong_audience, secret, algorithm="HS256")
    assert auth_client.get("/api/v1/auth/me", headers=access_headers(wrong_aud_token)).status_code == 401


def test_student_affairs_can_use_same_login_without_self_registration(auth_client, migrated_engine):
    with Session(migrated_engine) as session:
        affairs = User(
            full_name="Affairs Officer",
            email="affairs@example.edu",
            university_id="STAFF-01",
            password_hash=hash_password("OfficerPassphrase#123"),
            account_type=AccountType.STUDENT_AFFAIRS,
        )
        session.add(affairs)
        session.commit()
    response = auth_client.post(
        "/api/v1/auth/login",
        json={"email": " AFFAIRS@EXAMPLE.EDU ", "password": "OfficerPassphrase#123"},
    )
    assert response.status_code == 200, response.text
    profile = auth_client.get("/api/v1/auth/me", headers=access_headers(response.json()["access_token"]))
    assert profile.status_code == 200
    assert profile.json()["account_type"] == "student_affairs"


def test_short_or_missing_jwt_secret_fails_closed(auth_client, monkeypatch):
    auth_client.post("/api/v1/auth/register", json=registration_body())
    monkeypatch.setenv("JWT_SECRET_KEY", "short")
    response = auth_client.post("/api/v1/auth/login", json=login_body())
    assert response.status_code == 503
    assert response.json() == {"detail": "Authentication unavailable"}


def test_login_invalid_payload_never_echoes_credentials(auth_client):
    secret = "DoNotEchoThisSecret"
    response = auth_client.post(
        "/api/v1/auth/login",
        json={"email": "not-email", "password": secret, "account_type": "student_affairs"},
    )
    assert response.status_code == 422
    assert secret not in response.text
    assert all("input" not in error for error in response.json()["detail"])


_AFFAIRS_PATH = "/api/v1/auth/student-affairs"


@pytest.mark.parametrize("authorization", [None, "Bearer invalid"])
def test_student_affairs_requires_valid_authentication(auth_client, authorization):
    headers = {"Authorization": authorization} if authorization else {}
    response = auth_client.get(_AFFAIRS_PATH, headers=headers)
    assert response.status_code == 401
    assert response.headers["www-authenticate"] == "Bearer"


def test_student_role_cannot_be_overridden_by_client(auth_client):
    assert auth_client.post(
        "/api/v1/auth/register", json=registration_body(account_type="student_affairs")
    ).status_code == 422
    assert auth_client.post("/api/v1/auth/register", json=registration_body()).status_code == 201
    response = auth_client.post("/api/v1/auth/login", json=login_body())
    assert response.status_code == 200
    headers = {**access_headers(response.json()["access_token"]), "X-Role": "student_affairs"}
    denied = auth_client.get(_AFFAIRS_PATH, headers=headers, params={"account_type": "student_affairs"})
    assert denied.status_code == 403
    claims = jwt.decode(response.json()["access_token"], options={"verify_signature": False})
    claims["account_type"] = "student_affairs"
    token_with_role = jwt.encode(claims, get_jwt_secret(), algorithm="HS256")
    assert auth_client.get(_AFFAIRS_PATH, headers=access_headers(token_with_role)).status_code == 403


def test_student_affairs_role_uses_current_db_account_and_rejects_expired_revoked_tokens(
    auth_client, migrated_engine
):
    with Session(migrated_engine) as session:
        user = User(
            full_name="Synthetic Affairs Officer",
            email="affairs@example.edu",
            university_id="OFFICE-01",
            password_hash=hash_password("SyntheticAffairsPassword123!"),
            account_type=AccountType.STUDENT_AFFAIRS,
        )
        session.add(user)
        session.commit()
        user_id = user.id

    response = auth_client.post(
        "/api/v1/auth/login",
        json={"email": "affairs@example.edu", "password": "SyntheticAffairsPassword123!"},
    )
    assert response.status_code == 200
    token = response.json()["access_token"]
    headers = access_headers(token)
    allowed = auth_client.get(_AFFAIRS_PATH, headers=headers)
    assert allowed.status_code == 200
    assert allowed.json() == {"account_type": "student_affairs"}

    claims = jwt.decode(token, options={"verify_signature": False})
    claims["exp"] = int((datetime.now(timezone.utc) - timedelta(minutes=1)).timestamp())
    expired = jwt.encode(claims, get_jwt_secret(), algorithm="HS256")
    assert auth_client.get(_AFFAIRS_PATH, headers=access_headers(expired)).status_code == 401

    with Session(migrated_engine) as session:
        session.get(User, user_id).account_type = AccountType.STUDENT
        session.commit()
    assert auth_client.get(_AFFAIRS_PATH, headers=headers).status_code == 403
    assert auth_client.post("/api/v1/auth/logout", headers=headers).status_code == 204
    assert auth_client.get(_AFFAIRS_PATH, headers=headers).status_code == 401


@pytest.mark.parametrize("changes", [
    {"email": " STUDENT@EXAMPLE.EDU ", "university_id": "DIFFERENT-ID"},
    {"email": "officer@example.edu", "university_id": " ab-123 "},
])
def test_affairs_provisioning_rejects_duplicates_without_promoting(
    registration_client, migrated_engine, changes
):
    assert registration_client.post("/api/v1/auth/register", json=registration_body()).status_code == 201
    data = AccountCreationInput.model_validate(registration_body(**changes))
    with Session(migrated_engine) as session:
        with pytest.raises(DuplicateAccountError):
            create_account(session, data, AccountType.STUDENT_AFFAIRS)
        users = session.query(User).all()
        assert len(users) == 1
        assert users[0].account_type is AccountType.STUDENT
