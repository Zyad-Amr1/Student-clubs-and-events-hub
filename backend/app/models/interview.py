from datetime import date, datetime
from uuid import UUID

from sqlalchemy import CheckConstraint, Date, DateTime, ForeignKey, Index, Integer, String, Text, UniqueConstraint, Uuid, func, text
from sqlalchemy.dialects.postgresql import JSONB
from sqlalchemy.orm import Mapped, mapped_column

from app.database import Base


class InterviewDay(Base):
    __tablename__ = "interview_days"
    __table_args__ = (
        UniqueConstraint("club_id", "day", name="uq_interview_days_club_day"),
        CheckConstraint("capacity > 0", name="ck_interview_days_capacity"),
        CheckConstraint("duration_minutes BETWEEN 1 AND 1440", name="ck_interview_days_duration"),
    )

    id: Mapped[UUID] = mapped_column(Uuid, primary_key=True, server_default=text("gen_random_uuid()"))
    club_id: Mapped[UUID] = mapped_column(ForeignKey("clubs.id", ondelete="CASCADE"))
    day: Mapped[date] = mapped_column(Date)
    capacity: Mapped[int] = mapped_column(Integer)
    duration_minutes: Mapped[int] = mapped_column(Integer, server_default=text("15"))
    periods: Mapped[list] = mapped_column(JSONB, server_default=text("'[]'::jsonb"))
    cancelled_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))


class InterviewCancellation(Base):
    __tablename__ = "interview_cancellations"

    id: Mapped[UUID] = mapped_column(Uuid, primary_key=True, server_default=text("gen_random_uuid()"))
    day_id: Mapped[UUID] = mapped_column(ForeignKey("interview_days.id", ondelete="CASCADE"))
    actor_id: Mapped[UUID] = mapped_column(ForeignKey("users.id", ondelete="RESTRICT"))
    target: Mapped[dict] = mapped_column(JSONB)
    reason: Mapped[str] = mapped_column(Text)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())


class InterviewSelection(Base):
    __tablename__ = "interview_selections"
    __table_args__ = (
        Index("uq_interview_selections_active_application", "application_id", unique=True,
              postgresql_where=text("released_at IS NULL")),
        Index("ix_interview_selections_day", "day_id"),
        CheckConstraint(
            "(starts_at IS NULL AND ends_at IS NULL AND published_at IS NULL) OR "
            "(starts_at IS NOT NULL AND ends_at IS NOT NULL AND published_at IS NOT NULL "
            "AND (released_at IS NULL OR cancellation_id IS NOT NULL) AND ends_at > starts_at)",
            name="ck_interview_selections_confirmed",
        ),
        CheckConstraint(
            "cancellation_id IS NULL OR (released_at IS NOT NULL AND attendance IS NULL)",
            name="ck_interview_selections_cancellation",
        ),
        CheckConstraint(
            "(attendance IS NULL AND attendance_at IS NULL AND attendance_by IS NULL) OR "
            "(attendance IS NOT NULL AND attendance IN ('attended', 'no_show') AND attendance_at IS NOT NULL "
            "AND attendance_by IS NOT NULL AND published_at IS NOT NULL AND released_at IS NULL "
            "AND attendance_at >= ends_at)",
            name="ck_interview_selections_attendance",
        ),
        CheckConstraint(
            "expired_at IS NULL OR (released_at IS NOT NULL AND published_at IS NULL "
            "AND cancellation_id IS NULL AND expired_at <= released_at)",
            name="ck_interview_selections_expiry",
        ),
    )

    id: Mapped[UUID] = mapped_column(Uuid, primary_key=True, server_default=text("gen_random_uuid()"))
    application_id: Mapped[UUID] = mapped_column(ForeignKey("membership_applications.id", ondelete="CASCADE"))
    day_id: Mapped[UUID] = mapped_column(ForeignKey("interview_days.id", ondelete="CASCADE"))
    selected_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=text("clock_timestamp()"))
    released_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    starts_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    ends_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    published_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    cancellation_id: Mapped[UUID | None] = mapped_column(
        ForeignKey("interview_cancellations.id", ondelete="CASCADE"),
    )
    expired_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    attendance: Mapped[str | None] = mapped_column(String(12))
    attendance_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    attendance_by: Mapped[UUID | None] = mapped_column(ForeignKey("users.id", ondelete="RESTRICT"))


class InterviewNotice(Base):
    __tablename__ = "interview_notices"
    __table_args__ = (
        UniqueConstraint("application_id", "event_key", name="uq_interview_notices_event"),
    )

    id: Mapped[UUID] = mapped_column(Uuid, primary_key=True, server_default=text("gen_random_uuid()"))
    application_id: Mapped[UUID] = mapped_column(ForeignKey("membership_applications.id", ondelete="CASCADE"))
    event_key: Mapped[str] = mapped_column(String(80))
    kind: Mapped[str] = mapped_column(String(20))
    message: Mapped[str] = mapped_column(Text)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
