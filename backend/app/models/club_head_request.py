from datetime import datetime
from uuid import UUID

from sqlalchemy import CheckConstraint, DateTime, ForeignKey, Index, String, Text, Uuid, func, text
from sqlalchemy.orm import Mapped, mapped_column

from app.database import Base


class ClubHeadRequest(Base):
    __tablename__ = "club_head_requests"
    __table_args__ = (
        Index("uq_club_head_pending", "club_id", unique=True, postgresql_where=text("status = 'pending'")),
        CheckConstraint(
            "(status = 'pending' AND reviewed_by IS NULL AND decided_at IS NULL AND reason IS NULL) OR "
            "(status = 'approved' AND reviewed_by IS NOT NULL AND decided_at IS NOT NULL AND reason IS NULL) OR "
            "(status = 'rejected' AND reviewed_by IS NOT NULL AND decided_at IS NOT NULL "
            "AND reason IS NOT NULL AND btrim(reason) <> '')",
            name="ck_club_head_request_decision",
        ),
    )

    id: Mapped[UUID] = mapped_column(Uuid, primary_key=True, server_default=text("gen_random_uuid()"))
    club_id: Mapped[UUID] = mapped_column(ForeignKey("clubs.id", ondelete="RESTRICT"))
    student_id: Mapped[UUID] = mapped_column(ForeignKey("users.id", ondelete="RESTRICT"))
    status: Mapped[str] = mapped_column(String(12), server_default=text("'pending'"))
    reason: Mapped[str | None] = mapped_column(Text)
    reviewed_by: Mapped[UUID | None] = mapped_column(ForeignKey("users.id", ondelete="RESTRICT"))
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    decided_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
