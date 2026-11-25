"""Add membership applications and accepted membership records."""
from alembic import op
import sqlalchemy as sa

revision = "0009_membership_applications"
down_revision = "0008_club_requests"
branch_labels = None
depends_on = None


def upgrade():
    op.create_table(
        "membership_applications",
        sa.Column("id", sa.Uuid(), primary_key=True, server_default=sa.text("gen_random_uuid()")),
        sa.Column("club_id", sa.Uuid(), sa.ForeignKey("clubs.id", ondelete="RESTRICT"), nullable=False),
        sa.Column("student_id", sa.Uuid(), sa.ForeignKey("users.id", ondelete="RESTRICT"), nullable=False),
        sa.Column("status", sa.String(24), server_default=sa.text("'pending'"), nullable=False),
        sa.Column("submitted_at", sa.DateTime(timezone=True), server_default=sa.func.clock_timestamp(), nullable=False),
        sa.Column("interview_required_at", sa.DateTime(timezone=True)),
        sa.Column("accepted_at", sa.DateTime(timezone=True)),
        sa.UniqueConstraint("club_id", "student_id", name="uq_membership_applications_club_student"),
        sa.CheckConstraint("status IN ('pending', 'interview_required', 'accepted')",
                           name="ck_membership_applications_status"),
    )
    op.create_index("ix_membership_applications_student", "membership_applications",
                    ["student_id", "submitted_at"])


def downgrade():
    op.drop_table("membership_applications")
