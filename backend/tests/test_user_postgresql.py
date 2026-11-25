from datetime import datetime, timedelta, timezone
from uuid import UUID, uuid4

import pytest
import jwt

from app.auth.accounts import DuplicateAccountError, create_account
from app.auth.passwords import hash_password, verify_password
from app.auth.schemas import AccountCreationInput
from app.auth.tokens import JWT_AUDIENCE, JWT_ISSUER
from app.config import get_jwt_secret
from app.models.club import Club, ClubApprovalStatus
from app.models.event import Event, EventApprovalStatus
from sqlalchemy import text
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.models.user import AccountType, User


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

def login_body(**changes):
    return {"email": " STUDENT@EXAMPLE.EDU ", "password": "StrongPassphrase#123", **changes}


def access_headers(token):
    return {"Authorization": f"Bearer {token}"}


def _student_access_headers(auth_client):
    assert auth_client.post("/api/v1/auth/register", json=registration_body()).status_code == 201
    login = auth_client.post("/api/v1/auth/login", json=login_body())
    assert login.status_code == 200
    return access_headers(login.json()["access_token"])


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


def test_student_browses_only_approved_active_clubs(auth_client, migrated_engine):
    headers = _student_access_headers(auth_client)
    with Session(migrated_engine) as session:
        session.add_all(
            [
                Club(
                    name="Zulu Robotics",
                    description="Robotics club",
                    category="Technology",
                    approval_status=ClubApprovalStatus.APPROVED,
                    is_active=True,
                    logo_url="https://example.edu/zulu.png",
                ),
                Club(
                    name="Alpha Arts",
                    description="Arts club",
                    category="Arts",
                    approval_status=ClubApprovalStatus.APPROVED,
                    is_active=True,
                ),
                Club(
                    name="Pending Club",
                    description="Pending club",
                    category="Academic",
                    approval_status=ClubApprovalStatus.PENDING,
                    is_active=True,
                ),
                Club(
                    name="Rejected Club",
                    description="Rejected club",
                    category="Academic",
                    approval_status=ClubApprovalStatus.REJECTED,
                    is_active=True,
                ),
                Club(
                    name="Inactive Club",
                    description="Inactive club",
                    category="Academic",
                    approval_status=ClubApprovalStatus.APPROVED,
                    is_active=False,
                ),
            ]
        )
        session.commit()

    response = auth_client.get("/api/v1/clubs", headers=headers)

    assert response.status_code == 200, response.text
    body = response.json()
    assert body["page"] == 1
    assert body["page_size"] == 20
    assert body["total"] == 2
    assert [club["name"] for club in body["clubs"]] == ["Alpha Arts", "Zulu Robotics"]
    assert set(body["clubs"][0]) == {"id", "name", "description", "category", "logo_url"}
    assert body["clubs"][1]["logo_url"] == "https://example.edu/zulu.png"
    assert all(
        hidden_name not in response.text
        for hidden_name in ("Pending Club", "Rejected Club", "Inactive Club")
    )


