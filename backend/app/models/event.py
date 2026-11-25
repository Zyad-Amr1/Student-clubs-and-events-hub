"""PostgreSQL-backed club events with separate approval and publication state."""

from datetime import datetime
from enum import StrEnum
from uuid import UUID

from sqlalchemy import (
    Boolean,
    CheckConstraint,
    DateTime,
    Enum,
    FetchedValue,
    ForeignKey,
    Index,
    Integer,
    String,
    Text,
    Uuid,
    func,
    text,
)
from sqlalchemy.orm import Mapped, mapped_column

from app.database import Base

_WHITESPACE = (
    r"U&' \0009\000A\000B\000C\000D\001C\001D\001E\001F"
    r"\0085\00A0\1680\2000\2001\2002\2003\2004\2005\2006\2007"
    r"\2008\2009\200A\2028\2029\202F\205F\3000'"
)


class EventApprovalStatus(StrEnum):
    DRAFT = "draft"
    PENDING = "pending"
    APPROVED = "approved"
    REJECTED = "rejected"


class Event(Base):
    __tablename__ = "events"
    __table_args__ = (
        CheckConstraint(f"btrim(title, {_WHITESPACE}) <> ''", name="ck_events_title_nonblank"),
        CheckConstraint(
            f"btrim(description, {_WHITESPACE}) <> ''",
            name="ck_events_description_nonblank",
        ),
        CheckConstraint(f"btrim(venue, {_WHITESPACE}) <> ''", name="ck_events_venue_nonblank"),
        CheckConstraint("seat_capacity > 0", name="ck_events_seat_capacity_positive"),
        CheckConstraint(
            "ends_at IS NULL OR ends_at > starts_at",
            name="ck_events_ends_after_start",
        ),
        Index(
            "ix_events_club_upcoming",
            "club_id",
            "approval_status",
            "is_published",
            "starts_at",
            "id",
        ),
    )

    id: Mapped[UUID] = mapped_column(
        Uuid, primary_key=True, server_default=text("gen_random_uuid()")
    )
    club_id: Mapped[UUID] = mapped_column(
        Uuid,
        ForeignKey("clubs.id", ondelete="CASCADE", name="fk_events_club_id_clubs"),
        nullable=False,
    )
    title: Mapped[str] = mapped_column(String(160), nullable=False)
    description: Mapped[str] = mapped_column(Text, nullable=False)
    venue: Mapped[str] = mapped_column(String(200), nullable=False)
    starts_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    ends_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    seat_capacity: Mapped[int] = mapped_column(Integer, nullable=False)
    approval_status: Mapped[EventApprovalStatus] = mapped_column(
        Enum(
            EventApprovalStatus,
            values_callable=lambda enum: [item.value for item in enum],
            native_enum=False,
            create_constraint=True,
            validate_strings=True,
            name="ck_events_approval_status",
        ),
        nullable=False,
        server_default=text("'draft'"),
    )
    is_published: Mapped[bool] = mapped_column(
        Boolean, nullable=False, server_default=text("false")
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, server_default=func.now()
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
        server_default=func.now(),
        server_onupdate=FetchedValue(),
    )
    cancelled_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    cancellation_reason: Mapped[str | None] = mapped_column(Text)
