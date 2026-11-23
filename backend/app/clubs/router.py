"""Authenticated endpoints for browsing public clubs."""

from typing import Annotated

from fastapi import APIRouter, Depends, Query
from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.auth.dependencies import require_roles
from app.database import get_db
from app.models.club import Club, ClubApprovalStatus
from app.models.user import AccountType
from app.clubs.schemas import ClubBrowseResponse

DEFAULT_PAGE_SIZE = 20
MAX_PAGE_SIZE = 100
MAX_PAGE = 10_000

router = APIRouter(
    prefix="/api/v1/clubs",
    tags=["Clubs"],
    dependencies=[Depends(require_roles(AccountType.STUDENT))],
)


@router.get(
    "",
    response_model=ClubBrowseResponse,
    summary="Browse approved university clubs",
    description=(
        "Returns only approved, active clubs to authenticated Student accounts. "
        "Results are ordered by name and UUID for stable pagination."
    ),
    responses={
        401: {"description": "Missing, invalid, expired, or revoked bearer token"},
        403: {"description": "Student account required"},
    },
)
def browse_clubs(
    db: Annotated[Session, Depends(get_db)],
    page: Annotated[
        int,
        Query(ge=1, le=MAX_PAGE, description="1-based page number, up to 10,000."),
    ] = 1,
    page_size: Annotated[
        int,
        Query(ge=1, le=MAX_PAGE_SIZE, description="Number of clubs per page, up to 100."),
    ] = DEFAULT_PAGE_SIZE,
) -> ClubBrowseResponse:
    """Return a bounded page of approved, active clubs without internal state."""
    visible = (
        Club.approval_status == ClubApprovalStatus.APPROVED,
        Club.is_active.is_(True),
    )
    total = db.scalar(select(func.count()).select_from(Club).where(*visible)) or 0
    clubs = db.scalars(
        select(Club)
        .where(*visible)
        .order_by(Club.name.asc(), Club.id.asc())
        .offset((page - 1) * page_size)
        .limit(page_size)
    ).all()
    return ClubBrowseResponse(clubs=clubs, page=page, page_size=page_size, total=total)