def test_club_search_and_category_filter_only_public_clubs(auth_client, migrated_engine):
    headers = _student_access_headers(auth_client)
    with Session(migrated_engine) as session:
        session.add_all(
            [
                Club(name="Aero Robotics", description="Aero", category="TECHNOLOGY",
                     approval_status=ClubApprovalStatus.APPROVED, is_active=True),
                Club(name="Robotics Society", description="Robotics", category="Technology",
                     approval_status=ClubApprovalStatus.APPROVED, is_active=True),
                Club(name="Robot Academy", description="Academy", category="Academic",
                     approval_status=ClubApprovalStatus.APPROVED, is_active=True),
                Club(name="Arts Collective", description="Arts", category="Arts",
                     approval_status=ClubApprovalStatus.APPROVED, is_active=True),
                Club(name="Pending Robotics", description="Hidden pending", category="Technology",
                     approval_status=ClubApprovalStatus.PENDING, is_active=True),
                Club(name="Rejected Robotics", description="Hidden rejected", category="Technology",
                     approval_status=ClubApprovalStatus.REJECTED, is_active=True),
                Club(name="Inactive Robotics", description="Hidden inactive", category="Technology",
                     approval_status=ClubApprovalStatus.APPROVED, is_active=False),
            ]
        )
        session.commit()

    search = auth_client.get("/api/v1/clubs", headers=headers, params={"search": "  rObOt  "})
    assert search.status_code == 200, search.text
    assert search.json()["total"] == 3
    assert [club["name"] for club in search.json()["clubs"]] == [
        "Aero Robotics", "Robot Academy", "Robotics Society"
    ]

    category = auth_client.get("/api/v1/clubs", headers=headers, params={"category": "  technology  "})
    assert category.status_code == 200, category.text
    assert category.json()["total"] == 2
    assert [club["name"] for club in category.json()["clubs"]] == [
        "Aero Robotics", "Robotics Society"
    ]

    combined = auth_client.get(
        "/api/v1/clubs",
        headers=headers,
        params={"search": " ROBOT ", "category": " TeChNoLoGy "},
    )
    assert combined.status_code == 200, combined.text
    assert combined.json()["total"] == 2
    assert [club["name"] for club in combined.json()["clubs"]] == [
        "Aero Robotics", "Robotics Society"
    ]
    assert set(combined.json()["clubs"][0]) == {
        "id", "name", "description", "category", "logo_url"
    }
    assert all(hidden not in combined.text for hidden in (
        "Pending Robotics", "Rejected Robotics", "Inactive Robotics",
    ))

    exact_category = auth_client.get(
        "/api/v1/clubs", headers=headers, params={"category": "tech"}
    )
    assert exact_category.status_code == 200
    assert exact_category.json()["total"] == 0
    assert exact_category.json()["clubs"] == []

    blank_filters = auth_client.get(
        "/api/v1/clubs", headers=headers, params={"search": "   ", "category": "  "}
    )
    assert blank_filters.status_code == 200
    assert blank_filters.json()["total"] == 4


def test_club_search_treats_wildcards_as_literal_text(auth_client, migrated_engine):
    headers = _student_access_headers(auth_client)
    with Session(migrated_engine) as session:
        session.add_all(
            [
                Club(name="100% Robotics", description="Percent", category="Technology",
                     approval_status=ClubApprovalStatus.APPROVED),
                Club(name="100X Robotics", description="Another", category="Technology",
                     approval_status=ClubApprovalStatus.APPROVED),
                Club(name="A_B Club", description="Underscore", category="Arts",
                     approval_status=ClubApprovalStatus.APPROVED),
                Club(name="AxB Club", description="Another", category="Arts",
                     approval_status=ClubApprovalStatus.APPROVED),
            ]
        )
        session.commit()

    percent = auth_client.get(
        "/api/v1/clubs", headers=headers, params={"search": "100%"}
    )
    underscore = auth_client.get(
        "/api/v1/clubs", headers=headers, params={"search": "A_B"}
    )
    assert percent.status_code == underscore.status_code == 200
    assert [club["name"] for club in percent.json()["clubs"]] == ["100% Robotics"]
    assert [club["name"] for club in underscore.json()["clubs"]] == ["A_B Club"]


def test_club_search_filters_before_pagination(auth_client, migrated_engine):
    headers = _student_access_headers(auth_client)
    with Session(migrated_engine) as session:
        session.add_all(
            [
                Club(name=name, description=name, category=category,
                     approval_status=ClubApprovalStatus.APPROVED)
                for name, category in (
                    ("Alpha Robotics", "Technology"),
                    ("Beta Robotics", "Technology"),
                    ("Gamma Robotics", "Technology"),
                    ("Arts Club", "Technology"),
                    ("Robotics Academy", "Academic"),
                )
            ]
        )
        session.commit()

    first = auth_client.get(
        "/api/v1/clubs", headers=headers,
        params={"search": "robotics", "category": "technology", "page": 1, "page_size": 1},
    )
    second = auth_client.get(
        "/api/v1/clubs", headers=headers,
        params={"search": "robotics", "category": "technology", "page": 2, "page_size": 1},
    )
    empty = auth_client.get(
        "/api/v1/clubs", headers=headers,
        params={"search": "robotics", "category": "technology", "page": 4, "page_size": 1},
    )
    assert first.status_code == second.status_code == empty.status_code == 200
    assert first.json()["total"] == second.json()["total"] == empty.json()["total"] == 3
    assert [c["name"] for c in first.json()["clubs"]] == ["Alpha Robotics"]
    assert [c["name"] for c in second.json()["clubs"]] == ["Beta Robotics"]
    assert empty.json()["clubs"] == []


