"""MVP invariant: at most one administrator per club.

Revision ID: 0006_one_admin_per_club
Revises: 0005_club_administrators

Only apply to a specifically authorized database. If duplicate assignments
exist, fail without deleting or choosing anyone's administrator.
"""

from alembic import op
import sqlalchemy as sa


revision = "0006_one_admin_per_club"
down_revision = "0005_club_administrators"
branch_labels = None
depends_on = None


def upgrade() -> None:
    connection = op.get_bind()
    duplicate = connection.execute(
        sa.text(
            "SELECT club_id FROM club_administrators "
            "GROUP BY club_id HAVING count(*) > 1 LIMIT 1"
        )
    ).scalar()
    if duplicate is not None:
        raise RuntimeError(
            "Duplicate club administrator assignments detected. "
            "An authorized Student Affairs reviewer must resolve them "
            "before applying 0006; migration does not delete any grants."
        )
    op.create_unique_constraint(
        "uq_club_administrators_club_id",
        "club_administrators",
        ["club_id"],
    )


def downgrade() -> None:
    op.drop_constraint(
        "uq_club_administrators_club_id",
        "club_administrators",
        type_="unique",
    )
