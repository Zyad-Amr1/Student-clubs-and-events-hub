"""Owner-visible history of applications to create a club."""
from datetime import datetime
from uuid import UUID

from sqlalchemy import CheckConstraint, DateTime, ForeignKey, Index, String, Text, Uuid, func, text
from sqlalchemy.orm import Mapped, mapped_column

from app.database import Base


class ClubRequest(Base):
    __tablename__ = "club_requests"
    __table_args__ = (
        CheckConstraint(
            "status IN ('pending', 'approved', 'rejected', 'withdrawn')",
            name="ck_club_requests_status",
        ),
        CheckConstraint(
            "(status = 'rejected') = (rejection_reason IS NOT NULL)",
            name="ck_club_requests_rejection",
        ),
        Index("ix_club_requests_owner", "student_id", "created_at"),
        Index("ix_club_requests_queue", "status", "created_at"),
        Index("uq_club_requests_pending_student", "student_id", unique=True,
              postgresql_where=text("status = 'pending'")),
        Index("uq_club_requests_pending_name", "name_key", unique=True,
              postgresql_where=text("status = 'pending'")),
    )

    id: Mapped[UUID] = mapped_column(Uuid, primary_key=True, server_default=text("gen_random_uuid()"))
    student_id: Mapped[UUID] = mapped_column(Uuid, ForeignKey("users.id", ondelete="CASCADE"))
    club_id: Mapped[UUID | None] = mapped_column(Uuid, ForeignKey("clubs.id", ondelete="SET NULL"))
    name: Mapped[str] = mapped_column(String(120))
    name_key: Mapped[str] = mapped_column(Text)
    description: Mapped[str] = mapped_column(Text)
    category: Mapped[str] = mapped_column(String(80))
    logo_url: Mapped[str | None] = mapped_column(Text)
    status: Mapped[str] = mapped_column(String(12), server_default=text("'pending'"))
    rejection_reason: Mapped[str | None] = mapped_column(Text)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    closed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    reviewed_by: Mapped[UUID | None] = mapped_column(Uuid, ForeignKey("users.id", ondelete="SET NULL"))
