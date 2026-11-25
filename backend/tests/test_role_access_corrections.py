"""Targeted MVP role-access regressions on disposable PostgreSQL 18 only."""

import importlib.util
from pathlib import Path
from types import SimpleNamespace
from uuid import uuid4

import pytest
from sqlalchemy import func, select, text
from sqlalchemy.orm import Session

from app.auth import provision_student_affairs
from app.models.user import AccountType, User
from test_club_admin_assignment import assign, assignments
from test_event_creation import (
    draft_client,
    draft_test_engine,
    grant_admin,
    payload,
    post_event,
    scenario,
    synthetic_test_password_hash,
)


def portal(client, headers):
    return client.get("/api/v1/auth/club-admin/clubs", headers=headers)


def revoke(client, club_id, headers=None):
    return client.delete(
        f"/api/v1/auth/student-affairs/clubs/{club_id}/administrator",
        headers=headers or {},
    )


def update_club(engine, club_id, *, approval=None, active=None):
    changes = []
    values = {"id": club_id}
    if approval is not None:
        changes.append("approval_status = :approval")
        values["approval"] = approval
    if active is not None:
        changes.append("is_active = :active")
        values["active"] = active
    assert changes
    with engine.begin() as connection:
        connection.execute(
            text(f"UPDATE clubs SET {', '.join(changes)} WHERE id = :id"),
            values,
        )


@pytest.mark.parametrize("approval", ["pending", "rejected"])
def test_unapproved_active_club_cannot_receive_new_admin(
    draft_client, draft_test_engine, scenario, approval
):
    ids, headers = scenario["ids"], scenario["headers"]
    update_club(draft_test_engine, ids["club"], approval=approval)
    response = assign(draft_client, ids["club"], ids["owner"], headers["affairs"])
    assert response.status_code == 404
    assert response.json() == {"detail": "Club not found"}
    assert assignments(draft_test_engine, ids["club"]) == []


@pytest.mark.parametrize("approval", ["pending", "rejected"])
def test_existing_grant_becomes_unusable_when_approval_changes(
    draft_client, draft_test_engine, scenario, approval
):
    ids, headers = scenario["ids"], scenario["headers"]
    assert assign(draft_client, ids["club"], ids["owner"], headers["affairs"]).status_code == 200
    assert portal(draft_client, headers["owner"]).status_code == 200
    update_club(draft_test_engine, ids["club"], approval=approval)
    assert portal(draft_client, headers["owner"]).status_code == 403
    assert post_event(draft_client, ids["club"], payload(), headers["owner"]).status_code == 404
    assert draft_client.get(
        f"/api/v1/clubs/{ids['club']}", headers=headers["owner"]
    ).status_code == 404
    assert [str(x) for x in assignments(draft_test_engine, ids["club"])] == [
        str(ids["owner"])
    ]
    # No implicit deletion; restoring approval restores the current grant.
    update_club(draft_test_engine, ids["club"], approval="approved")
    assert portal(draft_client, headers["owner"]).status_code == 200


def test_active_flag_removes_admin_access_without_removing_grant(
    draft_client, draft_test_engine, scenario
):
    ids, headers = scenario["ids"], scenario["headers"]
    assert assign(draft_client, ids["club"], ids["owner"], headers["affairs"]).status_code == 200
    update_club(draft_test_engine, ids["club"], active=False)
    assert portal(draft_client, headers["owner"]).status_code == 403
    assert post_event(draft_client, ids["club"], payload(), headers["owner"]).status_code == 404
    assert assign(draft_client, ids["club"], ids["student"], headers["affairs"]).status_code == 404
    assert len(assignments(draft_test_engine, ids["club"])) == 1


def test_revoke_is_idempotent_and_cannot_delete_student_or_club(
    draft_client, draft_test_engine, scenario
):
    ids, headers = scenario["ids"], scenario["headers"]
    grant_admin(draft_test_engine, ids["club"], ids["owner"])
    assert revoke(draft_client, ids["club"], headers["affairs"]).status_code == 204
    assert revoke(draft_client, ids["club"], headers["affairs"]).status_code == 204
    assert assignments(draft_test_engine, ids["club"]) == []
    assert portal(draft_client, headers["owner"]).status_code == 403
    assert post_event(draft_client, ids["club"], payload(), headers["owner"]).status_code == 404
    me = draft_client.get("/api/v1/auth/me", headers=headers["owner"])
    assert me.status_code == 200 and me.json()["account_type"] == "student"
    # Existing Student discovery and the Club record are unchanged.
    details = draft_client.get(f"/api/v1/clubs/{ids['club']}", headers=headers["owner"])
    assert details.status_code == 200