def test_club_search_validates_bounds_and_enforces_authorization(auth_client, migrated_engine):
    headers = _student_access_headers(auth_client)
    invalid_search = auth_client.get(
        "/api/v1/clubs", headers=headers,
        params={"search": "x" * 121},
    )
    assert invalid_search.status_code == 422
    invalid_category = auth_client.get(
        "/api/v1/clubs",
        headers=headers,
        params={"category": "x" * 81},
    )
    assert invalid_category.status_code == 422
    missing_auth = auth_client.get(
        "/api/v1/clubs", params={"search": "Robotics", "category": "Technology"}
    )
    assert missing_auth.status_code == 401

    with Session(migrated_engine) as session:
        session.add(User(
            full_name="Search Affairs Officer",
            email="search-affairs@example.edu",
            university_id="SEARCH-AFFAIRS-01",
            password_hash=hash_password("SyntheticAffairsPassword123!"),
            account_type=AccountType.STUDENT_AFFAIRS,
        ))
        session.commit()
    login = auth_client.post(
        "/api/v1/auth/login",
        json={"email": "search-affairs@example.edu", "password": "SyntheticAffairsPassword123!"},
    )
    assert login.status_code == 200
    affairs = auth_client.get(
        "/api/v1/clubs",
        headers=access_headers(login.json()["access_token"]),
        params={"search": "Robotics", "category": "Technology"},
    )
    assert affairs.status_code == 403


def test_club_timestamps_are_database_managed(migrated_engine, registration_client):
    with Session(migrated_engine) as session:
        club = Club(
            name="Timestamp Club",
            description="Timestamp behavior",
            category="Academic",
            approval_status=ClubApprovalStatus.APPROVED,
        )
        session.add(club)
        session.commit()
        original_updated_at = club.updated_at
        assert club.id is not None
        assert club.created_at.utcoffset() is not None

        club.description = "Updated timestamp behavior"
        session.commit()
        session.refresh(club)

        assert club.updated_at > original_updated_at


def test_club_browse_paginates_deterministically_and_bounds_page_size(auth_client, migrated_engine):
    headers = _student_access_headers(auth_client)
    with Session(migrated_engine) as session:
        session.add_all(
            [
                Club(
                    id=UUID(int=club_id),
                    name=name,
                    description=f"{name} description",
                    category="Academic",
                    approval_status=ClubApprovalStatus.APPROVED,
                    is_active=True,
                )
                for club_id, name in (
                    (1, "Alpha Club"),
                    (2, "Alpha Club"),
                    (3, "Beta Club"),
                    (4, "Gamma Club"),
                )
            ]
        )
        session.commit()

    first_page = auth_client.get("/api/v1/clubs?page=1&page_size=2", headers=headers)
    second_page = auth_client.get("/api/v1/clubs?page=2&page_size=2", headers=headers)
    invalid_page = auth_client.get("/api/v1/clubs?page=0", headers=headers)
    oversized_page = auth_client.get("/api/v1/clubs?page_size=101", headers=headers)

    assert first_page.status_code == second_page.status_code == 200
    assert [club["id"] for club in first_page.json()["clubs"]] == [str(UUID(int=1)), str(UUID(int=2))]
    assert [club["name"] for club in second_page.json()["clubs"]] == ["Beta Club", "Gamma Club"]
    assert first_page.json()["total"] == second_page.json()["total"] == 4
    assert invalid_page.status_code == oversized_page.status_code == 422


def test_empty_club_browse_returns_empty_collection(auth_client):
    headers = _student_access_headers(auth_client)

    response = auth_client.get("/api/v1/clubs", headers=headers)

    assert response.status_code == 200
    assert response.json() == {"clubs": [], "page": 1, "page_size": 20, "total": 0}


