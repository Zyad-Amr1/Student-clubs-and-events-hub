"""Interactive local CLI for provisioning Student Affairs accounts."""

import sys
import warnings
from collections.abc import Sequence
from getpass import GetPassWarning, getpass

from pydantic import ValidationError
from sqlalchemy.exc import SQLAlchemyError
from sqlalchemy.orm import Session

from app.auth.accounts import DuplicateAccountError, create_account
from app.auth.schemas import AccountCreationInput
from app.config import DatabaseConfigurationError, get_database_url
from app.database import get_engine
from app.models.user import AccountType


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
            create_account(db, data, AccountType.STUDENT_AFFAIRS)
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
