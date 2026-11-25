"""Add active Student event reservations and FIFO waitlist ordering.

Revision ID: 0007_event_reservations
Revises: 0006_one_admin_per_club
"""

from alembic import op
import sqlalchemy as sa


revision = "0007_event_reservations"
down_revision = "0006_one_admin_per_club"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "event_reservations",
        sa.Column("id", sa.BigInteger(), sa.Identity(always=False), nullable=False),
        sa.Column("event_id", sa.Uuid(), nullable=False),
        sa.Column("user_id", sa.Uuid(), nullable=False),
        sa.Column("status", sa.String(length=16), nullable=False),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
        sa.CheckConstraint(
            "status IN ('confirmed', 'waitlisted')",
            name="ck_event_reservations_status",
        ),
        sa.ForeignKeyConstraint(
            ["event_id"],
            ["events.id"],
            name="fk_event_reservations_event_id",
            ondelete="CASCADE",
        ),
        sa.ForeignKeyConstraint(
            ["user_id"],
            ["users.id"],
            name="fk_event_reservations_user_id",
            ondelete="CASCADE",
        ),
        sa.PrimaryKeyConstraint("id", name="pk_event_reservations"),
        sa.UniqueConstraint(
            "event_id", "user_id", name="uq_event_reservations_event_user"
        ),
    )
    op.create_index(
        "ix_event_reservations_event_status_id",
        "event_reservations",
        ["event_id", "status", "id"],
    )
    op.create_index(
        "ix_event_reservations_user_id", "event_reservations", ["user_id"]
    )


def downgrade() -> None:
    op.drop_index("ix_event_reservations_user_id", table_name="event_reservations")
    op.drop_index(
        "ix_event_reservations_event_status_id", table_name="event_reservations"
    )
    op.drop_table("event_reservations")
