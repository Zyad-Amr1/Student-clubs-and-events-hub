"""Interactive local CLI for provisioning Student Affairs accounts."""

import sys
import warnings
from collections.abc import Sequence
from getpass import GetPassWarning, getpass

from pydantic import ValidationError
from sqlalchemy import select, text
from sqlalchemy.exc import SQLAlchemyError
from sqlalchemy.orm import Session

from app.auth.accounts import DuplicateAccountError, create_account
from app.auth.passwords import PasswordHashCapacityError
from app.auth.schemas import AccountCreationInput
from app.config import DatabaseConfigurationError, get_database_url
from app.database import get_engine
from app.models.user import AccountType, User


def _confirm_target_database() -> bool:
    try:
        url = get_database_url()
        host = url.host
        port = url.port
        database = url.database
    except (DatabaseConfigurationError, ValueError):
        print("Provisioning failed. Check database configuration.", file=sys.stderr)
        return False

    if not host or not database:
        print(
            "Provisioning cancelled: DATABASE_URL must specify the target database host and name.",
            file=sys.stderr,
        )
        return False

    if host.startswith("/"):
        target = f"socket={host} database={database}"
    else:
        host = f"[{host}]" if ":" in host else host
        target = f"{host}:{port or 5432}/{database}"
    print(f"Target PostgreSQL database: {target}")
    try:
        confirmation = input("Type that exact target to continue: ")
    except (EOFError, KeyboardInterrupt, OSError):
        print("Provisioning cancelled.", file=sys.stderr)
        return False

    if confirmation != target:
        print("Target database was not confirmed; provisioning cancelled.", file=sys.stderr)
        return False
    return True




def _student_affairs_exists(db: Session) -> bool:
    """Operational singleton guard, not a concurrent database constraint."""
    return db.scalar(
        select(User.id)
        .where(User.account_type == AccountType.STUDENT_AFFAIRS)
        .limit(1)
    ) is not None


def _refuse_second_account() -> None:
    print(
        "A Student Affairs account already exists. "
        "Provisioning another account was cancelled. "
        "Contact the authorized university administrator for recovery.",
        file=sys.stderr,
    )


def _lock_student_affairs_provisioning(db: Session) -> None:
    """Serialize this trusted CLI across processes on the same PostgreSQL DB.

    The transaction-scoped advisory lock lasts across the existence check and
    create_account(db,...), which commits and releases it. Never run outside
    the same Session/transaction or commit before the insert.
    """
    db.execute(
        text("SELECT pg_advisory_xact_lock(:lock_key)"),
        {"lock_key": 0x43414D5043414646},
    )

def main(argv: Sequence[str] | None = None) -> int:
    if argv is None:
        argv = sys.argv[1:]
    if list(argv) in (["--help"], ["-h"]):
        print("Run from backend: python -m app.auth.provision_student_affairs")
        print("Prompts for account details and reads the password without echo.")
        return 0
    if argv or not sys.stdin.isatty():
        print("Use an interactive terminal and pass no arguments.", file=sys.stderr)
        return 1
    if not _confirm_target_database():
        return 1

    try:
        full_name = input("Full name: ")
        email = input("Email: ")
        university_id = input("University ID: ")
        with warnings.catch_warnings():
            warnings.simplefilter("error", GetPassWarning)
            password = getpass("Password: ")
            confirmation = getpass("Confirm password: ")
        data = AccountCreationInput(
            full_name=full_name, email=email, university_id=university_id,
            password=password, confirm_password=confirmation,
        )
    except ValidationError:
        print("Invalid account details or password confirmation.", file=sys.stderr)
        return 1
    except (EOFError, KeyboardInterrupt, GetPassWarning, OSError):
        print("Provisioning cancelled or secure input unavailable.", file=sys.stderr)
        return 1

    try:
        with Session(get_engine()) as db:
            _lock_student_affairs_provisioning(db)
            # Check the operational singleton before insertion, after the
            # existing input validation. Not a DB-wide concurrent singleton.
            if _student_affairs_exists(db):
                _refuse_second_account()
                return 1
            create_account(db, data, AccountType.STUDENT_AFFAIRS)
    except PasswordHashCapacityError:
        print("Provisioning temporarily busy. Retry securely.", file=sys.stderr)
        return 1
    except DuplicateAccountError:
        print("An account with these identifiers already exists.", file=sys.stderr)
        return 1
    except (DatabaseConfigurationError, ImportError, SQLAlchemyError, ValueError):
        print("Provisioning failed. Check database configuration and availability.", file=sys.stderr)
        return 1
    print("Student Affairs account created.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
