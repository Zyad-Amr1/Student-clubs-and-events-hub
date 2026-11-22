"""Create users and protect account identifiers.

Revision ID: 0001_create_users
Revises:
"""

from alembic import op
import sqlalchemy as sa


revision = "0001_create_users"
down_revision = None
branch_labels = None
depends_on = None

_WHITESPACE = (
    r"U&' \0009\000A\000B\000C\000D\001C\001D\001E\001F"
    r"\0085\00A0\1680\2000\2001\2002\2003\2004\2005\2006\2007"
    r"\2008\2009\200A\2028\2029\202F\205F\3000'"
)


def upgrade() -> None:
    op.create_table(
        "users",
        sa.Column("id", sa.Uuid(), server_default=sa.text("gen_random_uuid()"), nullable=False),
        sa.Column("full_name", sa.Text(), nullable=False),
        sa.Column("email", sa.Text(collation="pg_unicode_fast"), nullable=False),
        sa.Column("university_id", sa.Text(collation="pg_unicode_fast"), nullable=False),
        sa.Column("password_hash", sa.Text(), nullable=False),
        sa.Column("account_type", sa.String(15), server_default="student", nullable=False),
        sa.Column("faculty", sa.Text(), nullable=True),
        sa.Column("department", sa.Text(), nullable=True),
        sa.Column("academic_year", sa.Integer(), nullable=True),
        sa.Column("profile_picture_url", sa.Text(), nullable=True),
        sa.Column("is_active", sa.Boolean(), server_default=sa.text("true"), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("email", name="uq_users_email"),
        sa.UniqueConstraint("university_id", name="uq_users_university_id"),
        sa.CheckConstraint(
            f"email <> '' AND email = casefold(btrim(email, {_WHITESPACE}))",
            name="ck_users_email_normalized",
        ),
        sa.CheckConstraint(
            f"university_id <> '' AND university_id = upper(btrim(university_id, {_WHITESPACE}))",
            name="ck_users_university_id_normalized",
        ),
        sa.CheckConstraint(
            f"btrim(full_name, {_WHITESPACE}) <> ''", name="ck_users_full_name_nonblank"
        ),
        sa.CheckConstraint(
            f"btrim(password_hash, {_WHITESPACE}) <> ''", name="ck_users_password_hash_nonblank"
        ),
        sa.CheckConstraint("academic_year > 0", name="ck_users_academic_year_positive"),
        sa.CheckConstraint(
            "account_type IN ('student', 'student_affairs')", name="ck_users_account_type"
        ),
    )
    op.execute("""
        CREATE FUNCTION campusconnect_users_before_update() RETURNS trigger
        LANGUAGE plpgsql AS $$
        BEGIN
            IF NEW.email IS DISTINCT FROM OLD.email
               OR NEW.university_id IS DISTINCT FROM OLD.university_id THEN
                RAISE EXCEPTION 'User identifiers cannot be changed'
                    USING ERRCODE = '23514';
            END IF;
            NEW.updated_at := clock_timestamp();
            RETURN NEW;
        END;
        $$
    """)
    op.execute("""
        CREATE TRIGGER users_before_update
        BEFORE UPDATE ON users
        FOR EACH ROW EXECUTE FUNCTION campusconnect_users_before_update()
    """)


def downgrade() -> None:
    op.execute("DROP TRIGGER users_before_update ON users")
    op.execute("DROP FUNCTION campusconnect_users_before_update()")
    op.drop_table("users")
