"""Create accounts after the caller selects the account type."""

from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.auth.passwords import hash_password
from app.auth.schemas import AccountCreationInput
from app.models.user import AccountType, User

_UNIQUE_USER_CONSTRAINTS = {"uq_users_email", "uq_users_university_id"}


class DuplicateAccountError(Exception):
    """An account already uses one of the supplied identifiers."""


def create_account(db: Session, data: AccountCreationInput, account_type: AccountType) -> User:
    user = User(
        full_name=data.full_name,
        email=data.email,
        university_id=data.university_id,
        password_hash=hash_password(data.password),
        account_type=account_type,
    )
    db.add(user)
    try:
        db.commit()
    except IntegrityError as error:
        db.rollback()
        constraint = getattr(getattr(error.orig, "diag", None), "constraint_name", None)
        if constraint in _UNIQUE_USER_CONSTRAINTS:
            raise DuplicateAccountError from None
        raise
    return user
