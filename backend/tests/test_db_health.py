from unittest.mock import MagicMock

from fastapi.testclient import TestClient
from sqlalchemy.exc import OperationalError

from app import main


def test_database_ready(monkeypatch) -> None:
    engine = MagicMock()
    connection = engine.connect.return_value.__enter__.return_value
    monkeypatch.setattr(main, "get_engine", lambda: engine)

    with TestClient(main.app) as client:
        response = client.get("/api/v1/health/db")

    assert response.status_code == 200
    assert response.json() == {"status": "ok"}
    assert str(connection.execute.call_args.args[0]) == "SELECT 1"
    engine.connect.return_value.__exit__.assert_called_once()


def test_database_connection_failure_is_sanitized(monkeypatch, caplog) -> None:
    engine = MagicMock()
    engine.connect.side_effect = OperationalError(
        None, None, RuntimeError("sensitive driver diagnostic")
    )
    monkeypatch.setattr(main, "get_engine", lambda: engine)

    with TestClient(main.app) as client:
        response = client.get("/api/v1/health/db")
        assert client.get("/health").status_code == 200

    assert response.status_code == 503
    assert response.json() == {"detail": "Database unavailable"}
    assert "sensitive driver diagnostic" not in caplog.text


def test_database_query_failure_is_sanitized(monkeypatch) -> None:
    engine = MagicMock()
    connection = engine.connect.return_value.__enter__.return_value
    connection.execute.side_effect = OperationalError(
        None, None, RuntimeError("sensitive driver diagnostic")
    )
    monkeypatch.setattr(main, "get_engine", lambda: engine)

    with TestClient(main.app) as client:
        response = client.get("/api/v1/health/db")

    assert response.status_code == 503
    assert response.json() == {"detail": "Database unavailable"}
    engine.connect.return_value.__exit__.assert_called_once()


def test_database_driver_failure_is_sanitized(monkeypatch) -> None:
    get_engine = MagicMock(side_effect=ImportError("sensitive driver diagnostic"))
    monkeypatch.setattr(main, "get_engine", get_engine)

    with TestClient(main.app) as client:
        response = client.get("/api/v1/health/db")

    assert response.status_code == 503
    assert response.json() == {"detail": "Database unavailable"}
