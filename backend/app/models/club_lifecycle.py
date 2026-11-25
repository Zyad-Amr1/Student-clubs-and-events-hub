"""Auditable club lifecycle transitions and idempotent in-app notices."""

from datetime import datetime
from uuid import UUID

from sqlalchemy import DateTime, ForeignKey, Index, String, Text, UniqueConstraint, Uuid, func, text
from sqlalchemy.dialects.postgresql import JSONB
from sqlalchemy.orm import Mapped, mapped_column

from app.database import Base


class ClubLifecycleAudit(Base):
    __tablename__ = "club_lifecycle_audits"
    __table_args__ = (Index("ix_club_lifecycle_audits_club_created", "club_id", "created_at"),)

    id: Mapped[UUID] = mapped_column(Uuid, primary_key=True, server_default=text("gen_random_uuid()"))
    club_id: Mapped[UUID] = mapped_column(ForeignKey("clubs.id", ondelete="RESTRICT"))
    actor_id: Mapped[UUID] = mapped_column(ForeignKey("users.id", ondelete="RESTRICT"))
    action: Mapped[str] = mapped_column(String(16))
    reason: Mapped[str | None] = mapped_column(Text)
    affected: Mapped[dict] = mapped_column(JSONB)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())


class ClubLifecycleNotice(Base):
    __tablename__ = "club_lifecycle_notices"
    __table_args__ = (
        UniqueConstraint("user_id", "event_key", name="uq_club_lifecycle_notice_user_event"),
        Index("ix_club_lifecycle_notices_user_created", "user_id", "created_at"),
    )

    id: Mapped[UUID] = mapped_column(Uuid, primary_key=True, server_default=text("gen_random_uuid()"))
    club_id: Mapped[UUID] = mapped_column(ForeignKey("clubs.id", ondelete="RESTRICT"))
    user_id: Mapped[UUID] = mapped_column(ForeignKey("users.id", ondelete="RESTRICT"))
    event_key: Mapped[str] = mapped_column(String(120))
    kind: Mapped[str] = mapped_column(String(24))
    message: Mapped[str] = mapped_column(Text)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
