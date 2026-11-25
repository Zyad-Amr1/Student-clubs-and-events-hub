"""Record interview cancellation, expiry, attendance and student notices."""
from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects.postgresql import JSONB

revision = "0011_interview_lifecycle"
down_revision = "0010_interview_booking"
branch_labels = None
depends_on = None
TABLE = "interview_selections"

DRAFT_FIELDS = "(starts_at IS NULL AND ends_at IS NULL AND published_at IS NULL)"
PUBLISHED_FIELDS = "starts_at IS NOT NULL AND ends_at IS NOT NULL AND published_at IS NOT NULL"


def upgrade():
    op.add_column("interview_days", sa.Column("cancelled_at", sa.DateTime(timezone=True)))
    op.create_table(
        "interview_cancellations",
        sa.Column("id", sa.Uuid(), primary_key=True, server_default=sa.text("gen_random_uuid()")),
        sa.Column("day_id", sa.Uuid(), sa.ForeignKey("interview_days.id", ondelete="CASCADE"), nullable=False),
        sa.Column("actor_id", sa.Uuid(), sa.ForeignKey("users.id", ondelete="RESTRICT"), nullable=False),
        sa.Column("target", JSONB(), nullable=False),
        sa.Column("reason", sa.Text(), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
    )
    op.add_column(TABLE, sa.Column("cancellation_id", sa.Uuid(),
                  sa.ForeignKey("interview_cancellations.id", ondelete="CASCADE")))
    op.add_column(TABLE, sa.Column("expired_at", sa.DateTime(timezone=True)))
    op.add_column(TABLE, sa.Column("attendance", sa.String(12)))
    op.add_column(TABLE, sa.Column("attendance_at", sa.DateTime(timezone=True)))
    op.add_column(TABLE, sa.Column("attendance_by", sa.Uuid(), sa.ForeignKey("users.id", ondelete="RESTRICT")))
    op.drop_constraint("ck_interview_selections_confirmed", TABLE, type_="check")
    op.create_check_constraint(
        "ck_interview_selections_confirmed", TABLE,
        f"{DRAFT_FIELDS} OR ({PUBLISHED_FIELDS} AND "
        "(released_at IS NULL OR cancellation_id IS NOT NULL) AND ends_at > starts_at)",
    )
    op.create_check_constraint(
        "ck_interview_selections_cancellation", TABLE,
        "cancellation_id IS NULL OR (released_at IS NOT NULL AND attendance IS NULL)",
    )
    op.create_check_constraint(
        "ck_interview_selections_attendance", TABLE,
        "(attendance IS NULL AND attendance_at IS NULL AND attendance_by IS NULL) OR "
        "(attendance IS NOT NULL AND attendance IN ('attended', 'no_show') AND attendance_at IS NOT NULL "
        "AND attendance_by IS NOT NULL AND published_at IS NOT NULL AND released_at IS NULL "
        "AND attendance_at >= ends_at)",
    )
    op.create_check_constraint(
        "ck_interview_selections_expiry", TABLE,
        "expired_at IS NULL OR (released_at IS NOT NULL AND published_at IS NULL "
        "AND cancellation_id IS NULL AND expired_at <= released_at)",
    )
    op.create_table(
        "interview_notices",
        sa.Column("id", sa.Uuid(), primary_key=True, server_default=sa.text("gen_random_uuid()")),
        sa.Column("application_id", sa.Uuid(),
                  sa.ForeignKey("membership_applications.id", ondelete="CASCADE"), nullable=False),
        sa.Column("event_key", sa.String(80), nullable=False),
        sa.Column("kind", sa.String(20), nullable=False),
        sa.Column("message", sa.Text(), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.UniqueConstraint("application_id", "event_key", name="uq_interview_notices_event"),
    )
    op.execute(
        "INSERT INTO interview_notices (application_id, event_key, kind, message, created_at) "
        "SELECT application_id, 'confirmed:' || id::text, 'confirmed', "
        "'Your interview appointment is confirmed.', published_at "
        "FROM interview_selections WHERE published_at IS NOT NULL"
    )


def downgrade():
    op.execute(
        "DO $$ BEGIN IF EXISTS (SELECT FROM interview_cancellations) OR "
        "EXISTS (SELECT FROM interview_selections WHERE attendance IS NOT NULL OR expired_at IS NOT NULL) "
        "THEN RAISE EXCEPTION 'Downgrade would discard interview lifecycle history'; END IF; END $$"
    )
    op.drop_table("interview_notices")
    for name in ("expiry", "attendance", "cancellation", "confirmed"):
        op.drop_constraint(f"ck_interview_selections_{name}", TABLE, type_="check")
    for name in ("attendance_by", "attendance_at", "attendance", "expired_at", "cancellation_id"):
        op.drop_column(TABLE, name)
    op.create_check_constraint(
        "ck_interview_selections_confirmed", TABLE,
        f"{DRAFT_FIELDS} OR ({PUBLISHED_FIELDS} AND released_at IS NULL AND ends_at > starts_at)",
    )
    op.drop_table("interview_cancellations")
    op.drop_column("interview_days", "cancelled_at")
