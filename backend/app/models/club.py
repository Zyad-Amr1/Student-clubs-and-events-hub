"""PostgreSQL-backed university clubs and their public visibility state."""

from datetime import datetime
from enum import StrEnum
from uuid import UUID

from sqlalchemy import (
    Boolean,
    CheckConstraint,
    DateTime,
    Enum,
    FetchedValue,
    Index,
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


class ClubApprovalStatus(StrEnum):
    PENDING = "pending"
    APPROVED = "approved"
    REJECTED = "rejected"


class Club(Base):
    __tablename__ = "clubs"
    __table_args__ = (
        CheckConstraint(f"btrim(name, {_WHITESPACE}) <> ''", name="ck_clubs_name_nonblank"),
        CheckConstraint(
            f"btrim(description, {_WHITESPACE}) <> ''", name="ck_clubs_description_nonblank"
        ),
        CheckConstraint(
            f"btrim(category, {_WHITESPACE}) <> ''", name="ck_clubs_category_nonblank"
        ),
        CheckConstraint(
            f"logo_url IS NULL OR btrim(logo_url, {_WHITESPACE}) <> ''",
            name="ck_clubs_logo_url_nonblank",
        ),
        Index("ix_clubs_browse", "approval_status", "is_active", "name", "id"),
    )

    id: Mapped[UUID] = mapped_column(
        Uuid, primary_key=True, server_default=text("gen_random_uuid()")
    )
    name: Mapped[str] = mapped_column(String(120), nullable=False)
    description: Mapped[str] = mapped_column(Text, nullable=False)
    category: Mapped[str] = mapped_column(String(80), nullable=False)
    logo_url: Mapped[str | None] = mapped_column(Text)
    approval_status: Mapped[ClubApprovalStatus] = mapped_column(
        Enum(
            ClubApprovalStatus,
            values_callable=lambda enum: [item.value for item in enum],
            native_enum=False,
            create_constraint=True,
            validate_strings=True,
            name="ck_clubs_approval_status",
        ),
        nullable=False,
        server_default=text("'pending'"),
    )
    is_active: Mapped[bool] = mapped_column(
        Boolean, nullable=False, server_default=text("true")
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
    archived_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    archive_reason: Mapped[str | None] = mapped_column(Text)
