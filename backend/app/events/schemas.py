"""Strict contracts for creating unpublished draft club events."""

from datetime import datetime, timezone
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field, field_validator, model_validator

from app.models.event import EventApprovalStatus


class DraftEventCreate(BaseModel):
    model_config = ConfigDict(extra="forbid", str_strip_whitespace=True)

    title: str = Field(min_length=1, max_length=160)
    description: str = Field(min_length=1, max_length=10_000)
    venue: str = Field(min_length=1, max_length=200)
    starts_at: datetime
    ends_at: datetime | None = None
    seat_capacity: int = Field(strict=True, ge=1, le=100_000)

    @field_validator("starts_at", "ends_at")
    @classmethod
    def require_aware_utc(cls, value: datetime | None) -> datetime | None:
        if value is None:
            return None
        if value.tzinfo is None or value.utcoffset() is None:
            raise ValueError("Event times must include a timezone offset")
        return value.astimezone(timezone.utc)

    @model_validator(mode="after")
    def validate_schedule(self):
        if self.starts_at <= datetime.now(timezone.utc):
            raise ValueError("Event start must be in the future")
        if self.ends_at is not None and self.ends_at <= self.starts_at:
            raise ValueError("Event end must be later than event start")
        return self


class DraftEventResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    club_id: UUID
    title: str
    description: str
    venue: str
    starts_at: datetime
    ends_at: datetime | None
    seat_capacity: int
    approval_status: EventApprovalStatus
    is_published: bool
    created_at: datetime
    updated_at: datetime