@pytest.mark.parametrize("approval,active", [
    ("pending", True),
    ("rejected", True),
    ("approved", False),
])
def test_revocation_allowed_after_club_becomes_unapproved_or_inactive(
    draft_client, draft_test_engine, scenario, approval, active
):
    ids, headers = scenario["ids"], scenario["headers"]
    grant_admin(draft_test_engine, ids["club"], ids["owner"])
    update_club(draft_test_engine, ids["club"], approval=approval, active=active)
    assert revoke(draft_client, ids["club"], headers["affairs"]).status_code == 204
    assert assignments(draft_test_engine, ids["club"]) == []
    assert revoke(draft_client, ids["club"], headers["affairs"]).status_code == 204


def test_revocation_is_scoped_and_old_jwt_does_not_restore_privilege(
    draft_client, draft_test_engine, scenario
):
    ids, headers = scenario["ids"], scenario["headers"]
    grant_admin(draft_test_engine, ids["club"], ids["owner"])
    grant_admin(draft_test_engine, ids["other"], ids["owner"])
    assert revoke(draft_client, ids["club"], headers["affairs"]).status_code == 204
    assert assignments(draft_test_engine, ids["club"]) == []
    assert [str(x) for x in assignments(draft_test_engine, ids["other"])] == [
        str(ids["owner"])
    ]
    result = portal(draft_client, headers["owner"])
    assert result.status_code == 200
    assert [x["id"] for x in result.json()["clubs"]] == [str(ids["other"])]
    assert post_event(draft_client, ids["club"], payload(), headers["owner"]).status_code == 404
    assert post_event(draft_client, ids["other"], payload(), headers["owner"]).status_code == 201


def test_only_authenticated_affairs_can_revoke(
    draft_client, draft_test_engine, scenario
):
    ids, headers = scenario["ids"], scenario["headers"]
    grant_admin(draft_test_engine, ids["club"], ids["owner"])
    for forbidden in ({}, {"Authorization": "Bearer invalid"}):
        assert revoke(draft_client, ids["club"], forbidden).status_code == 401
    for role in ("student", "owner"):
        assert revoke(draft_client, ids["club"], headers[role]).status_code == 403
    assert len(assignments(draft_test_engine, ids["club"])) == 1
    # Logout revokes the JWT used for subsequent privileged requests.
    assert draft_client.post("/api/v1/auth/logout", headers=headers["affairs"]).status_code == 204
    assert revoke(draft_client, ids["club"], headers["affairs"]).status_code == 401
    assert len(assignments(draft_test_engine, ids["club"])) == 1


def test_revoke_unknown_club_returns_404_without_mutations(draft_client, scenario):
    assert revoke(draft_client, uuid4(), scenario["headers"]["affairs"]).status_code == 404


def test_unapproved_club_never_leaks_through_spoofed_admin_query(
    draft_client, draft_test_engine, scenario
):
    ids, headers = scenario["ids"], scenario["headers"]
    grant_admin(draft_test_engine, ids["club"], ids["owner"])
    update_club(draft_test_engine, ids["club"], approval="pending")
    response = draft_client.get(
        f"/api/v1/auth/club-admin/clubs?club_id={ids['club']}&role=student_affairs",
        headers=headers["owner"],
    )
    assert response.status_code == 403
    assert post_event(draft_client, ids["club"], payload(), headers["owner"]).status_code == 404


