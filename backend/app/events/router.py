"""Draft creation requires a verified Student with a club-specific DB grant."""

from datetime import datetime, timezone
from typing import Annotated
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Path, Request, status
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.auth.dependencies import AuthenticatedIdentity, current_identity
from app.database import get_db
from app.events.schemas import DraftEventCreate, DraftEventResponse
from app.models.club import Club, ClubApprovalStatus
from app.models.club_administrator import ClubAdministrator
from app.models.event import Event, EventApprovalStatus
from app.models.user import AccountType

router = APIRouter(prefix="/api/v1/clubs", tags=["Club Event Management"])


@router.post(
    "/{club_id}/events",
    status_code=status.HTTP_201_CREATED,
    response_model=DraftEventResponse,
    summary="Create a draft event for a club you administer",
    responses={
        401: {"description": "Missing or invalid bearer session"},
        403: {"description": "Student account required; no Student Affairs override"},
        404: {"description": "Club not found or administrator access denied"},
        422: {"description": "Invalid event data"},
    },
)
def create_draft_event(
    club_id: Annotated[UUID, Path(description="Club UUID")],
    payload: DraftEventCreate,
    identity: Annotated[AuthenticatedIdentity, Depends(current_identity)],
    db: Annotated[Session, Depends(get_db)],
) -> Event:
    """Lock and check the active club and its membership before inserting a draft."""
    if identity.user.account_type != AccountType.STUDENT:
        raise HTTPException(status_code=403, detail="Insufficient permissions")

    club = db.scalar(
        select(Club)
        .join(ClubAdministrator, ClubAdministrator.club_id == Club.id)
        .where(
            Club.id == club_id,
            Club.is_active.is_(True),
            Club.approval_status == ClubApprovalStatus.APPROVED,
            ClubAdministrator.user_id == identity.user.id,
        )
        .with_for_update(of=(Club, ClubAdministrator))
    )
    if club is None:
        # Avoid revealing whether an inaccessible club exists.
        raise HTTPException(status_code=404, detail="Club not found")

    event = Event(
        club_id=club.id,
        title=payload.title,
        description=payload.description,
        venue=payload.venue,
        starts_at=payload.starts_at,
        ends_at=payload.ends_at,
        seat_capacity=payload.seat_capacity,
        approval_status=EventApprovalStatus.DRAFT,
        is_published=False,
    )
    db.add(event)
    db.commit()
    db.refresh(event)
    return event


def _ensure_ready_to_submit(event: Event) -> None:
    """Recheck persisted draft readiness at transition time, not creation time."""
    start = event.starts_at
    if (
        start.tzinfo is None
        or start.utcoffset() is None
        or start <= datetime.now(timezone.utc)
    ):
        raise HTTPException(status_code=422, detail="Event start must be in the future")

    end = event.ends_at
    if end is not None and (
        end.tzinfo is None
        or end.utcoffset() is None
        or end <= start
    ):
        raise HTTPException(status_code=422, detail="Event end must be after start")

    if (
        not event.title.strip()
        or len(event.title) > 160
        or not event.description.strip()
        or len(event.description) > 10_000
        or not event.venue.strip()
        or len(event.venue) > 200
        or not isinstance(event.seat_capacity, int)
        or not 1 <= event.seat_capacity <= 100_000
    ):
        raise HTTPException(status_code=422, detail="Draft event details are invalid")


async def _reject_submit_body(request: Request) -> None:
    """Submit is a command with no payload; never accept client-controlled state."""
    if await request.body():
        raise HTTPException(status_code=422, detail="Request body is not allowed")


@router.post(
    "/{club_id}/events/{event_id}/submit",
    status_code=status.HTTP_200_OK,
    dependencies=[Depends(_reject_submit_body)],
    response_model=DraftEventResponse,
    summary="Submit an unpublished draft event for Student Affairs approval",
    responses={
        401: {"description": "Missing or invalid bearer session"},
        403: {"description": "Student account required; no Student Affairs override"},
        404: {"description": "Club or draft event not found or access denied"},
        409: {"description": "Event is not an unpublished draft"},
        422: {"description": "Invalid identifiers, invalid draft, or unexpected request body"},
    },
)
def submit_draft_event(
    club_id: Annotated[UUID, Path(description="Club UUID")],
    event_id: Annotated[UUID, Path(description="Event UUID")],
    identity: Annotated[AuthenticatedIdentity, Depends(current_identity)],
    db: Annotated[Session, Depends(get_db)],
) -> Event:
    """Atomically transition draft -> pending with club-scoped authorization.

    Lock the club, membership, and event in the same transaction. A second
    concurrent request will observe the committed pending state and get 409.
    All unauthorized resource combinations return the same 404.
    """
    if identity.user.account_type != AccountType.STUDENT:
        raise HTTPException(status_code=403, detail="Insufficient permissions")

    event = db.scalar(
        select(Event)
        .join(Club, Event.club_id == Club.id)
        .join(ClubAdministrator, ClubAdministrator.club_id == Club.id)
        .where(
            Club.id == club_id,
            Club.is_active.is_(True),
            Club.approval_status == ClubApprovalStatus.APPROVED,
            ClubAdministrator.user_id == identity.user.id,
            Event.club_id == club_id,
            Event.id == event_id,
        )
        .with_for_update(of=(Club, ClubAdministrator, Event))
    )
    if event is None:
        raise HTTPException(status_code=404, detail="Club or event not found")

    if event.approval_status != EventApprovalStatus.DRAFT or event.is_published:
        raise HTTPException(status_code=409, detail="Event is not an unpublished draft")

    _ensure_ready_to_submit(event)

    event.approval_status = EventApprovalStatus.PENDING
    event.is_published = False
    db.commit()
    db.refresh(event)
    return event
