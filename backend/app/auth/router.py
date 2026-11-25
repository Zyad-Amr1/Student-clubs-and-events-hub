"""Public registration and login, authenticated profiles, and account-type checks."""

from typing import Literal
from uuid import UUID, uuid4

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import delete, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.auth.accounts import DuplicateAccountError, create_account
from app.auth.dependencies import AuthenticatedIdentity, current_identity, require_roles
from app.auth.passwords import PasswordHashCapacityError, hash_password, verify_password
from app.auth.tokens import ACCESS_TOKEN_TTL, issue_token, utcnow
from app.config import AuthenticationConfigurationError
from app.auth.schemas import (
    AuthenticatedUser, LoginRequest, RegisteredStudent,
    StudentRegistrationRequest, TokenResponse, ManagedClubsResponse,
    ClubAdministratorAssignment, ClubAdministratorAssignmentResponse,
)
from app.database import get_db
from app.models.auth_session import AuthSession
from app.models.user import AccountType, User
from app.models.club import Club, ClubApprovalStatus
from app.models.club_administrator import ClubAdministrator
from app.models.club_head_request import ClubHeadRequest

router = APIRouter(prefix="/api/v1/auth", tags=["Authentication"])



def _hash_capacity_unavailable() -> HTTPException:
    return HTTPException(
        status_code=503,
        detail="Authentication temporarily unavailable",
        headers={"Retry-After": "1"},
    )


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
    except PasswordHashCapacityError:
        raise _hash_capacity_unavailable() from None
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
    try:
        if user is None:
            # Match the cost for unknown emails to avoid account enumeration.
            hash_password(data.password)
            raise _bad_login()
        verified = verify_password(data.password, user.password_hash)
    except PasswordHashCapacityError:
        raise _hash_capacity_unavailable() from None
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


@router.get(
    "/club-admin/clubs",
    response_model=ManagedClubsResponse,
    responses={
        401: {"description": "Missing, expired or revoked session"},
        403: {"description": "No active club administrator membership"},
    },
)
def get_managed_clubs(
    identity: AuthenticatedIdentity = Depends(current_identity),
    db: Session = Depends(get_db),
) -> dict:
    """Resolve current club-scoped privileges from the database on every request.

    This is not a role-granting endpoint. Portal selection and JWT claims
    cannot confer a membership. Archived clubs stay visible read-only to
    their assigned admin so lifecycle status and reason remain accessible.
    """
    if identity.user.account_type != AccountType.STUDENT:
        raise HTTPException(status_code=403, detail="Insufficient permissions")

    clubs = _active_managed_clubs(db, identity.user.id)
    if not clubs:
        raise HTTPException(status_code=403, detail="Insufficient permissions")
    return {"clubs": clubs}


@router.get("/me/managed-clubs", response_model=ManagedClubsResponse)
def my_managed_clubs(
    identity: AuthenticatedIdentity = Depends(require_roles(AccountType.STUDENT)),
    db: Session = Depends(get_db),
) -> dict:
    return {"clubs": _active_managed_clubs(db, identity.user.id)}


def _active_managed_clubs(db: Session, user_id: UUID):
    return db.scalars(
        select(Club)
        .join(ClubAdministrator, ClubAdministrator.club_id == Club.id)
        .where(
            ClubAdministrator.user_id == user_id,
            (Club.is_active.is_(True) | Club.archived_at.is_not(None)),
            Club.approval_status == ClubApprovalStatus.APPROVED,
        )
        .order_by(Club.name.asc(), Club.id.asc())
    ).all()


@router.put(
    "/student-affairs/clubs/{club_id}/administrator",
    response_model=ClubAdministratorAssignmentResponse,
    dependencies=[Depends(require_roles(AccountType.STUDENT_AFFAIRS))],
    responses={
        401: {"description": "Invalid or revoked JWT"},
        403: {"description": "Student Affairs role required"},
        404: {"description": "Club not found or inactive"},
        409: {"description": "Concurrent assignment conflict; retry"},
        422: {"description": "Target must be an active Student account"},
    },
)
def assign_club_administrator(
    club_id: UUID,
    data: ClubAdministratorAssignment,
    db: Session = Depends(get_db),
) -> ClubAdministratorAssignmentResponse:
    """Student Affairs replaces the sole admin under a per-club row lock.

    External verification of the student's eligibility is a trusted
    Student Affairs workflow prerequisite, not a client-selected role.
    This operation never creates accounts or modifies Student privileges.
    """
    club = db.scalar(
        select(Club).where(
            Club.id == club_id,
            Club.is_active.is_(True),
            Club.approval_status == ClubApprovalStatus.APPROVED,
        ).with_for_update()
    )
    if club is None:
        raise HTTPException(status_code=404, detail="Club not found")

    candidate = db.get(User, data.student_id)
    if (
        candidate is None
        or not candidate.is_active
        or candidate.account_type != AccountType.STUDENT
    ):
        raise HTTPException(
            status_code=422, detail="Target must be an active Student account"
        )

    existing = db.scalar(
        select(ClubAdministrator).where(ClubAdministrator.club_id == club.id)
    )
    if existing is not None and existing.user_id == candidate.id:
        db.commit()  # release the club lock without making another grant
        return ClubAdministratorAssignmentResponse(
            club_id=club.id, user_id=candidate.id
        )

    if db.scalar(select(ClubHeadRequest.id).where(
        ClubHeadRequest.club_id == club.id, ClubHeadRequest.status == "pending",
    )) is not None:
        raise HTTPException(409, "Review the pending Club Head application first.")

    # DELETE executes before INSERT. The two operations share one transaction;
    # on failure, the previous administrator remains unchanged.
    if existing is not None:
        db.execute(
            delete(ClubAdministrator).where(
                ClubAdministrator.club_id == club.id
            )
        )
    db.add(ClubAdministrator(club_id=club.id, user_id=candidate.id))
    try:
        db.commit()
    except IntegrityError:
        db.rollback()
        raise HTTPException(
            status_code=409, detail="Administrator assignment conflict; retry"
        ) from None
    return ClubAdministratorAssignmentResponse(
        club_id=club.id, user_id=candidate.id
    )


@router.delete(
    "/student-affairs/clubs/{club_id}/administrator",
    status_code=status.HTTP_204_NO_CONTENT,
    dependencies=[Depends(require_roles(AccountType.STUDENT_AFFAIRS))],
    responses={
        401: {"description": "Invalid, expired or revoked JWT"},
        403: {"description": "Student Affairs role required"},
        404: {"description": "Club not found"},
    },
)
def revoke_club_administrator(
    club_id: UUID,
    db: Session = Depends(get_db),
) -> None:
    """Revoke only the club-specific grant, including for inactive/unapproved clubs.

    The club lock serializes this operation with assignment/replacement.
    A second call is safe: the existing club still returns 204.
    No Student account, Club, or other club's grant is modified.
    """
    club = db.scalar(
        select(Club).where(Club.id == club_id).with_for_update()
    )
    if club is None:
        raise HTTPException(status_code=404, detail="Club not found")
    db.execute(
        delete(ClubAdministrator).where(
            ClubAdministrator.club_id == club.id
        )
    )
    db.commit()
