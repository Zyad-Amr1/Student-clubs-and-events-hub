"""Add published interview days, selection history and confirmed appointments."""
from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects.postgresql import JSONB

revision = "0010_interview_booking"
down_revision = "0009_membership_applications"
branch_labels = None
depends_on = None


def upgrade():
    op.create_table(
        "interview_days",
        sa.Column("id", sa.Uuid(), primary_key=True, server_default=sa.text("gen_random_uuid()")),
        sa.Column("club_id", sa.Uuid(), sa.ForeignKey("clubs.id", ondelete="CASCADE"), nullable=False),
        sa.Column("day", sa.Date(), nullable=False),
        sa.Column("capacity", sa.Integer(), nullable=False),
        sa.Column("duration_minutes", sa.Integer(), server_default=sa.text("15"), nullable=False),
        sa.Column("periods", JSONB(), server_default=sa.text("'[]'::jsonb"), nullable=False),
        sa.UniqueConstraint("club_id", "day", name="uq_interview_days_club_day"),
        sa.CheckConstraint("capacity > 0", name="ck_interview_days_capacity"),
        sa.CheckConstraint("duration_minutes BETWEEN 1 AND 1440", name="ck_interview_days_duration"),
    )
    op.create_table(
        "interview_selections",
        sa.Column("id", sa.Uuid(), primary_key=True, server_default=sa.text("gen_random_uuid()")),
        sa.Column("application_id", sa.Uuid(), sa.ForeignKey("membership_applications.id", ondelete="CASCADE"), nullable=False),
        sa.Column("day_id", sa.Uuid(), sa.ForeignKey("interview_days.id", ondelete="CASCADE"), nullable=False),
        sa.Column("selected_at", sa.DateTime(timezone=True), server_default=sa.text("clock_timestamp()"), nullable=False),
        sa.Column("released_at", sa.DateTime(timezone=True)),
        sa.Column("starts_at", sa.DateTime(timezone=True)),
        sa.Column("ends_at", sa.DateTime(timezone=True)),
        sa.Column("published_at", sa.DateTime(timezone=True)),
        sa.CheckConstraint(
            "(starts_at IS NULL AND ends_at IS NULL AND published_at IS NULL) OR "
            "(starts_at IS NOT NULL AND ends_at IS NOT NULL AND published_at IS NOT NULL "
            "AND released_at IS NULL AND ends_at > starts_at)",
            name="ck_interview_selections_confirmed",
        ),
    )
    op.create_index("uq_interview_selections_active_application", "interview_selections",
                    ["application_id"], unique=True, postgresql_where=sa.text("released_at IS NULL"))
    op.create_index("ix_interview_selections_day", "interview_selections", ["day_id"])


def downgrade():
    op.drop_table("interview_selections")
    op.drop_table("interview_days")
