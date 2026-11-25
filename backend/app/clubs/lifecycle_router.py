"""Student Affairs club archive/reactivation with previews, audit and notices."""

from datetime import datetime
from hashlib import sha256
from json import dumps
from typing import Annotated
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, ConfigDict, Field, field_validator
from sqlalchemy import or_, select
from sqlalchemy.orm import Session

from app.auth.dependencies import AuthenticatedIdentity, require_roles
from app.auth.tokens import utcnow
from app.database import get_db
from app.models.club import Club, ClubApprovalStatus
from app.models.club_administrator import ClubAdministrator
from app.models.club_lifecycle import ClubLifecycleAudit, ClubLifecycleNotice
from app.models.event import Event
from app.models.event_reservation import EventReservation
from app.models.interview import InterviewCancellation, InterviewDay, InterviewNotice, InterviewSelection
from app.models.membership_application import MembershipApplication
from app.models.user import AccountType, User

router = APIRouter(prefix="/api/v1", tags=["Club lifecycle"])
Affairs = Annotated[AuthenticatedIdentity, Depends(require_roles(AccountType.STUDENT_AFFAIRS))]
Student = Annotated[AuthenticatedIdentity, Depends(require_roles(AccountType.STUDENT))]
DB = Annotated[Session, Depends(get_db)]


class ArchiveCommand(BaseModel):
    model_config = ConfigDict(extra="forbid", str_strip_whitespace=True)
    reason: str = Field(min_length=1, max_length=1000)
    preview_token: str = Field(min_length=64, max_length=64)

    @field_validator("reason")
    @classmethod
    def validate_reason(cls, value):
        if "\x00" in value:
            raise ValueError("Reason contains an invalid character.")
        return value


class ReactivateCommand(BaseModel):
    model_config = ConfigDict(extra="forbid", str_strip_whitespace=True)
    reason: str | None = Field(default=None, max_length=1000)

    @field_validator("reason")
    @classmethod
    def validate_reason(cls, value):
        if value is not None and "\x00" in value:
            raise ValueError("Reason contains an invalid character.")
        return value


def _activities(db: Session, club: Club, now: datetime):
    events = db.scalars(select(Event).where(
        Event.club_id == club.id, Event.starts_at > now, Event.cancelled_at.is_(None),
    ).order_by(Event.starts_at, Event.id)).all()
    days = db.scalars(select(InterviewDay).where(
        InterviewDay.club_id == club.id, InterviewDay.day >= now.date(),
        InterviewDay.cancelled_at.is_(None),
    ).order_by(InterviewDay.day, InterviewDay.id)).all()
    reservations = db.execute(select(EventReservation, User.full_name).join(
        User, User.id == EventReservation.user_id,
    ).join(Event, Event.id == EventReservation.event_id).where(
        Event.club_id == club.id, Event.starts_at > now,
        EventReservation.status.in_(("confirmed", "waitlisted")),
    ).order_by(Event.starts_at, EventReservation.id)).all()
    interviews = db.execute(select(InterviewSelection, MembershipApplication.student_id,
                                   User.full_name, InterviewDay).join(
        InterviewDay, InterviewDay.id == InterviewSelection.day_id,
    ).join(MembershipApplication, MembershipApplication.id == InterviewSelection.application_id).join(
        User, User.id == MembershipApplication.student_id,
    ).where(InterviewDay.club_id == club.id, InterviewDay.day >= now.date(),
            InterviewDay.cancelled_at.is_(None), InterviewSelection.released_at.is_(None),
            or_(InterviewSelection.published_at.is_(None), InterviewSelection.ends_at > now))
      .order_by(InterviewDay.day, InterviewSelection.selected_at, InterviewSelection.id)).all()
    snapshot = {
        "events": [(str(event.id), event.starts_at.isoformat()) for event in events],
        "reservations": [(row.id, row.status, name) for row, name in reservations],
        "days": [(str(day.id), day.day.isoformat()) for day in days],
        "interviews": [(str(row.id), str(student_id), name) for row, student_id, name, _ in interviews],
    }
    return events, days, reservations, interviews, snapshot


