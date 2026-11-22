import os
from datetime import timedelta
from pathlib import Path
from uuid import UUID

import pytest
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
