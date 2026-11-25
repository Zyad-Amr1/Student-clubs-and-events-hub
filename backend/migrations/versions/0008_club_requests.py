"""Add the club creation request queue and history."""
from alembic import op
import sqlalchemy as sa

revision = "0008_club_requests"
down_revision = "0007_event_reservations"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "club_requests",
        sa.Column("id", sa.Uuid(), primary_key=True, server_default=sa.text("gen_random_uuid()")),
        sa.Column("student_id", sa.Uuid(), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("club_id", sa.Uuid(), sa.ForeignKey("clubs.id", ondelete="SET NULL")),
        sa.Column("name", sa.String(120), nullable=False),
        sa.Column("name_key", sa.Text(), nullable=False),
        sa.Column("description", sa.Text(), nullable=False),
        sa.Column("category", sa.String(80), nullable=False),
        sa.Column("logo_url", sa.Text()),
        sa.Column("status", sa.String(12), server_default=sa.text("'pending'"), nullable=False),
        sa.Column("rejection_reason", sa.Text()),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("closed_at", sa.DateTime(timezone=True)),
        sa.Column("reviewed_by", sa.Uuid(), sa.ForeignKey("users.id", ondelete="SET NULL")),
        sa.CheckConstraint(
            "status IN ('pending', 'approved', 'rejected', 'withdrawn')",
            name="ck_club_requests_status",
        ),
        sa.CheckConstraint(
            "(status = 'rejected') = (rejection_reason IS NOT NULL)",
            name="ck_club_requests_rejection",
        ),
    )
    op.create_index("ix_club_requests_owner", "club_requests", ["student_id", "created_at"])
    op.create_index("ix_club_requests_queue", "club_requests", ["status", "created_at"])
    for name, column in (
        ("uq_club_requests_pending_student", "student_id"),
        ("uq_club_requests_pending_name", "name_key"),
    ):
        op.create_index(name, "club_requests", [column], unique=True,
                        postgresql_where=sa.text("status = 'pending'"))


def downgrade() -> None:
    op.drop_table("club_requests")
