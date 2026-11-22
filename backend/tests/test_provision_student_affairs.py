from contextlib import nullcontext
from unittest.mock import MagicMock

from sqlalchemy.engine import make_url

from app.auth import provision_student_affairs as cli
from app.models.user import AccountType


_DATABASE_URL = make_url(
    "postgresql+psycopg://operator:synthetic-db-password@db.example.edu:5432/campusconnect"
)
_DATABASE_TARGET = "db.example.edu:5432/campusconnect"


def configure_prompts(monkeypatch, *, email="synthetic@example.edu", confirmation="synthetic-passphrase"):
    fields = iter((_DATABASE_TARGET, "Synthetic Officer", email, " office-10 "))
    passwords = iter(("synthetic-passphrase", confirmation))
    monkeypatch.setattr("builtins.input", lambda _: next(fields))
    monkeypatch.setattr(cli, "getpass", lambda _: next(passwords))
    monkeypatch.setattr(cli.sys.stdin, "isatty", lambda: True)
    monkeypatch.setattr(cli, "get_database_url", lambda: _DATABASE_URL, raising=False)


def test_provisioning_confirms_target_before_collecting_account_details(monkeypatch, capsys):
    configure_prompts(monkeypatch)
    prompt = MagicMock(return_value="wrong-database")
    monkeypatch.setattr("builtins.input", prompt)
    get_engine = MagicMock()
    monkeypatch.setattr(cli, "get_engine", get_engine)

    assert cli.main([]) == 1
    prompt.assert_called_once()
    get_engine.assert_not_called()
    captured = capsys.readouterr()
    output = captured.out + captured.err
    assert _DATABASE_TARGET in output
    assert "synthetic-db-password" not in output


def test_provisioning_refuses_database_without_explicit_host_or_name(monkeypatch, capsys):
    configure_prompts(monkeypatch)
    monkeypatch.setattr(
        cli,
        "get_database_url",
        lambda: make_url("postgresql+psycopg://operator:synthetic-db-password@localhost"),
    )
    prompt = MagicMock()
    monkeypatch.setattr("builtins.input", prompt)
    get_engine = MagicMock()
    monkeypatch.setattr(cli, "get_engine", get_engine)

    assert cli.main([]) == 1
    prompt.assert_not_called()
    get_engine.assert_not_called()
    output = capsys.readouterr().err
    assert "target database" in output.lower()
    assert "synthetic-db-password" not in output


def test_provisioning_rejects_invalid_input_before_opening_database(monkeypatch, capsys):
    configure_prompts(monkeypatch, confirmation="mismatch")
    engine = MagicMock()
    monkeypatch.setattr(cli, "get_engine", engine)
    assert cli.main([]) == 1
    engine.assert_not_called()
    assert "synthetic-passphrase" not in capsys.readouterr().err


def test_provisioning_uses_validated_values_and_explicit_affairs_role(monkeypatch, capsys):
    configure_prompts(monkeypatch, email=" Synthetic@Example.EDU ")
    monkeypatch.setattr(cli, "get_engine", lambda: object())
    session = object()
    monkeypatch.setattr(cli, "Session", lambda _: nullcontext(session))
    create_account = MagicMock()
    monkeypatch.setattr(cli, "create_account", create_account)

    assert cli.main([]) == 0
    passed_session, credentials, role = create_account.call_args.args
    assert passed_session is session
    assert credentials.email == "synthetic@example.edu"
    assert credentials.university_id == "OFFICE-10"
    assert role is AccountType.STUDENT_AFFAIRS
    captured = capsys.readouterr()
    assert "synthetic-passphrase" not in captured.out + captured.err


def test_provisioning_rejects_command_line_credentials_without_echo(capsys):
    assert cli.main(["--password", "synthetic-passphrase"]) == 1
    assert "synthetic-passphrase" not in capsys.readouterr().err


def test_provisioning_reports_duplicate_without_printing_details(monkeypatch, capsys):
    configure_prompts(monkeypatch)
    monkeypatch.setattr(cli, "get_engine", lambda: object())
    monkeypatch.setattr(cli, "Session", lambda _: nullcontext(object()))
    monkeypatch.setattr(
        cli, "create_account", MagicMock(side_effect=cli.DuplicateAccountError("private detail"))
    )
    assert cli.main([]) == 1
    output = capsys.readouterr().err
    assert "already exists" in output
    assert "private detail" not in output
