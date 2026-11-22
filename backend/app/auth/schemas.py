"""Validated public registration contract for the Android client."""

from datetime import datetime
from typing import Literal
from uuid import UUID

from pydantic import BaseModel, ConfigDict, EmailStr, Field, field_validator, model_validator


class StudentRegistrationRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    full_name: str = Field(min_length=2, max_length=120)
    email: EmailStr
    university_id: str = Field(min_length=1, max_length=64)
    password: str = Field(min_length=8, max_length=128)
    confirm_password: str = Field(min_length=8, max_length=128)

    @field_validator("full_name", mode="before")
    @classmethod
    def normalize_name(cls, value: object) -> object:
        if not isinstance(value, str):
            return value
        value = value.strip()
        if any(ord(char) < 32 or ord(char) == 127 for char in value):
            raise ValueError("Full name contains invalid characters")
        return value

    @field_validator("email")
    @classmethod
    def normalize_email(cls, value: str) -> str:
        return value.strip().casefold()

    @field_validator("university_id", mode="before")
    @classmethod
    def normalize_university_id(cls, value: object) -> object:
        if not isinstance(value, str):
            return value
        value = value.strip().upper()
        if any(ord(char) < 32 or ord(char) == 127 for char in value):
            raise ValueError("University ID contains invalid characters")
        return value

    @model_validator(mode="after")
    def validate_confirmation(self) -> "StudentRegistrationRequest":
        if self.password != self.confirm_password:
            raise ValueError("Passwords do not match")
        return self


class RegisteredStudent(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    full_name: str
    email: str
    university_id: str
    account_type: Literal["student"]
    is_active: bool
    created_at: datetime
