from uuid import UUID

from sqlalchemy import DateTime

from app.database import Base
from app.models.user import AccountType, User


def test_user_model_structure():
    table = Base.metadata.tables["users"]
    assert list(table.primary_key.columns.keys()) == ["id"]
    assert table.c.id.type.python_type is UUID
    for name in ("full_name", "email", "university_id", "password_hash", "account_type"):
        assert not table.c[name].nullable
    for name in ("faculty", "department", "academic_year", "profile_picture_url"):
        assert table.c[name].nullable
    for name in ("created_at", "updated_at"):
        assert isinstance(table.c[name].type, DateTime)
        assert table.c[name].type.timezone
        assert not table.c[name].nullable
    assert {role.value for role in AccountType} == {"student", "student_affairs"}


def test_user_normalizes_identifiers_on_assignment():
    user = User(email="  Student@Example.EDU\n", university_id="\t ab-123 ")
    assert user.email == "student@example.edu"
    assert user.university_id == "AB-123"


def test_user_case_folds_unicode_email():
    user = User(email="\u00a0Straße@Example.EDU\u00a0")
    assert user.email == "strasse@example.edu"
