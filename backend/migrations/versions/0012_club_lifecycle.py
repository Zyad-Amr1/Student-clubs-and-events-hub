"""Add auditable archive/reactivation and preserve cancelled activities."""

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

revision = "0012_club_lifecycle"
down_revision = "0011_interview_lifecycle"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column("clubs", sa.Column("archived_at", sa.DateTime(timezone=True)))
    op.add_column("clubs", sa.Column("archive_reason", sa.Text()))
    op.add_column("events", sa.Column("cancelled_at", sa.DateTime(timezone=True)))
    op.add_column("events", sa.Column("cancellation_reason", sa.Text()))
    op.drop_constraint("ck_event_reservations_status", "event_reservations", type_="check")
    op.create_check_constraint("ck_event_reservations_status", "event_reservations",
                               "status IN ('confirmed', 'waitlisted', 'cancelled')")
    op.create_table(
        "club_lifecycle_audits",
        sa.Column("id", sa.Uuid(), server_default=sa.text("gen_random_uuid()"), nullable=False),
        sa.Column("club_id", sa.Uuid(), nullable=False),
        sa.Column("actor_id", sa.Uuid(), nullable=False),
        sa.Column("action", sa.String(16), nullable=False),
        sa.Column("reason", sa.Text()),
        sa.Column("affected", postgresql.JSONB(astext_type=sa.Text()), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.ForeignKeyConstraint(["club_id"], ["clubs.id"], ondelete="RESTRICT"),
        sa.ForeignKeyConstraint(["actor_id"], ["users.id"], ondelete="RESTRICT"),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index("ix_club_lifecycle_audits_club_created", "club_lifecycle_audits",
                    ["club_id", "created_at"])
    op.create_table(
        "club_lifecycle_notices",
        sa.Column("id", sa.Uuid(), server_default=sa.text("gen_random_uuid()"), nullable=False),
        sa.Column("club_id", sa.Uuid(), nullable=False),
        sa.Column("user_id", sa.Uuid(), nullable=False),
        sa.Column("event_key", sa.String(120), nullable=False),
        sa.Column("kind", sa.String(24), nullable=False),
        sa.Column("message", sa.Text(), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.ForeignKeyConstraint(["club_id"], ["clubs.id"], ondelete="RESTRICT"),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="RESTRICT"),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("user_id", "event_key", name="uq_club_lifecycle_notice_user_event"),
    )
    op.create_index("ix_club_lifecycle_notices_user_created", "club_lifecycle_notices",
                    ["user_id", "created_at"])


def downgrade() -> None:
    op.drop_index("ix_club_lifecycle_notices_user_created", table_name="club_lifecycle_notices")
    op.drop_table("club_lifecycle_notices")
    op.drop_index("ix_club_lifecycle_audits_club_created", table_name="club_lifecycle_audits")
    op.drop_table("club_lifecycle_audits")
    op.drop_constraint("ck_event_reservations_status", "event_reservations", type_="check")
    op.create_check_constraint("ck_event_reservations_status", "event_reservations",
                               "status IN ('confirmed', 'waitlisted')")
    op.drop_column("events", "cancellation_reason")
    op.drop_column("events", "cancelled_at")
    op.drop_column("clubs", "archive_reason")
    op.drop_column("clubs", "archived_at")