def _preview_token(club: Club, snapshot: dict) -> str:
    payload = {"club_id": str(club.id), "state": club.is_active,
               "approval": str(club.approval_status), "snapshot": snapshot}
    return sha256(dumps(payload, sort_keys=True).encode()).hexdigest()


def _notice(db: Session, club: Club, user_id: UUID, key: str, kind: str, message: str):
    db.add(ClubLifecycleNotice(club_id=club.id, user_id=user_id, event_key=key,
                               kind=kind, message=message))


@router.get("/student-affairs/clubs")
def clubs_for_lifecycle(identity: Affairs, db: DB):
    rows = db.execute(select(Club, ClubAdministrator.user_id, User.full_name).outerjoin(
        ClubAdministrator, ClubAdministrator.club_id == Club.id,
    ).outerjoin(User, User.id == ClubAdministrator.user_id).where(
        Club.approval_status == ClubApprovalStatus.APPROVED,
    ).order_by(Club.name, Club.id)).all()
    return {"clubs": [{"id": club.id, "name": club.name, "is_active": club.is_active,
                        "archived_at": club.archived_at, "archive_reason": club.archive_reason,
                        "administrator_id": admin_id, "administrator_name": admin_name}
                       for club, admin_id, admin_name in rows]}


@router.post("/student-affairs/clubs/{club_id}/archive-preview")
def archive_preview(club_id: UUID, identity: Affairs, db: DB):
    club = db.scalar(select(Club).where(Club.id == club_id).with_for_update())
    if club is None or club.approval_status != ClubApprovalStatus.APPROVED:
        raise HTTPException(404, "Approved club not found.")
    if not club.is_active:
        raise HTTPException(409, "Club is already archived.")
    events, days, reservations, interviews, snapshot = _activities(db, club, utcnow())
    return {"preview_token": _preview_token(club, snapshot),
            "events": [{"id": event.id, "title": event.title, "starts_at": event.starts_at,
                        "students": sum(1 for row, _ in reservations if row.event_id == event.id
                                        and row.status in ("confirmed", "waitlisted"))}
                       for event in events],
            "interview_days": [{"id": day.id, "day": day.day,
                                "students": sum(1 for _, _, _, item_day in interviews if item_day.id == day.id)}
                               for day in days],
            "affected_students": sorted({name for _, name in reservations} |
                                         {name for _, _, name, _ in interviews})}


@router.post("/student-affairs/clubs/{club_id}/archive")
def archive_club(club_id: UUID, data: ArchiveCommand, identity: Affairs, db: DB):
    club = db.scalar(select(Club).where(Club.id == club_id).with_for_update())
    if club is None or club.approval_status != ClubApprovalStatus.APPROVED:
        raise HTTPException(404, "Approved club not found.")
    if not club.is_active:
        raise HTTPException(409, "Club is already archived.")
    now = utcnow()
    events, days, reservations, interviews, snapshot = _activities(db, club, now)
    if data.preview_token != _preview_token(club, snapshot):
        raise HTTPException(409, "Club activities changed. Preview archiving again.")

    audit = ClubLifecycleAudit(club_id=club.id, actor_id=identity.user.id, action="archived",
                               reason=data.reason, affected=snapshot)
    db.add(audit)
    db.flush()
    club.is_active = False
    club.archived_at = now
    club.archive_reason = data.reason
    admin_ids = db.scalars(select(ClubAdministrator.user_id).where(
        ClubAdministrator.club_id == club.id)).all()
    for admin_id in admin_ids:
        _notice(db, club, admin_id, f"archive:{audit.id}:admin:{admin_id}", "club_archived",
                f"{club.name} was archived: {data.reason}")
    for event in events:
        event.cancelled_at, event.cancellation_reason, event.is_published = now, data.reason, False
    for reservation, _ in reservations:
        if reservation.status in ("confirmed", "waitlisted"):
            reservation.status = "cancelled"
            _notice(db, club, reservation.user_id, f"archive:{audit.id}:reservation:{reservation.id}",
                    "activity_cancelled", f"{club.name} cancelled {next(e.title for e in events if e.id == reservation.event_id)}: {data.reason}")

    for day in days:
        day_audit = InterviewCancellation(day_id=day.id, actor_id=identity.user.id,
            target={"scope": "day", "archive_audit_id": str(audit.id)}, reason=data.reason)
        db.add(day_audit)
        db.flush()
        day.cancelled_at = now
        for selection, student_id, _, item_day in interviews:
            if item_day.id == day.id and selection.released_at is None and selection.attendance is None:
                selection.released_at, selection.cancellation_id = now, day_audit.id
                db.add(InterviewNotice(application_id=selection.application_id,
                    event_key=f"cancelled:{day_audit.id}", kind="cancelled",
                    message=f"{club.name} cancelled your interview selection: {data.reason}"))
                _notice(db, club, student_id, f"archive:{audit.id}:interview:{selection.id}",
                        "activity_cancelled", f"{club.name} cancelled your interview: {data.reason}")
    db.commit()
    return {"club_id": club.id, "status": "archived", "archived_at": now,
            "archive_reason": data.reason, "cancelled_events": len(events),
            "cancelled_interview_days": len(days)}


