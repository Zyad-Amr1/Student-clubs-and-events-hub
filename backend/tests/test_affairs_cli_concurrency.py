"""PostgreSQL advisory transaction-lock regression for two trusted CLI invocations."""

from concurrent.futures import ThreadPoolExecutor
from threading import Barrier, get_ident
from types import SimpleNamespace

from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.auth import provision_student_affairs as cli
from app.models.user import AccountType, User
from test_event_creation import draft_client, draft_test_engine


def test_concurrent_provisioning_creates_only_one_account(
    draft_client, draft_test_engine, monkeypatch, capsys
):
    monkeypatch.setattr(cli.sys, "stdin", SimpleNamespace(isatty=lambda: True))
    monkeypatch.setattr(cli, "_confirm_target_database", lambda: True)
    monkeypatch.setattr(cli, "get_engine", lambda: draft_test_engine)
    barrier = Barrier(2, timeout=10)

    def prompt(label):
        if label == "Full name: ":
            barrier.wait()
            return "Disposable Affairs"
        if label == "Email: ":
            return f"affairs-lock-{get_ident()}@example.edu"
        if label == "University ID: ":
            return f"LOCK-{get_ident()}"
        raise AssertionError(f"Unexpected interactive prompt: {label}")

    monkeypatch.setattr("builtins.input", prompt)
    monkeypatch.setattr(cli, "getpass", lambda label: "DisposableAffairsPass#123")

    with ThreadPoolExecutor(max_workers=2) as pool:
        first = pool.submit(cli.main, [])
        second = pool.submit(cli.main, [])
        results = [first.result(timeout=40), second.result(timeout=40)]

    assert sorted(results) == [0, 1], results
    with Session(draft_test_engine) as session:
        assert session.scalar(
            select(func.count()).select_from(User).where(
                User.account_type == AccountType.STUDENT_AFFAIRS
            )
        ) == 1
