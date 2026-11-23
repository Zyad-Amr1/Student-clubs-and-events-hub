"""Create clubs for authenticated browsing.

Revision ID: 0003_create_clubs
Revises: 0002_create_auth_sessions
"""

from alembic import op
import sqlalchemy as sa


revision = "0003_create_clubs"
down_revision = "0002_create_auth_sessions"
branch_labels = None
depends_on = None

_WHITESPACE = (
    r"U&' \0009\000A\000B\000C\000D\001C\001D\001E\001F"
    r"\0085\00A0\1680\2000\2001\2002\2003\2004\2005\2006\2007"
    r"\2008\2009\200A\2028\2029\202F\205F\3000'"
)


def upgrade() -> None:
    op.create_table(
        "clubs",
        sa.Column("id", sa.Uuid(), server_default=sa.text("gen_random_uuid()"), nullable=False),
        sa.Column("name", sa.String(length=120), nullable=False),
        sa.Column("description", sa.Text(), nullable=False),
        sa.Column("category", sa.String(length=80), nullable=False),
        sa.Column("logo_url", sa.Text(), nullable=True),
        sa.Column("approval_status", sa.String(length=8), server_default="pending", nullable=False),
        sa.Column("is_active", sa.Boolean(), server_default=sa.text("true"), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.CheckConstraint("approval_status IN ('pending', 'approved', 'rejected')", name="ck_clubs_approval_status"),
        sa.CheckConstraint(f"btrim(name, {_WHITESPACE}) <> ''", name="ck_clubs_name_nonblank"),
        sa.CheckConstraint(
            f"btrim(description, {_WHITESPACE}) <> ''", name="ck_clubs_description_nonblank"
        ),
        sa.CheckConstraint(
            f"btrim(category, {_WHITESPACE}) <> ''", name="ck_clubs_category_nonblank"
        ),
        sa.CheckConstraint(
            f"logo_url IS NULL OR btrim(logo_url, {_WHITESPACE}) <> ''",
            name="ck_clubs_logo_url_nonblank",
        ),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(
        "ix_clubs_browse", "clubs", ["approval_status", "is_active", "name", "id"]
    )
    op.execute("""
        CREATE FUNCTION campusconnect_clubs_before_update() RETURNS trigger
        LANGUAGE plpgsql AS $$
        BEGIN
            NEW.updated_at := clock_timestamp();
            RETURN NEW;
        END;
        $$
    """)
    op.execute("""
        CREATE TRIGGER clubs_before_update
        BEFORE UPDATE ON clubs
        FOR EACH ROW EXECUTE FUNCTION campusconnect_clubs_before_update()
    """)


def downgrade() -> None:
    op.execute("DROP TRIGGER clubs_before_update ON clubs")
    op.execute("DROP FUNCTION campusconnect_clubs_before_update()")
    op.drop_index("ix_clubs_browse", table_name="clubs")
    op.drop_table("clubs")
