"""CAMP-12/13: Student Affairs reviews submitted events, publishing approvals.

No self-approval, direct draft approval, or public alteration of publish state.
No new table/migration: use the existing event state and DB-backed role checks.
"""

from datetime import datetime, timezone
from typing import Annotated
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Path, Query
from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.auth.dependencies import require_roles
from app.database import get_db
from app.events.schemas import DraftEventResponse, EventReviewDecision, PendingEventPage
from app.models.club import Club, ClubApprovalStatus
from app.models.event import Event, EventApprovalStatus
from app.models.user import AccountType

router = APIRouter(
    prefix="/api/v1/student-affairs/events",
    tags=["Student Affairs Event Review"],
    dependencies=[Depends(require_roles(AccountType.STUDENT_AFFAIRS))],
)


@router.get(
    "/pending",
    response_model=PendingEventPage,
    summary="List submitted events awaiting Student Affairs decision",
)
def pending_event_queue(
    db: Annotated[Session, Depends(get_db)],
    page: Annotated[int, Query(ge=1, le=10_000)] = 1,
    page_size: Annotated[int, Query(ge=1, le=100)] = 20,
) -> PendingEventPage:
    filters = (
        Event.approval_status == EventApprovalStatus.PENDING,
        Event.is_published.is_(False),
        Event.cancelled_at.is_(None),
        Club.is_active.is_(True),
        Club.approval_status == ClubApprovalStatus.APPROVED,
    )
    total = db.scalar(
        select(func.count()).select_from(Event)
        .join(Club, Event.club_id == Club.id).where(*filters)
    ) or 0
    events = db.scalars(
        select(Event).join(Club, Event.club_id == Club.id)
        .where(*filters)
        .order_by(Event.created_at.asc(), Event.id.asc())
        .offset((page - 1) * page_size)
        .limit(page_size)
    ).all()
    return PendingEventPage(
        events=events, page=page, page_size=page_size, total=total
    )


@router.post(
    "/{event_id}/review",
    response_model=DraftEventResponse,
    responses={
        401: {"description": "Missing, expired or revoked session"},
        403: {"description": "Student Affairs account required"},
        404: {"description": "Event not found or club not approved/active"},
        409: {"description": "Event is not pending"},
        422: {"description": "Invalid review decision or expired event"},
    },
    summary="Approve and publish or reject a pending club event",
)
def review_pending_event(
    event_id: Annotated[UUID, Path(description="Event UUID")],
    decision: EventReviewDecision,
    db: Annotated[Session, Depends(get_db)],
) -> Event:
    club_id = db.scalar(select(Event.club_id).where(Event.id == event_id))
    if club_id is None:
        raise HTTPException(status_code=404, detail="Event not found")
    # Archive and all club-scoped activity acquire Club before Event.
    club = db.scalar(select(Club).where(
        Club.id == club_id,
        Club.is_active.is_(True),
        Club.approval_status == ClubApprovalStatus.APPROVED,
    ).with_for_update())
    if club is None:
        raise HTTPException(status_code=404, detail="Event not found")
    event = db.scalar(select(Event).where(Event.id == event_id).with_for_update())
    if event is None or event.club_id != club.id:
        raise HTTPException(status_code=404, detail="Event not found")
    if event.cancelled_at is not None:
        raise HTTPException(status_code=409, detail="Event was cancelled")
    if event.approval_status != EventApprovalStatus.PENDING or event.is_published:
        raise HTTPException(status_code=409, detail="Event is not pending")

    if decision.decision == "approve":
        if event.starts_at <= datetime.now(timezone.utc):
            raise HTTPException(status_code=422, detail="Event start is not in the future")
        event.approval_status = EventApprovalStatus.APPROVED
        event.is_published = True
    else:
        event.approval_status = EventApprovalStatus.REJECTED
        event.is_published = False

    db.commit()
    db.refresh(event)
    return event
