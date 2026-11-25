from datetime import datetime
from uuid import UUID

from sqlalchemy import CheckConstraint, DateTime, ForeignKey, Index, String, UniqueConstraint, Uuid, func, text
from sqlalchemy.orm import Mapped, mapped_column

from app.database import Base


class MembershipApplication(Base):
    __tablename__ = "membership_applications"
    __table_args__ = (
        UniqueConstraint("club_id", "student_id", name="uq_membership_applications_club_student"),
        CheckConstraint("status IN ('pending', 'interview_required', 'accepted')",
                        name="ck_membership_applications_status"),
        Index("ix_membership_applications_student", "student_id", "submitted_at"),
    )

    id: Mapped[UUID] = mapped_column(Uuid, primary_key=True, server_default=text("gen_random_uuid()"))
    club_id: Mapped[UUID] = mapped_column(ForeignKey("clubs.id", ondelete="RESTRICT"))
    student_id: Mapped[UUID] = mapped_column(ForeignKey("users.id", ondelete="RESTRICT"))
    status: Mapped[str] = mapped_column(String(24), server_default=text("'pending'"))
    submitted_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.clock_timestamp())
    interview_required_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    accepted_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