def test_student_affairs_cannot_browse_student_clubs(auth_client, migrated_engine):
    with Session(migrated_engine) as session:
        session.add(
            User(
                full_name="Synthetic Affairs Officer",
                email="affairs@example.edu",
                university_id="AFFAIRS-01",
                password_hash=hash_password("SyntheticAffairsPassword123!"),
                account_type=AccountType.STUDENT_AFFAIRS,
            )
        )
        session.commit()

    login = auth_client.post(
        "/api/v1/auth/login",
        json={"email": "affairs@example.edu", "password": "SyntheticAffairsPassword123!"},
    )
    assert login.status_code == 200
    response = auth_client.get(
        "/api/v1/clubs", headers=access_headers(login.json()["access_token"])
    )

    assert response.status_code == 403


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


def test_student_sees_only_approved_published_future_events_for_visible_club(
    auth_client, migrated_engine
):
    headers = _student_access_headers(auth_client)
    now = datetime.now(timezone.utc)
    future = now + timedelta(days=2)
    past = now - timedelta(days=2)
    with Session(migrated_engine) as session:
        club = Club(
            name="Visible Event Club",
            description="Visible club description",
            category="Academic",
            approval_status=ClubApprovalStatus.APPROVED,
            is_active=True,
            logo_url="https://example.edu/club.png",
        )
        pending_club = Club(
            name="Pending Event Club",
            description="Hidden club description",
            category="Academic",
            approval_status=ClubApprovalStatus.PENDING,
            is_active=True,
        )
        other_club = Club(
            name="Other Visible Club",
            description="Different club description",
            category="Academic",
            approval_status=ClubApprovalStatus.APPROVED,
            is_active=True,
        )
        session.add_all([club, pending_club, other_club])
        session.flush()
        visible_club_id = club.id

        session.add_all(
            [
                Event(
                    club_id=club.id,
                    title="Visible future event",
                    description="Public event details",
                    venue="Main Hall",
                    starts_at=future,
                    ends_at=future + timedelta(hours=2),
                    seat_capacity=50,
                    approval_status=EventApprovalStatus.APPROVED,
                    is_published=True,
                ),
                Event(
                    club_id=club.id,
                    title="Draft event",
                    description="Draft details",
                    venue="Draft Room",
                    starts_at=future,
                    seat_capacity=10,
                    approval_status=EventApprovalStatus.DRAFT,
                    is_published=True,
                ),
                Event(
                    club_id=club.id,
                    title="Pending event",
                    description="Pending details",
                    venue="Pending Room",
                    starts_at=future,
                    seat_capacity=10,
                    approval_status=EventApprovalStatus.PENDING,
                    is_published=True,
                ),
                Event(
                    club_id=club.id,
                    title="Rejected event",
                    description="Rejected details",
                    venue="Rejected Room",
                    starts_at=future,
                    seat_capacity=10,
                    approval_status=EventApprovalStatus.REJECTED,
                    is_published=True,
                ),
                Event(
                    club_id=club.id,
                    title="Unpublished event",
                    description="Unpublished details",
                    venue="Private Room",
                    starts_at=future,
                    seat_capacity=10,
                    approval_status=EventApprovalStatus.APPROVED,
                    is_published=False,
                ),
                Event(
                    club_id=club.id,
                    title="Past event",
                    description="Past details",
                    venue="Old Hall",
                    starts_at=past,
                    seat_capacity=10,
                    approval_status=EventApprovalStatus.APPROVED,
                    is_published=True,
                ),
                Event(
                    club_id=other_club.id,
                    title="Other club event",
                    description="Other club details",
                    venue="Other Hall",
                    starts_at=future,
                    seat_capacity=10,
                    approval_status=EventApprovalStatus.APPROVED,
                    is_published=True,
                ),
                Event(
                    club_id=pending_club.id,
                    title="Hidden club event",
                    description="Hidden club event details",
                    venue="Hidden Hall",
                    starts_at=future,
                    seat_capacity=10,
                    approval_status=EventApprovalStatus.APPROVED,
                    is_published=True,
                ),
            ]
        )
        session.commit()

    response = auth_client.get(f"/api/v1/clubs/{visible_club_id}", headers=headers)

    assert response.status_code == 200, response.text
    body = response.json()
    assert set(body) == {"club", "events", "page", "page_size", "total"}
    assert body["club"] == {
        "id": str(visible_club_id),
        "name": "Visible Event Club",
        "description": "Visible club description",
        "category": "Academic",
        "logo_url": "https://example.edu/club.png",
    }
    assert body["page"] == 1
    assert body["page_size"] == 20
    assert body["total"] == 1
    assert [event["title"] for event in body["events"]] == ["Visible future event"]
    assert set(body["events"][0]) == {
        "id",
        "title",
        "description",
        "venue",
        "starts_at",
        "ends_at",
        "seat_capacity",
    }
    starts_at = datetime.fromisoformat(body["events"][0]["starts_at"].replace("Z", "+00:00"))
    assert starts_at.utcoffset() == timedelta(0)
    assert all(
        hidden_title not in response.text
        for hidden_title in (
            "Draft event",
            "Pending event",
            "Rejected event",
            "Unpublished event",
            "Past event",
            "Other club event",
            "Hidden club event",
        )
    )


