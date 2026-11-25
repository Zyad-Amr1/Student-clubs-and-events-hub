"""Draft creation requires a verified Student with a club-specific DB grant."""

from typing import Annotated
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Path, status
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
