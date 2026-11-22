"""Public student registration, with no privilege or password fields in responses."""

from uuid import uuid4

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.auth.dependencies import AuthenticatedIdentity, current_identity
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

_UNIQUE_USER_CONSTRAINTS = {"uq_users_email", "uq_users_university_id"}


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
    user = User(
        full_name=data.full_name,
        email=data.email,
        university_id=data.university_id,
        password_hash=hash_password(data.password),
        account_type=AccountType.STUDENT,
    )
    db.add(user)
    try:
        db.commit()
    except IntegrityError as error:
        db.rollback()
        constraint = getattr(getattr(error.orig, "diag", None), "constraint_name", None)
        if constraint in _UNIQUE_USER_CONSTRAINTS:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="An account with these details already exists",
            ) from None
        raise

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


@router.post("/logout", status_code=status.HTTP_204_NO_CONTENT)
def logout(
    identity: AuthenticatedIdentity = Depends(current_identity),
    db: Session = Depends(get_db),
) -> None:
    """Revoke this token immediately without invalidating other sessions."""
    identity.session.revoked_at = utcnow()
    db.commit()
