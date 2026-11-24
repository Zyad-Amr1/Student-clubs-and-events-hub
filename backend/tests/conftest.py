"""Shared fixtures for tests backed by the disposable PostgreSQL database."""

import os
from pathlib import Path

import pytest
from alembic import command
from alembic.config import Config
from fastapi.testclient import TestClient
from sqlalchemy import URL, create_engine, inspect, text
from sqlalchemy.orm import Session

from app.database import get_db
from app.main import app


@pytest.fixture
def bdd_context():
    """Share scenario-specific data between Gherkin step functions."""
    return {}


@pytest.fixture(scope="module")
def migrated_engine():
    """Create and later remove the schema only on the dedicated test database."""
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
                assert inspect(engine).has_table("clubs")
                assert inspect(engine).has_table("events")
                command.check(alembic_config)
                yield engine
            finally:
                command.downgrade(alembic_config, "base")
                with engine.begin() as connection:
                    assert not inspect(connection).has_table("users")
                    assert not inspect(connection).has_table("clubs")
                    assert not inspect(connection).has_table("events")
                    assert connection.scalar(
                        text("SELECT to_regprocedure('campusconnect_users_before_update()')")
                    ) is None
                    assert connection.scalar(
                        text("SELECT to_regprocedure('campusconnect_clubs_before_update()')")
                    ) is None
                    assert connection.scalar(
                        text("SELECT to_regprocedure('campusconnect_events_before_update()')")
                    ) is None
                    # The fixture started with an empty database and owns this table.
                    connection.execute(text("DROP TABLE alembic_version"))
    finally:
        engine.dispose()


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
            connection.execute(text("DELETE FROM events"))
            connection.execute(text("DELETE FROM clubs"))
            connection.execute(text("DELETE FROM users"))


@pytest.fixture
def auth_client(registration_client, monkeypatch):
    """Use the shared auth routes and a test-only JWT signing key."""
    monkeypatch.setenv("JWT_SECRET_KEY", "only-for-tests-0123456789-abcdefghijklmnopqrstuv")
    return registration_client
