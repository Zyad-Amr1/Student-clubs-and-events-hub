"""Private profile updates and password changes for the current account."""
from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, ConfigDict, Field, field_validator, model_validator
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.auth.dependencies import AuthenticatedIdentity, current_identity, require_roles
from app.auth.passwords import PasswordHashCapacityError, hash_password, verify_password
from app.auth.schemas import AccountCreationInput, AuthenticatedUser
from app.database import get_db
from app.images import MAX_IMAGE_BASE64, normalized_image
from app.models.user import AccountType, User

router = APIRouter(prefix="/api/v1/auth", tags=["Account management"])
STUDENT = require_roles(AccountType.STUDENT)
FACULTIES = {
    "Engineering": ["Computer Engineering", "Electrical Engineering", "Mechanical Engineering"],
    "Science": ["Computer Science", "Mathematics", "Physics"],
    "Business": ["Accounting", "Management"],
}
YEARS = [1, 2, 3, 4, 5]


class ProfileUpdate(BaseModel):
    model_config = ConfigDict(extra="forbid")

    full_name: str = Field(min_length=2, max_length=120)
    faculty: str | None = Field(default=None, max_length=80)
    department: str | None = Field(default=None, max_length=80)
    academic_year: int | None = Field(default=None, strict=True)
    picture_base64: str | None = Field(default=None, max_length=MAX_IMAGE_BASE64)

    @field_validator("full_name", mode="before")
    @classmethod
    def normalize_name(cls, value):
        return AccountCreationInput.normalize_name(value)

    @model_validator(mode="after")
    def validate_academics(self):
        if self.faculty is not None and self.faculty not in FACULTIES:
            raise ValueError("Select a faculty from the demo catalog.")
        if self.department is not None and self.department not in FACULTIES.get(self.faculty, []):
            raise ValueError("Select a department for the selected faculty.")
        if self.academic_year is not None and self.academic_year not in YEARS:
            raise ValueError("Select an academic year from the demo catalog.")
        return self


class PasswordChange(BaseModel):
    model_config = ConfigDict(extra="forbid")

    current_password: str = Field(min_length=1, max_length=128)
    new_password: str = Field(min_length=8, max_length=128)
    confirm_password: str = Field(min_length=8, max_length=128)

    @model_validator(mode="after")
    def validate_password(self):
        if self.new_password != self.confirm_password:
            raise ValueError("New passwords do not match.")
        if self.current_password == self.new_password:
            raise ValueError("Choose a different new password.")
        return self


@router.get("/academic-catalog")
def academic_catalog(_: Annotated[AuthenticatedIdentity, Depends(STUDENT)]):
    return {"faculties": FACULTIES, "years": YEARS}


@router.put("/me", response_model=AuthenticatedUser)
def edit_profile(
    data: ProfileUpdate,
    identity: Annotated[AuthenticatedIdentity, Depends(STUDENT)],
    db: Annotated[Session, Depends(get_db)],
):
    user = identity.user
    if "picture_base64" in data.model_fields_set:
        try:
            user.profile_picture_url = (
                normalized_image(data.picture_base64) if data.picture_base64 is not None else None
            )
        except ValueError as error:
            raise HTTPException(422, str(error)) from None
    user.full_name = data.full_name
    user.faculty = data.faculty
    user.department = data.department
    user.academic_year = data.academic_year
    db.commit()
    db.refresh(user)
    return user


@router.post("/me/password", status_code=204)
def change_password(
    data: PasswordChange,
    identity: Annotated[AuthenticatedIdentity, Depends(current_identity)],
    db: Annotated[Session, Depends(get_db)],
):
    user = db.scalar(
        select(User).where(User.id == identity.user.id)
        .with_for_update().execution_options(populate_existing=True)
    )
    if user is None or not user.is_active:
        raise HTTPException(401, "Invalid or expired session")
    try:
        if not verify_password(data.current_password, user.password_hash):
            raise HTTPException(400, "Current password is incorrect.")
        user.password_hash = hash_password(data.new_password)
    except PasswordHashCapacityError:
        raise HTTPException(
            503, "Authentication temporarily unavailable", headers={"Retry-After": "1"}
        ) from None
    db.commit()