@pytest.mark.parametrize(
    ("approval_status", "is_active"),
    [
        (ClubApprovalStatus.PENDING, True),
        (ClubApprovalStatus.REJECTED, True),
        (ClubApprovalStatus.APPROVED, False),
    ],
)
def test_student_gets_not_found_for_hidden_clubs(
    auth_client, migrated_engine, approval_status, is_active
):
    headers = _student_access_headers(auth_client)
    with Session(migrated_engine) as session:
        club = Club(
            name="Hidden Detail Club",
            description="Hidden club",
            category="Academic",
            approval_status=approval_status,
            is_active=is_active,
        )
        session.add(club)
        session.commit()
        club_id = club.id

    hidden = auth_client.get(f"/api/v1/clubs/{club_id}", headers=headers)
    nonexistent = auth_client.get(f"/api/v1/clubs/{uuid4()}", headers=headers)

    assert hidden.status_code == nonexistent.status_code == 404


def test_student_affairs_cannot_get_club_details(auth_client, migrated_engine):
    with Session(migrated_engine) as session:
        club = Club(
            name="Student Detail Club",
            description="Visible to Students",
            category="Academic",
            approval_status=ClubApprovalStatus.APPROVED,
            is_active=True,
        )
        officer = User(
            full_name="Synthetic Affairs Officer",
            email="details-affairs@example.edu",
            university_id="DETAILS-AFFAIRS-01",
            password_hash=hash_password("SyntheticAffairsPassword123!"),
            account_type=AccountType.STUDENT_AFFAIRS,
        )
        session.add_all([club, officer])
        session.commit()
        club_id = club.id

    login = auth_client.post(
        "/api/v1/auth/login",
        json={"email": "details-affairs@example.edu", "password": "SyntheticAffairsPassword123!"},
    )
    assert login.status_code == 200
    response = auth_client.get(
        f"/api/v1/clubs/{club_id}", headers=access_headers(login.json()["access_token"])
    )

    assert response.status_code == 403


def test_club_details_returns_empty_event_page(auth_client, migrated_engine):
    headers = _student_access_headers(auth_client)
    with Session(migrated_engine) as session:
        club = Club(
            name="Empty Events Club",
            description="No upcoming events",
            category="Academic",
            approval_status=ClubApprovalStatus.APPROVED,
            is_active=True,
        )
        session.add(club)
        session.commit()
        club_id = club.id

    response = auth_client.get(f"/api/v1/clubs/{club_id}", headers=headers)

    assert response.status_code == 200
    body = response.json()
    assert body["events"] == []
    assert body["page"] == 1
    assert body["page_size"] == 20
    assert body["total"] == 0