@router.post("/student-affairs/clubs/{club_id}/reactivate")
def reactivate_club(club_id: UUID, data: ReactivateCommand, identity: Affairs, db: DB):
    club = db.scalar(select(Club).where(Club.id == club_id).with_for_update())
    if club is None or club.approval_status != ClubApprovalStatus.APPROVED:
        raise HTTPException(404, "Approved club not found.")
    if club.is_active:
        raise HTTPException(409, "Club is already active.")
    audit = ClubLifecycleAudit(club_id=club.id, actor_id=identity.user.id, action="reactivated",
                               reason=data.reason, affected={"cancelled_activities_restored": False})
    db.add(audit)
    club.is_active, club.archived_at, club.archive_reason = True, None, None
    for admin_id in db.scalars(select(ClubAdministrator.user_id).where(
            ClubAdministrator.club_id == club.id)).all():
        _notice(db, club, admin_id, f"reactivate:{audit.id}:admin:{admin_id}", "club_reactivated",
                f"{club.name} is active again. Previously cancelled activities remain cancelled."
                + (f" Reason: {data.reason}" if data.reason else ""))
    db.commit()
    return {"club_id": club.id, "status": "active", "reactivated_at": audit.created_at,
            "previous_activities_restored": False}


@router.get("/student-affairs/clubs/{club_id}/lifecycle-history")
def lifecycle_history(club_id: UUID, identity: Affairs, db: DB):
    if db.get(Club, club_id) is None:
        raise HTTPException(404, "Club not found.")
    rows = db.scalars(select(ClubLifecycleAudit).where(
        ClubLifecycleAudit.club_id == club_id,
    ).order_by(ClubLifecycleAudit.created_at.desc(), ClubLifecycleAudit.id.desc())).all()
    return {"history": [{"id": item.id, "action": item.action, "reason": item.reason,
                          "affected": item.affected, "created_at": item.created_at}
                         for item in rows]}


@router.get("/me/club-lifecycle-notices")
def my_lifecycle_notices(identity: Student, db: DB):
    rows = db.execute(select(ClubLifecycleNotice, Club.name).join(
        Club, Club.id == ClubLifecycleNotice.club_id,
    ).where(ClubLifecycleNotice.user_id == identity.user.id).order_by(
        ClubLifecycleNotice.created_at.desc(), ClubLifecycleNotice.id.desc()).limit(100)).all()
    return {"notices": [{"id": notice.id, "club_id": notice.club_id, "club_name": name,
                         "kind": notice.kind, "message": notice.message,
                         "created_at": notice.created_at} for notice, name in rows]}
