"""Public registration and login, authenticated profiles, and account-type checks."""

from typing import Literal
from uuid import uuid4

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.auth.accounts import DuplicateAccountError, create_account
from app.auth.dependencies import AuthenticatedIdentity, current_identity, require_roles
from app.auth.passwords import hash_password, verify_password
from app.auth.tokens import ACCESS_TOKEN_TTL, issue_token, utcnow
from app.config import AuthenticationConfigurationError
from app.auth.schemas import (
    AuthenticatedUser, LoginRequest, RegisteredStudent,
    StudentRegistrationRequest, TokenResponse,
)
from app.database import get_db
from app.models.auth_session import AuthSession
from app.models.user import AccountType, User

router = APIRouter(prefix="/api/v1/auth", tags=["Authentication"])


@router.post(
    "/register",
    response_model=RegisteredStudent,
    status_code=status.HTTP_201_CREATED,
    responses={409: {"description": "Email or university ID already registered"}},
)
def register_student(
    data: StudentRegistrationRequest,
    db: Session = Depends(get_db),
) -> User:
    """Create a Student. Unique constraints enforce duplicates atomically."""
    try:
        user = create_account(db, data, AccountType.STUDENT)
    except DuplicateAccountError:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="An account with these details already exists",
        ) from None

    db.refresh(user)
    return user


def _bad_login() -> HTTPException:
    return HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Invalid email or password",
        headers={"WWW-Authenticate": "Bearer"},
    )


@router.post("/login", response_model=TokenResponse)
def login(data: LoginRequest, db: Session = Depends(get_db)) -> TokenResponse:
    """Issue a revocable, expiring JWT for a valid, active account."""
    user = db.scalar(select(User).where(User.email == data.email))
    if user is None:
        # Perform the same memory-hard work even for an unknown email.
        hash_password(data.password)
        raise _bad_login()

    verified = verify_password(data.password, user.password_hash)
    if not verified or not user.is_active:
        raise _bad_login()

    now = utcnow()
    token_id = uuid4()
    try:
        encoded, expires = issue_token(user.id, token_id, now)
    except AuthenticationConfigurationError:
        raise HTTPException(status_code=503, detail="Authentication unavailable") from None

    db.add(AuthSession(id=token_id, user_id=user.id, expires_at=expires))
    db.commit()
    return TokenResponse(
        access_token=encoded,
        expires_in=int(ACCESS_TOKEN_TTL.total_seconds()),
    )


@router.get("/me", response_model=AuthenticatedUser)
def authenticated_me(identity: AuthenticatedIdentity = Depends(current_identity)) -> User:
    """Return only a safe profile after validating the session on the server."""
    return identity.user


@router.get(
    "/student-affairs",
    dependencies=[Depends(require_roles(AccountType.STUDENT_AFFAIRS))],
    responses={
        401: {"description": "Invalid or expired session"},
        403: {"description": "Insufficient permissions"},
    },
)
def student_affairs_access() -> dict[str, Literal["student_affairs"]]:
    """Confirm that the authenticated account has Student Affairs access."""
    return {"account_type": "student_affairs"}


@router.post("/logout", status_code=status.HTTP_204_NO_CONTENT)
def logout(
    identity: AuthenticatedIdentity = Depends(current_identity),
    db: Session = Depends(get_db),
) -> None:
    """Revoke this token immediately without invalidating other sessions."""
    identity.session.revoked_at = utcnow()
    db.commit()
