"""CAMP-14/17: authenticated Student RSVP, FIFO waitlist and cancellation."""

from datetime import datetime, timezone
from typing import Annotated
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Path, Response, status
from sqlalchemy import func, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.auth.dependencies import AuthenticatedIdentity, current_identity
from app.database import get_db
from app.events.reservation_schemas import (
    EventReservationResponse,
    MyReservationsResponse,
    ReservedEventDetails,
)
from app.models.club import Club, ClubApprovalStatus
from app.models.event import Event, EventApprovalStatus
from app.models.event_reservation import EventReservation
from app.models.user import AccountType, User

router = APIRouter(prefix="/api/v1", tags=["Student Event Reservations"])

_CONFIRMED = "confirmed"
_WAITLISTED = "waitlisted"


def _require_student(identity: AuthenticatedIdentity) -> None:
    if identity.user.account_type != AccountType.STUDENT:
        raise HTTPException(status_code=403, detail="Student account required")


def _event_and_club(db: Session, event_id: UUID, *, lock_event: bool):
    statement = (
        select(Event, Club)
        .join(Club, Club.id == Event.club_id)
        .where(Event.id == event_id)
    )
    if lock_event:
        statement = statement.with_for_update(of=Event)
    return db.execute(statement).first()


def _is_reservable(event: Event, club: Club) -> bool:
    return (
        event.approval_status == EventApprovalStatus.APPROVED
        and event.is_published
        and event.starts_at > datetime.now(timezone.utc)
        and club.is_active
        and club.approval_status == ClubApprovalStatus.APPROVED
    )


def _waitlist_position(db: Session, reservation: EventReservation) -> int:
    """Return the 1-based position among active Student waitlist entries."""
    position = db.scalar(
        select(func.count(EventReservation.id))
        .join(User, User.id == EventReservation.user_id)
        .where(
            EventReservation.event_id == reservation.event_id,
            EventReservation.status == _WAITLISTED,
            EventReservation.id <= reservation.id,
            User.is_active.is_(True),
            User.account_type == AccountType.STUDENT,
        )
    )
    return int(position or 0)


def _reservation_response(
    db: Session, reservation: EventReservation, event: Event
) -> EventReservationResponse:
    return EventReservationResponse(
        event_id=reservation.event_id,
        status=reservation.status,
        waitlist_position=(
            _waitlist_position(db, reservation)
            if reservation.status == _WAITLISTED
            else None
        ),
        event=ReservedEventDetails.model_validate(event),
    )


def _promote_next_waitlisted(db: Session, event_id: UUID) -> None:
    """Promote the earliest still-active Student in this event's FIFO queue."""
    next_reservation = db.scalar(
        select(EventReservation)
        .join(User, User.id == EventReservation.user_id)
        .where(
            EventReservation.event_id == event_id,
            EventReservation.status == _WAITLISTED,
            User.is_active.is_(True),
            User.account_type == AccountType.STUDENT,
        )
        .order_by(EventReservation.id.asc())
        .limit(1)
        .with_for_update(of=EventReservation)
    )
    if next_reservation is not None:
        next_reservation.status = _CONFIRMED


@router.post(
    "/events/{event_id}/reservations",
    response_model=EventReservationResponse,
    status_code=status.HTTP_201_CREATED,
    responses={
        401: {"description": "Missing, expired or revoked session"},
        403: {"description": "Student account required"},
        404: {"description": "Event is not available for reservation"},
        409: {"description": "Student already has an active reservation"},
    },
    summary="Reserve a confirmed seat or join the event waitlist",
)
def reserve_event(
    event_id: Annotated[UUID, Path(description="Published event UUID")],
    identity: Annotated[AuthenticatedIdentity, Depends(current_identity)],
    db: Annotated[Session, Depends(get_db)],
) -> EventReservationResponse:
    _require_student(identity)

    locked = _event_and_club(db, event_id, lock_event=True)
    if locked is None:
        raise HTTPException(status_code=404, detail="Event not found or unavailable")
    event, club = locked
    if not _is_reservable(event, club):
        raise HTTPException(status_code=404, detail="Event not found or unavailable")

    existing = db.scalar(
        select(EventReservation).where(
            EventReservation.event_id == event.id,
            EventReservation.user_id == identity.user.id,
        )
    )
    if existing is not None:
        raise HTTPException(status_code=409, detail="Already reserved for this event")

    confirmed_count = db.scalar(
        select(func.count(EventReservation.id)).where(
            EventReservation.event_id == event.id,
            EventReservation.status == _CONFIRMED,
        )
    ) or 0
    reservation = EventReservation(
        event_id=event.id,
        user_id=identity.user.id,
        status=(_CONFIRMED if confirmed_count < event.seat_capacity else _WAITLISTED),
    )
    db.add(reservation)
    try:
        db.flush()
    except IntegrityError:
        db.rollback()
        raise HTTPException(status_code=409, detail="Already reserved for this event") from None

    response = _reservation_response(db, reservation, event)
    db.commit()
    return response


@router.delete(
    "/events/{event_id}/reservations",
    status_code=status.HTTP_204_NO_CONTENT,
    responses={
        401: {"description": "Missing, expired or revoked session"},
        403: {"description": "Student account required"},
        404: {"description": "Reservation not found for this Student"},
    },
    summary="Cancel the current Student's event reservation",
)
def cancel_event_reservation(
    event_id: Annotated[UUID, Path(description="Event UUID")],
    identity: Annotated[AuthenticatedIdentity, Depends(current_identity)],
    db: Annotated[Session, Depends(get_db)],
) -> Response:
    _require_student(identity)

    locked = _event_and_club(db, event_id, lock_event=True)
    if locked is None:
        raise HTTPException(status_code=404, detail="Reservation not found")
    event, club = locked
    reservation = db.scalar(
        select(EventReservation)
        .where(
            EventReservation.event_id == event.id,
            EventReservation.user_id == identity.user.id,
        )
        .with_for_update()
    )
    if reservation is None:
        raise HTTPException(status_code=404, detail="Reservation not found")

    released_confirmed_seat = reservation.status == _CONFIRMED
    db.delete(reservation)
    if (
        released_confirmed_seat
        and _is_reservable(event, club)
    ):
        db.flush()
        confirmed_count = db.scalar(
            select(func.count(EventReservation.id)).where(
                EventReservation.event_id == event.id,
                EventReservation.status == _CONFIRMED,
            )
        ) or 0
        if confirmed_count < event.seat_capacity:
            _promote_next_waitlisted(db, event.id)

    db.commit()
    return Response(status_code=status.HTTP_204_NO_CONTENT)


@router.get(
    "/me/reservations",
    response_model=MyReservationsResponse,
    responses={
        401: {"description": "Missing, expired or revoked session"},
        403: {"description": "Student account required"},
    },
    summary="List the current Student's confirmed and waitlisted events",
)
def my_event_reservations(
    identity: Annotated[AuthenticatedIdentity, Depends(current_identity)],
    db: Annotated[Session, Depends(get_db)],
) -> MyReservationsResponse:
    _require_student(identity)
    rows = db.execute(
        select(EventReservation, Event)
        .join(Event, Event.id == EventReservation.event_id)
        .where(EventReservation.user_id == identity.user.id)
        .order_by(Event.starts_at.asc(), EventReservation.id.asc())
    ).all()
    return MyReservationsResponse(
        reservations=[
            _reservation_response(db, reservation, event)
            for reservation, event in rows
        ]
    )