def test_club_details_paginates_events_by_start_time_then_uuid(auth_client, migrated_engine):
    headers = _student_access_headers(auth_client)
    starts_at = datetime.now(timezone.utc) + timedelta(days=3)
    with Session(migrated_engine) as session:
        club = Club(
            name="Pagination Events Club",
            description="Stable order",
            category="Academic",
            approval_status=ClubApprovalStatus.APPROVED,
            is_active=True,
        )
        session.add(club)
        session.flush()
        club_id = club.id
        session.add_all(
            [
                Event(
                    id=UUID(int=event_id),
                    club_id=club_id,
                    title=f"Event {event_id}",
                    description="Upcoming event",
                    venue="Main Hall",
                    starts_at=starts_at,
                    seat_capacity=25,
                    approval_status=EventApprovalStatus.APPROVED,
                    is_published=True,
                )
                for event_id in (1, 2, 3, 4)
            ]
        )
        session.commit()

    first_page = auth_client.get(
        f"/api/v1/clubs/{club_id}?page=1&page_size=2", headers=headers
    )
    second_page = auth_client.get(
        f"/api/v1/clubs/{club_id}?page=2&page_size=2", headers=headers
    )
    invalid_page = auth_client.get(f"/api/v1/clubs/{club_id}?page=0", headers=headers)
    oversized_page = auth_client.get(
        f"/api/v1/clubs/{club_id}?page_size=101", headers=headers
    )

    assert first_page.status_code == second_page.status_code == 200
    assert [event["id"] for event in first_page.json()["events"]] == [
        str(UUID(int=1)),
        str(UUID(int=2)),
    ]
    assert [event["id"] for event in second_page.json()["events"]] == [
        str(UUID(int=3)),
        str(UUID(int=4)),
    ]
    assert first_page.json()["total"] == second_page.json()["total"] == 4
    assert invalid_page.status_code == oversized_page.status_code == 422


@pytest.mark.parametrize(
    ("field", "constraint"),
    [
        ("title", "ck_events_title_nonblank"),
        ("seat_capacity", "ck_events_seat_capacity_positive"),
        ("ends_at", "ck_events_ends_after_start"),
    ],
)
def test_postgresql_enforces_event_field_constraints(migrated_engine, field, constraint):
    starts_at = datetime.now(timezone.utc) + timedelta(days=1)
    with Session(migrated_engine) as session:
        club = Club(
            name="Constraint Test Club",
            description="Event constraint test",
            category="Academic",
            approval_status=ClubApprovalStatus.APPROVED,
        )
        session.add(club)
        session.flush()
        event = Event(
            club_id=club.id,
            title="Valid event title",
            description="Valid event description",
            venue="Valid venue",
            starts_at=starts_at,
            ends_at=starts_at + timedelta(hours=1),
            seat_capacity=10,
            approval_status=EventApprovalStatus.APPROVED,
            is_published=True,
        )
        if field == "title":
            event.title = "\t\n"
        elif field == "seat_capacity":
            event.seat_capacity = 0
        else:
            event.ends_at = starts_at
        session.add(event)
        with pytest.raises(IntegrityError) as error:
            session.flush()
        assert error.value.orig.diag.constraint_name == constraint


def test_postgresql_enforces_event_club_foreign_key(migrated_engine):
    starts_at = datetime.now(timezone.utc) + timedelta(days=1)
    with Session(migrated_engine) as session:
        session.add(
            Event(
                club_id=uuid4(),
                title="Orphan event",
                description="Must reference a club",
                venue="Main Hall",
                starts_at=starts_at,
                seat_capacity=10,
            )
        )
        with pytest.raises(IntegrityError) as error:
            session.flush()
        assert error.value.orig.diag.constraint_name == "fk_events_club_id_clubs"


def test_postgresql_event_defaults_and_database_managed_timestamps(
    migrated_engine, registration_client
):
    starts_at = datetime.now(timezone.utc) + timedelta(days=1)
    with Session(migrated_engine) as session:
        club = Club(
            name="Event Timestamp Club",
            description="Event timestamp test",
            category="Academic",
            approval_status=ClubApprovalStatus.APPROVED,
        )
        session.add(club)
        session.flush()
        event = Event(
            club_id=club.id,
            title="Initial event title",
            description="Event defaults and timestamp behavior",
            venue="Main Hall",
            starts_at=starts_at,
            seat_capacity=10,
        )
        session.add(event)
        session.commit()
        original_updated_at = event.updated_at

        assert event.approval_status is EventApprovalStatus.DRAFT
        assert event.is_published is False
        assert event.created_at.utcoffset() is not None
        assert event.updated_at.utcoffset() is not None

        event.title = "Updated event title"
        session.commit()
        session.refresh(event)
        assert event.updated_at > original_updated_at
