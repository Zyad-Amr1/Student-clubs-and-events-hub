"""Student event reservation response contracts."""

from datetime import datetime
from typing import Literal
from uuid import UUID

from pydantic import BaseModel, ConfigDict


class ReservedEventDetails(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    club_id: UUID
    title: str
    description: str
    venue: str
    starts_at: datetime
    ends_at: datetime | None
    seat_capacity: int


class EventReservationResponse(BaseModel):
    event_id: UUID
    status: Literal["confirmed", "waitlisted"]
    waitlist_position: int | None
    event: ReservedEventDetails


class MyReservationsResponse(BaseModel):
    reservations: list[EventReservationResponse]
