"""Club-scoped administrator grants; no global club_admin account type exists."""

from datetime import datetime
from uuid import UUID

from sqlalchemy import DateTime, ForeignKey, Index, Uuid, func
from sqlalchemy.orm import Mapped, mapped_column

from app.database import Base


class ClubAdministrator(Base):
    __tablename__ = "club_administrators"
    __table_args__ = (Index("ix_club_administrators_user_id", "user_id"),)

    club_id: Mapped[UUID] = mapped_column(
        Uuid,
        ForeignKey("clubs.id", ondelete="CASCADE", name="fk_club_admins_club_id"),
        primary_key=True,
    )
    user_id: Mapped[UUID] = mapped_column(
        Uuid,
        ForeignKey("users.id", ondelete="CASCADE", name="fk_club_admins_user_id"),
        primary_key=True,
    )
    assigned_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, server_default=func.now()
    )
