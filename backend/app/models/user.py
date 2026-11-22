from datetime import datetime
from enum import StrEnum
from uuid import UUID

from sqlalchemy import (
    Boolean,
    CheckConstraint,
    DateTime,
    Enum,
    FetchedValue,
    Integer,
    Text,
    UniqueConstraint,
    Uuid,
    func,
    text,
)
from sqlalchemy.orm import Mapped, mapped_column, validates

from app.database import Base


# Match str.strip(), including Unicode spaces and ASCII control separators.
_WHITESPACE = (
    r"U&' \0009\000A\000B\000C\000D\001C\001D\001E\001F"
    r"\0085\00A0\1680\2000\2001\2002\2003\2004\2005\2006\2007"
    r"\2008\2009\200A\2028\2029\202F\205F\3000'"
)


class AccountType(StrEnum):
    STUDENT = "student"
    STUDENT_AFFAIRS = "student_affairs"


class User(Base):
    __tablename__ = "users"
    __table_args__ = (
        UniqueConstraint("email", name="uq_users_email"),
        UniqueConstraint("university_id", name="uq_users_university_id"),
        CheckConstraint(
            f"email <> '' AND email = casefold(btrim(email, {_WHITESPACE}))",
            name="ck_users_email_normalized",
        ),
        CheckConstraint(
            f"university_id <> '' AND university_id = upper(btrim(university_id, {_WHITESPACE}))",
            name="ck_users_university_id_normalized",
        ),
        CheckConstraint(f"btrim(full_name, {_WHITESPACE}) <> ''", name="ck_users_full_name_nonblank"),
        CheckConstraint(
            f"btrim(password_hash, {_WHITESPACE}) <> ''", name="ck_users_password_hash_nonblank"
        ),
        CheckConstraint("academic_year > 0", name="ck_users_academic_year_positive"),
    )

    id: Mapped[UUID] = mapped_column(
        Uuid, primary_key=True, server_default=text("gen_random_uuid()")
    )
    full_name: Mapped[str] = mapped_column(Text)
    email: Mapped[str] = mapped_column(Text(collation="pg_unicode_fast"))
    university_id: Mapped[str] = mapped_column(Text(collation="pg_unicode_fast"))
    password_hash: Mapped[str] = mapped_column(Text)
    account_type: Mapped[AccountType] = mapped_column(
        Enum(
            AccountType,
            values_callable=lambda enum: [item.value for item in enum],
            native_enum=False,
            create_constraint=True,
            validate_strings=True,
            name="ck_users_account_type",
        ),
        server_default=text("'student'"),
    )
    faculty: Mapped[str | None] = mapped_column(Text)
    department: Mapped[str | None] = mapped_column(Text)
    academic_year: Mapped[int | None] = mapped_column(Integer)
    profile_picture_url: Mapped[str | None] = mapped_column(Text)
    is_active: Mapped[bool] = mapped_column(Boolean, server_default=text("true"))
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), server_onupdate=FetchedValue()
    )

    @validates("email")
    def normalize_email(self, _key: str, value: str) -> str:
        return value.strip().casefold()

    @validates("university_id")
    def normalize_university_id(self, _key: str, value: str) -> str:
        return value.strip().upper()
