"""Create club events for upcoming event details.

Revision ID: 0004_create_events
Revises: 0003_create_clubs
"""

from alembic import op
import sqlalchemy as sa


revision = "0004_create_events"
down_revision = "0003_create_clubs"
branch_labels = None
depends_on = None

_WHITESPACE = (
    r"U&' \0009\000A\000B\000C\000D\001C\001D\001E\001F"
    r"\0085\00A0\1680\2000\2001\2002\2003\2004\2005\2006\2007"
    r"\2008\2009\200A\2028\2029\202F\205F\3000'"
)


def upgrade() -> None:
    op.create_table(
        "events",
        sa.Column("id", sa.Uuid(), server_default=sa.text("gen_random_uuid()"), nullable=False),
        sa.Column("club_id", sa.Uuid(), nullable=False),
        sa.Column("title", sa.String(length=160), nullable=False),
        sa.Column("description", sa.Text(), nullable=False),
        sa.Column("venue", sa.String(length=200), nullable=False),
        sa.Column("starts_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("ends_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("seat_capacity", sa.Integer(), nullable=False),
        sa.Column(
            "approval_status",
            sa.String(length=8),
            server_default=sa.text("'draft'"),
            nullable=False,
        ),
        sa.Column("is_published", sa.Boolean(), server_default=sa.text("false"), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.CheckConstraint(
            "approval_status IN ('draft', 'pending', 'approved', 'rejected')",
            name="ck_events_approval_status",
        ),
        sa.CheckConstraint(f"btrim(title, {_WHITESPACE}) <> ''", name="ck_events_title_nonblank"),
        sa.CheckConstraint(
            f"btrim(description, {_WHITESPACE}) <> ''",
            name="ck_events_description_nonblank",
        ),
        sa.CheckConstraint(f"btrim(venue, {_WHITESPACE}) <> ''", name="ck_events_venue_nonblank"),
        sa.CheckConstraint("seat_capacity > 0", name="ck_events_seat_capacity_positive"),
        sa.CheckConstraint(
            "ends_at IS NULL OR ends_at > starts_at",
            name="ck_events_ends_after_start",
        ),
        sa.ForeignKeyConstraint(
            ["club_id"],
            ["clubs.id"],
            name="fk_events_club_id_clubs",
            ondelete="CASCADE",
        ),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(
        "ix_events_club_upcoming",
        "events",
        ["club_id", "approval_status", "is_published", "starts_at", "id"],
    )
    op.execute("""
        CREATE FUNCTION campusconnect_events_before_update() RETURNS trigger
        LANGUAGE plpgsql AS $$
        BEGIN
            NEW.updated_at := clock_timestamp();
            RETURN NEW;
        END;
        $$
    """)
    op.execute("""
        CREATE TRIGGER events_before_update
        BEFORE UPDATE ON events
        FOR EACH ROW EXECUTE FUNCTION campusconnect_events_before_update()
    """)


def downgrade() -> None:
    op.execute("DROP TRIGGER events_before_update ON events")
    op.execute("DROP FUNCTION campusconnect_events_before_update()")
    op.drop_index("ix_events_club_upcoming", table_name="events")
    op.drop_table("events")
