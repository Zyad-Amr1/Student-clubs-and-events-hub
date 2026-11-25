"""A Student's active confirmed or waitlisted place at an event."""

from datetime import datetime
from typing import Literal
from uuid import UUID

from sqlalchemy import (
    BigInteger,
    CheckConstraint,
    DateTime,
    ForeignKey,
    Identity,
    Index,
    String,
    UniqueConstraint,
    Uuid,
    func,
)
from sqlalchemy.orm import Mapped, mapped_column

from app.database import Base

ReservationStatus = Literal["confirmed", "waitlisted"]


class EventReservation(Base):
    __tablename__ = "event_reservations"
    __table_args__ = (
        CheckConstraint(
            "status IN ('confirmed', 'waitlisted', 'cancelled')",
            name="ck_event_reservations_status",
        ),
        UniqueConstraint(
            "event_id", "user_id", name="uq_event_reservations_event_user"
        ),
        Index(
            "ix_event_reservations_event_status_id", "event_id", "status", "id"
        ),
        Index("ix_event_reservations_user_id", "user_id"),
    )

    # PostgreSQL assigns this monotonically increasing value after the event
    # row is locked, so it is also the persisted FIFO order for that event.
    id: Mapped[int] = mapped_column(
        BigInteger, Identity(always=False), primary_key=True
    )
    event_id: Mapped[UUID] = mapped_column(
        Uuid,
        ForeignKey("events.id", ondelete="CASCADE", name="fk_event_reservations_event_id"),
        nullable=False,
    )
    user_id: Mapped[UUID] = mapped_column(
        Uuid,
        ForeignKey("users.id", ondelete="CASCADE", name="fk_event_reservations_user_id"),
        nullable=False,
    )
    status: Mapped[str] = mapped_column(String(16), nullable=False)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, server_default=func.now()
    )
