from datetime import date, datetime
from uuid import UUID

from sqlalchemy import CheckConstraint, Date, DateTime, ForeignKey, Index, Integer, UniqueConstraint, Uuid, text
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


class InterviewSelection(Base):
    __tablename__ = "interview_selections"
    __table_args__ = (
        Index("uq_interview_selections_active_application", "application_id", unique=True,
              postgresql_where=text("released_at IS NULL")),
        Index("ix_interview_selections_day", "day_id"),
        CheckConstraint(
            "(starts_at IS NULL AND ends_at IS NULL AND published_at IS NULL) OR "
            "(starts_at IS NOT NULL AND ends_at IS NOT NULL AND published_at IS NOT NULL "
            "AND released_at IS NULL AND ends_at > starts_at)",
            name="ck_interview_selections_confirmed",
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
