"""Add server-managed, club-specific administrator memberships.

Revision ID: 0005_club_administrators
Revises: 0004_create_events

No public grant or self-service assignment endpoint is introduced.
"""

from alembic import op
import sqlalchemy as sa


revision = "0005_club_administrators"
down_revision = "0004_create_events"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "club_administrators",
        sa.Column("club_id", sa.Uuid(), nullable=False),
        sa.Column("user_id", sa.Uuid(), nullable=False),
        sa.Column("assigned_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.ForeignKeyConstraint(
            ["club_id"], ["clubs.id"], name="fk_club_admins_club_id", ondelete="CASCADE"
        ),
        sa.ForeignKeyConstraint(
            ["user_id"], ["users.id"], name="fk_club_admins_user_id", ondelete="CASCADE"
        ),
        sa.PrimaryKeyConstraint("club_id", "user_id", name="pk_club_administrators"),
    )
    op.create_index(
        "ix_club_administrators_user_id", "club_administrators", ["user_id"]
    )


def downgrade() -> None:
    op.drop_index("ix_club_administrators_user_id", table_name="club_administrators")
    op.drop_table("club_administrators")
