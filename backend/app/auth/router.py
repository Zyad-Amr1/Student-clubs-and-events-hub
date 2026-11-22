"""Public student registration, with no privilege or password fields in responses."""

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.auth.passwords import hash_password
from app.auth.schemas import RegisteredStudent, StudentRegistrationRequest
from app.database import get_db
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
