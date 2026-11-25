"""Enforce a single Student Affairs account and record Club Head decisions."""

from alembic import op
import sqlalchemy as sa

revision = "0013_club_head_requests"
down_revision = "0012_club_lifecycle"
branch_labels = None
depends_on = None


def upgrade():
    op.execute("""
        DO $$ BEGIN
        IF (SELECT count(*) FROM users WHERE account_type = 'student_affairs') > 1 THEN
            RAISE EXCEPTION 'Resolve duplicate Student Affairs accounts before upgrading';
        END IF;
        END $$;
    """)
    op.create_index("uq_users_student_affairs", "users", ["account_type"], unique=True,
                    postgresql_where=sa.text("account_type = 'student_affairs'"))
    op.create_table(
        "club_head_requests",
        sa.Column("id", sa.Uuid(), primary_key=True, server_default=sa.text("gen_random_uuid()")),
        sa.Column("club_id", sa.Uuid(), sa.ForeignKey("clubs.id", ondelete="RESTRICT"), nullable=False),
        sa.Column("student_id", sa.Uuid(), sa.ForeignKey("users.id", ondelete="RESTRICT"), nullable=False),
        sa.Column("status", sa.String(12), nullable=False, server_default=sa.text("'pending'")),
        sa.Column("reason", sa.Text()),
        sa.Column("reviewed_by", sa.Uuid(), sa.ForeignKey("users.id", ondelete="RESTRICT")),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
        sa.Column("decided_at", sa.DateTime(timezone=True)),
        sa.CheckConstraint(
            "(status = 'pending' AND reviewed_by IS NULL AND decided_at IS NULL AND reason IS NULL) OR "
            "(status = 'approved' AND reviewed_by IS NOT NULL AND decided_at IS NOT NULL AND reason IS NULL) OR "
            "(status = 'rejected' AND reviewed_by IS NOT NULL AND decided_at IS NOT NULL "
            "AND reason IS NOT NULL AND btrim(reason) <> '')",
            name="ck_club_head_request_decision",
        ),
    )
    op.create_index("uq_club_head_pending", "club_head_requests", ["club_id"], unique=True,
                    postgresql_where=sa.text("status = 'pending'"))


def downgrade():
    op.drop_table("club_head_requests")
    op.drop_index("uq_users_student_affairs", table_name="users")
