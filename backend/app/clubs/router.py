"""Authenticated endpoints for browsing public clubs."""

from datetime import datetime, timezone
from typing import Annotated
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Path, Query
from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.auth.dependencies import require_roles
from app.database import get_db
from app.models.club import Club, ClubApprovalStatus
from app.models.event import Event, EventApprovalStatus
from app.models.user import AccountType
from app.clubs.schemas import ClubBrowseResponse, ClubDetailsResponse

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
        "Supports optional case-insensitive partial name search and exact category filtering. "
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
    search: Annotated[
        str | None,
        Query(
            max_length=120,
            description="Optional case-insensitive literal substring of a club name.",
        ),
    ] = None,
    category: Annotated[
        str | None,
        Query(
            max_length=80,
            description="Optional category name, matched exactly without case sensitivity.",
        ),
    ] = None,
) -> ClubBrowseResponse:
    """Return filtered, approved active clubs with safe fields and stable pagination."""
    visible = [
        Club.approval_status == ClubApprovalStatus.APPROVED,
        Club.is_active.is_(True),
    ]
    # Empty or whitespace-only filters mean no filter.
    if search is not None and (name_term := search.strip()):
        # autoescape protects literal % and _ characters from SQL LIKE wildcard behavior.
        visible.append(Club.name.icontains(name_term, autoescape=True))
    if category is not None and (category_term := category.strip()):
        visible.append(func.lower(Club.category) == category_term.lower())

    # Count after applying *all* filters and before page slicing.
    total = db.scalar(select(func.count()).select_from(Club).where(*visible)) or 0
    clubs = db.scalars(
        select(Club)
        .where(*visible)
        .order_by(Club.name.asc(), Club.id.asc())
        .offset((page - 1) * page_size)
        .limit(page_size)
    ).all()
    return ClubBrowseResponse(clubs=clubs, page=page, page_size=page_size, total=total)


@router.get(
    "/{club_id}",
    response_model=ClubDetailsResponse,
    summary="View an approved club and its upcoming events",
    description=(
        "Returns details for an approved, active club and only its approved, "
        "published events starting after the request's UTC time boundary."
    ),
    responses={
        401: {"description": "Missing, invalid, expired, or revoked bearer token"},
        403: {"description": "Student account required"},
        404: {"description": "Club not found"},
    },
)
def get_club_details(
    club_id: Annotated[UUID, Path(description="Club UUID")],
    db: Annotated[Session, Depends(get_db)],
    page: Annotated[
        int,
        Query(ge=1, le=MAX_PAGE, description="1-based event page number, up to 10,000."),
    ] = 1,
    page_size: Annotated[
        int,
        Query(ge=1, le=MAX_PAGE_SIZE, description="Events per page, up to 100."),
    ] = DEFAULT_PAGE_SIZE,
) -> ClubDetailsResponse:
    """Return safe club details and a bounded page of public upcoming events."""
    club = db.scalar(
        select(Club).where(
            Club.id == club_id,
            Club.approval_status == ClubApprovalStatus.APPROVED,
            Club.is_active.is_(True),
        )
    )
    if club is None:
        raise HTTPException(status_code=404, detail="Club not found")

    now = datetime.now(timezone.utc)
    visible_events = (
        Club.id == club.id,
        Club.approval_status == ClubApprovalStatus.APPROVED,
        Club.is_active.is_(True),
        Event.club_id == club.id,
        Event.approval_status == EventApprovalStatus.APPROVED,
        Event.is_published.is_(True),
        Event.cancelled_at.is_(None),
        Event.starts_at > now,
    )
    event_query = select(Event).join(Club, Event.club_id == Club.id).where(*visible_events)
    total = (
        db.scalar(
            select(func.count())
            .select_from(Event)
            .join(Club, Event.club_id == Club.id)
            .where(*visible_events)
        )
        or 0
    )
    events = db.scalars(
        event_query
        .order_by(Event.starts_at.asc(), Event.id.asc())
        .offset((page - 1) * page_size)
        .limit(page_size)
    ).all()
    return ClubDetailsResponse(
        club=club,
        events=events,
        page=page,
        page_size=page_size,
        total=total,
    )
