"""Public response schemas for club browsing and event details."""

from datetime import datetime, timezone
from uuid import UUID

from pydantic import BaseModel, ConfigDict, field_validator


class ClubSummary(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    name: str
    description: str
    category: str
    logo_url: str | None


class ClubBrowseResponse(BaseModel):
    clubs: list[ClubSummary]
    page: int
    page_size: int
    total: int


class EventSummary(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    title: str
    description: str
    venue: str
    starts_at: datetime
    ends_at: datetime | None
    seat_capacity: int

    @field_validator("starts_at", "ends_at")
    @classmethod
    def normalize_datetime_to_utc(cls, value: datetime | None) -> datetime | None:
        if value is None:
            return None
        if value.tzinfo is None or value.utcoffset() is None:
            raise ValueError("Event times must include a timezone")
        return value.astimezone(timezone.utc)


class ClubDetailsResponse(BaseModel):
    club: ClubSummary
    events: list[EventSummary]
    page: int
    page_size: int
    total: int