def test_second_affairs_provisioning_is_blocked_before_account_creation(
    draft_client, draft_test_engine, scenario, monkeypatch, capsys
):
    from app.auth import provision_student_affairs as cli

    monkeypatch.setattr(cli.sys, "stdin", SimpleNamespace(isatty=lambda: True))
    monkeypatch.setattr(cli, "_confirm_target_database", lambda: True)
    monkeypatch.setattr(cli, "get_engine", lambda: draft_test_engine)

    prompts = iter([
        "Temporary Staff",
        "temporary-staff@example.edu",
        "TEMP-STAFF",
    ])
    monkeypatch.setattr("builtins.input", lambda prompt="": next(prompts))
    monkeypatch.setattr(cli, "getpass", lambda prompt: "TemporaryStaffPassword#123")
    assert cli.main([]) == 1
    captured = capsys.readouterr()
    assert "already exists" in captured.err
    assert "draft-affairs@example.edu" not in captured.err
    with Session(draft_test_engine) as db:
        assert db.scalar(
            select(func.count()).select_from(User).where(
                User.account_type == AccountType.STUDENT_AFFAIRS
            )
        ) == 1


def test_provisioning_one_affairs_account_still_works_then_refuses_second(
    draft_client, draft_test_engine, monkeypatch, capsys
):
    from app.auth import provision_student_affairs as cli

    monkeypatch.setattr(cli.sys, "stdin", SimpleNamespace(isatty=lambda: True))
    monkeypatch.setattr(cli, "_confirm_target_database", lambda: True)
    monkeypatch.setattr(cli, "get_engine", lambda: draft_test_engine)
    supplied = iter([
        "Disposable Staff", "disposable-staff@example.edu", "DISP-STAFF",
        "Disposable Staff", "disposable-staff@example.edu", "DISP-STAFF",
    ])
    monkeypatch.setattr("builtins.input", lambda prompt="": next(supplied))
    monkeypatch.setattr(cli, "getpass", lambda prompt: "DisposableStaffPassword#123")
    assert cli.main([]) == 0
    assert cli.main([]) == 1
    assert "already exists" in capsys.readouterr().err
    with Session(draft_test_engine) as db:
        assert db.scalar(
            select(func.count()).select_from(User).where(
                User.account_type == AccountType.STUDENT_AFFAIRS
            )
        ) == 1
    login = draft_client.post("/api/v1/auth/login", json={
        "email": "disposable-staff@example.edu",
        "password": "DisposableStaffPassword#123",
    })
    assert login.status_code == 200
    authorized = draft_client.get(
        "/api/v1/auth/student-affairs",
        headers={"Authorization": "Bearer " + login.json()["access_token"]},
    )
    assert authorized.status_code == 200


def test_0006_duplicate_preflight_rejects_without_deleting_grants(
    draft_test_engine, draft_client, scenario, monkeypatch
):
    """Rollback a test-only DDL transaction, retaining the fixture's migrated schema."""
    ids = scenario["ids"]
    path = Path(__file__).resolve().parents[1] / "migrations" / "versions" / "0006_one_admin_per_club.py"
    spec = importlib.util.spec_from_file_location("test_mvp_migration_0006", path)
    assert spec is not None and spec.loader is not None
    migration = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(migration)
    with draft_test_engine.connect() as connection:
        transaction = connection.begin()
        try:
            connection.execute(text(
                "ALTER TABLE club_administrators "
                "DROP CONSTRAINT uq_club_administrators_club_id"
            ))
            for uid in (ids["owner"], ids["student"]):
                connection.execute(
                    text(
                        "INSERT INTO club_administrators (club_id,user_id) "
                        "VALUES (:c,:u)"
                    ),
                    {"c": ids["club"], "u": uid},
                )
            monkeypatch.setattr(migration.op, "get_bind", lambda: connection)
            with pytest.raises(RuntimeError, match="Duplicate club administrator assignments"):
                migration.upgrade()
            assert connection.execute(
                text("SELECT count(*) FROM club_administrators WHERE club_id=:c"),
                {"c": ids["club"]},
            ).scalar_one() == 2
        finally:
            transaction.rollback()
    # The unique constraint is restored by PostgreSQL transactional DDL.
    with draft_test_engine.connect() as connection:
        assert connection.execute(
            text(
                "SELECT count(*) FROM pg_constraint "
                "WHERE conname = 'uq_club_administrators_club_id'"
            )
        ).scalar_one() == 1
        assert connection.execute(
            text("SELECT count(*) FROM club_administrators WHERE club_id=:c"),
            {"c": ids["club"]},
        ).scalar_one() == 0
