"""Interview-day capacity, FCFS previews and explicit appointment publication."""
from datetime import date, datetime, time, timedelta, timezone
from hashlib import sha256
from json import dumps
from typing import Literal
from uuid import UUID

from fastapi import APIRouter, HTTPException
from pydantic import AwareDatetime, BaseModel, ConfigDict, Field, model_validator
from sqlalchemy import func, or_, select, text

from app.auth.tokens import utcnow
from app.clubs.management_router import DB, Student, _managed_club
from app.models.club import Club, ClubApprovalStatus
from app.models.interview import (
    InterviewCancellation as Cancellation, InterviewDay as Day,
    InterviewNotice as Notice, InterviewSelection as Selection,
)
from app.models.membership_application import MembershipApplication as Application
from app.models.user import AccountType, User

router = APIRouter(prefix="/api/v1", tags=["Interviews"])
ADMIN = "/club-admin/clubs/{club_id}/interview-days"
SELF = "/me/applications/{application_id}/interview"


class Period(BaseModel):
    model_config = ConfigDict(extra="forbid")
    start_minute: int = Field(strict=True, ge=0, lt=1440)
    end_minute: int = Field(strict=True, gt=0, le=1440)


class DaySetup(BaseModel):
    model_config = ConfigDict(extra="forbid")
    capacity: int = Field(strict=True, gt=0, le=2_147_483_647)
    duration_minutes: int = Field(strict=True, gt=0, le=1440)
    periods: list[Period] = Field(max_length=48)

    @model_validator(mode="after")
    def validate_windows(self):
        self.periods.sort(key=lambda item: item.start_minute)
        previous_end = 0
        for window in self.periods:
            if (window.start_minute < previous_end
                    or window.end_minute - window.start_minute < self.duration_minutes):
                raise ValueError("Availability must not overlap and each period must fit an interview.")
            previous_end = window.end_minute
        return self


class DayView(BaseModel):
    id: UUID
    day: date
    capacity: int
    selected: int
    duration_minutes: int
    periods: list[Period]
    cancelled: bool


class StudentDay(BaseModel):
    id: UUID
    day: date
    seats_available: int


class PickDay(BaseModel):
    model_config = ConfigDict(extra="forbid")
    day_id: UUID


class Slot(BaseModel):
    selection_id: UUID
    applicant_name: str
    status: Literal["proposed", "unscheduled", "confirmed", "cancelled",
                    "expired", "attended", "no_show"]
    starts_at: datetime | None = None
    ends_at: datetime | None = None
    cancellation_reason: str | None = None


class PublishItem(BaseModel):
    model_config = ConfigDict(extra="forbid")
    selection_id: UUID
    starts_at: AwareDatetime
    ends_at: AwareDatetime


class Publish(BaseModel):
    model_config = ConfigDict(extra="forbid")
    appointments: list[PublishItem] = Field(min_length=1, max_length=1440)


class CancelTarget(BaseModel):
    model_config = ConfigDict(extra="forbid")
    scope: Literal["day", "period", "appointment"]
    selection_id: UUID | None = None
    period: Period | None = None

    @model_validator(mode="after")
    def validate_target(self):
        if (self.selection_id is not None) != (self.scope == "appointment") or (
            (self.period is not None) != (self.scope == "period")
        ):
            raise ValueError("Choose a target matching the cancellation scope.")
        return self


class CancelRequest(BaseModel):
    model_config = ConfigDict(extra="forbid", str_strip_whitespace=True)
    target: CancelTarget
    preview_token: str = Field(pattern="^[a-f0-9]{64}$")
    reason: str = Field(min_length=1, max_length=1000)

    @model_validator(mode="after")
    def validate_reason(self):
        if "\x00" in self.reason:
            raise ValueError("Reason contains an invalid character.")
        return self


class Attendance(BaseModel):
    model_config = ConfigDict(extra="forbid")
    status: Literal["attended", "no_show"]


def _day(db: DB, club_id: UUID, day_id: UUID) -> Day:
    day = db.scalar(select(Day).where(Day.club_id == club_id, Day.id == day_id))
    if day is None:
        raise HTTPException(404, "Interview day not found.")
    return day


def _active_count(db: DB, day_id: UUID, *, published_only=False) -> int:
    query = select(func.count()).select_from(Selection).where(
        Selection.day_id == day_id, Selection.released_at.is_(None),
    )
    if published_only:
        query = query.where(Selection.published_at.is_not(None))
    return db.scalar(query)


def _admin_view(day: Day, count: int) -> DayView:
    return DayView(id=day.id, day=day.day, capacity=day.capacity, selected=count,
                   duration_minutes=day.duration_minutes, periods=day.periods,
                   cancelled=day.cancelled_at is not None)


def _at(day: date, minute: int) -> datetime:
    return datetime.combine(day, time.min, timezone.utc) + timedelta(minutes=minute)


def _notify(db: DB, application_id: UUID, kind: str, event_id: UUID, message: str):
    db.add(Notice(application_id=application_id, kind=kind,
                  event_key=f"{kind}:{event_id}", message=message))


def _status(selection: Selection, day: Day, now: datetime) -> str:
    if selection.cancellation_id is not None:
        return "cancelled"
    if selection.attendance is not None:
        return selection.attendance
    if selection.published_at is not None:
        return "confirmed"
    if selection.expired_at is not None or (
        selection.released_at is None and day.day < now.date()
    ):
        return "expired"
    return "unscheduled" if selection.released_at is None else "withdrawn"


def _release_unpublished(selection: Selection, day: Day, now: datetime):
    selection.released_at = now
    if day.day < now.date():
        selection.expired_at = _at(day.day, 1440)


def _fits(start, end, day: date, setup: DaySetup) -> bool:
    return end - start >= timedelta(minutes=setup.duration_minutes) and any(
        _at(day, p.start_minute) <= start < end <= _at(day, p.end_minute) for p in setup.periods
    )


@router.get(ADMIN)
def admin_days(club_id: UUID, identity: Student, db: DB) -> dict[str, list[DayView]]:
    _managed_club(db, club_id, identity.user.id)
    days = db.scalars(select(Day).where(Day.club_id == club_id).order_by(Day.day)).all()
    today = utcnow().date()
    return {"days": [_admin_view(day, _active_count(db, day.id, published_only=day.day < today))
                     for day in days]}


@router.put(ADMIN + "/by-date/{day_date}", response_model=DayView)
def save_day(club_id: UUID, day_date: date, data: DaySetup, identity: Student, db: DB):
    club = _managed_club(db, club_id, identity.user.id)
    if day_date < utcnow().date() or day_date == date.max:
        raise HTTPException(422, "Choose today or a future interview date in UTC.")
    day = db.scalar(select(Day).where(Day.club_id == club_id, Day.day == day_date))
    is_new = day is None
    if is_new:
        day = Day(club_id=club_id, day=day_date)
        db.add(day)
        count = 0
    else:
        if day.cancelled_at is not None:
            raise HTTPException(409, "This interview day was cancelled. Publish another date.")
        count = _active_count(db, day.id)
        if data.capacity < count:
            raise HTTPException(409, "Capacity cannot be below current day selections.")
        confirmed = db.scalars(select(Selection).where(
            Selection.day_id == day.id, Selection.published_at.is_not(None),
            Selection.released_at.is_(None),
        ))
        if any(not _fits(item.starts_at, item.ends_at, day_date, data) for item in confirmed):
            raise HTTPException(409, "The change would invalidate a confirmed interview.")
    day.capacity = data.capacity
    day.duration_minutes = data.duration_minutes
    day.periods = [period.model_dump() for period in data.periods]
    db.flush()
    if is_new:
        eligible = db.scalars(select(Application.id).join(User, User.id == Application.student_id)
            .where(Application.club_id == club_id, Application.status == "interview_required",
                   User.is_active.is_(True), User.account_type == AccountType.STUDENT))
        for application_id in eligible:
            _notify(db, application_id, "day_posted", day.id,
                    f"{club.name} posted an interview day for {day.day.isoformat()} UTC.")
    response = _admin_view(day, count)
    db.commit()
    return response


def _owned_application(db: DB, application_id: UUID, student_id: UUID) -> Application:
    application = db.scalar(select(Application).where(
        Application.id == application_id, Application.student_id == student_id,
    ))
    if application is None:
        raise HTTPException(404, "Application not found.")
    return application


def _lock_bookable_application(db: DB, application_id: UUID, student_id: UUID) -> Application:
    application = _owned_application(db, application_id, student_id)
    club = db.scalar(select(Club).where(
        Club.id == application.club_id, Club.is_active.is_(True),
        Club.approval_status == ClubApprovalStatus.APPROVED,
    ).with_for_update())
    if club is None:
        raise HTTPException(404, "Club not available.")
    db.refresh(application, with_for_update=True)
    if application.status != "interview_required":
        raise HTTPException(409, "This application is not eligible for an interview.")
    return application


def _selection(db: DB, application_id: UUID):
    return db.scalar(select(Selection).where(
        Selection.application_id == application_id, Selection.released_at.is_(None),
    ))


def _student_booking(selection: Selection, day: Day, reason: str | None, now: datetime):
    status = _status(selection, day, now)
    if status == "withdrawn":
        return None
    return {
        "day_id": day.id, "day": day.day,
        "status": status, "cancellation_reason": reason,
        "starts_at": selection.starts_at, "ends_at": selection.ends_at,
    }


@router.get(SELF)
def student_interview(application_id: UUID, identity: Student, db: DB):
    application = _owned_application(db, application_id, identity.user.id)
    club = db.get(Club, application.club_id)
    if club is None or club.approval_status != ClubApprovalStatus.APPROVED:
        raise HTTPException(404, "Club not available.")
    if club.is_active and application.status != "interview_required":
        raise HTTPException(409, "This application is not eligible for an interview.")

    now = utcnow()
    history = (select(Selection, Day, Cancellation.reason)
        .join(Day, Day.id == Selection.day_id)
        .outerjoin(Cancellation, Cancellation.id == Selection.cancellation_id)
        .where(Selection.application_id == application.id))
    if not club.is_active:
        history = history.where(Selection.cancellation_id.is_not(None))
    latest = db.execute(history.order_by(
        Selection.selected_at.desc(), Selection.id.desc(),
    ).limit(1)).first()
    if not club.is_active:
        if latest is None:
            raise HTTPException(404, "Club not available.")
        return {"days": [], "booking": _student_booking(*latest, now)}

    days = db.scalars(select(Day).where(
        Day.club_id == application.club_id, Day.day >= now.date(), Day.cancelled_at.is_(None),
    ).order_by(Day.day)).all()
    return {
        "days": [StudentDay(id=day.id, day=day.day,
                            seats_available=day.capacity - _active_count(db, day.id)) for day in days],
        "booking": _student_booking(*latest, now) if latest else None,
    }


@router.put(SELF)
def choose_day(application_id: UUID, data: PickDay, identity: Student, db: DB):
    application = _lock_bookable_application(db, application_id, identity.user.id)
    day = _day(db, application.club_id, data.day_id)
    now = utcnow()
    if day.cancelled_at is not None:
        raise HTTPException(409, "This interview day was cancelled. Choose another day.")
    if day.day < now.date():
        raise HTTPException(409, "This interview day has ended.")
    current = _selection(db, application.id)
    if current is not None and current.day_id == day.id:
        return _student_booking(current, day, None, now)
    if current is not None and current.published_at is not None:
        raise HTTPException(409, "This interview appointment is already confirmed.")
    if _active_count(db, day.id) >= day.capacity:
        raise HTTPException(409, "This interview day is full. Choose another day.")
    if current is not None:
        _release_unpublished(current, db.get(Day, current.day_id), now)
        db.flush()
    selection = Selection(application_id=application.id, day_id=day.id)
    db.add(selection)
    db.flush()
    response = _student_booking(selection, day, None, now)
    db.commit()
    return response


@router.delete(SELF, status_code=204)
def withdraw_selection(application_id: UUID, identity: Student, db: DB):
    application = _lock_bookable_application(db, application_id, identity.user.id)
    current = _selection(db, application.id)
    if current is None:
        return
    if current.published_at is not None:
        raise HTTPException(409, "This interview appointment is already confirmed.")
    _release_unpublished(current, db.get(Day, current.day_id), utcnow())
    db.commit()


def _generate(db: DB, day: Day) -> list[Slot]:
    rows = db.execute(
        select(Selection, Application.student_id, User.full_name, Cancellation.reason)
        .join(Application, Application.id == Selection.application_id)
        .join(User, User.id == Application.student_id)
        .outerjoin(Cancellation, Cancellation.id == Selection.cancellation_id)
        .where(Selection.day_id == day.id,
               or_(Selection.cancellation_id.is_not(None), Selection.expired_at.is_not(None),
                   Selection.published_at.is_not(None),
                   Selection.released_at.is_(None) & (Application.status == "interview_required")
                   & User.is_active.is_(True) & (User.account_type == AccountType.STUDENT)))
        .order_by(Application.submitted_at, Application.id)
    ).all()
    if not rows:
        return []

    student_ids = {student_id for _, student_id, _, _ in rows}
    confirmed = db.execute(select(Selection, Application.club_id, Application.student_id)
        .join(Application, Application.id == Selection.application_id)
        .where(Selection.published_at.is_not(None), Selection.released_at.is_(None),
               Selection.starts_at < _at(day.day, 1440), Selection.ends_at > _at(day.day, 0),
               or_(Application.club_id == day.club_id, Application.student_id.in_(student_ids)))
    ).all()
    club_busy = [(s.starts_at, s.ends_at) for s, c, _ in confirmed if c == day.club_id]
    student_busy = {}
    for s, _, student in confirmed:
        student_busy.setdefault(student, []).append((s.starts_at, s.ends_at))

    now = utcnow()
    cursor = max(now.replace(second=0, microsecond=0) + timedelta(minutes=1), _at(day.day, 0))
    duration = timedelta(minutes=day.duration_minutes)
    result = []
    for item, student, name, reason in rows:
        status = _status(item, day, now)
        if status != "unscheduled":
            result.append(Slot(selection_id=item.id, applicant_name=name, status=status,
                               starts_at=item.starts_at, ends_at=item.ends_at,
                               cancellation_reason=reason))
            continue
        slot = Slot(selection_id=item.id, applicant_name=name, status="unscheduled")
        blocked = club_busy + student_busy.get(student, [])
        for period in day.periods if day.cancelled_at is None else []:
            start = max(cursor, _at(day.day, period["start_minute"]))
            until = _at(day.day, period["end_minute"])
            while start + duration <= until:
                overlaps = [end for begin, end in blocked if start < end and begin < start + duration]
                if overlaps:
                    start = max(overlaps)
                    continue
                slot.status, slot.starts_at, slot.ends_at = "proposed", start, start + duration
                cursor = slot.ends_at
                break
            if slot.status == "proposed":
                break
        result.append(slot)
    return result


@router.get(ADMIN + "/{day_id}/schedule")
def preview(club_id: UUID, day_id: UUID, identity: Student, db: DB):
    _managed_club(db, club_id, identity.user.id)
    day = _day(db, club_id, day_id)
    audits = db.scalars(select(Cancellation).where(Cancellation.day_id == day.id)
                       .order_by(Cancellation.created_at.desc(), Cancellation.id)).all()
    return {"slots": _generate(db, day), "cancelled": day.cancelled_at is not None,
            "periods": day.periods,
            "cancellations": [{"target": row.target, "reason": row.reason,
                               "created_at": row.created_at} for row in audits]}


@router.post(ADMIN + "/{day_id}/schedule", status_code=204)
def publish(club_id: UUID, day_id: UUID, data: Publish, identity: Student, db: DB):
    # A student may interview for multiple clubs. Serialize publishing across clubs
    # before checking those conflicts, then lock the club against selection changes.
    db.execute(text("SELECT pg_advisory_xact_lock(74019205)"))
    _managed_club(db, club_id, identity.user.id)
    day = _day(db, club_id, day_id)
    if day.cancelled_at is not None:
        raise HTTPException(409, "This interview day was cancelled.")
    proposed = {slot.selection_id: slot for slot in _generate(db, day) if slot.status == "proposed"}
    ids = {item.selection_id for item in data.appointments}
    if len(ids) != len(data.appointments):
        raise HTTPException(422, "Each appointment can only be published once per request.")
    for item in data.appointments:
        slot = proposed.get(item.selection_id)
        if slot is None or (slot.starts_at, slot.ends_at) != (item.starts_at, item.ends_at):
            raise HTTPException(409, "The schedule changed. Refresh the preview before publishing.")
        selection = db.get(Selection, item.selection_id)
        selection.starts_at, selection.ends_at = slot.starts_at, slot.ends_at
        selection.published_at = utcnow()
        _notify(db, selection.application_id, "confirmed", selection.id,
                "Your interview appointment is confirmed.")
    db.commit()


def _cancellation_targets(db: DB, day: Day, target: CancelTarget, now: datetime):
    if day.cancelled_at is not None:
        raise HTTPException(409, "This interview day was already cancelled.")
    query = (select(Selection, User.full_name)
             .join(Application, Application.id == Selection.application_id)
             .join(User, User.id == Application.student_id)
             .where(Selection.day_id == day.id, Selection.released_at.is_(None),
                    Selection.attendance.is_(None)))
    if target.scope == "appointment":
        query = query.where(Selection.id == target.selection_id, Selection.published_at.is_not(None))
    elif target.scope == "period":
        window = target.period.model_dump()
        if window not in day.periods:
            raise HTTPException(409, "This availability period has changed.")
        query = query.where(Selection.published_at.is_not(None),
                            Selection.starts_at < _at(day.day, window["end_minute"]),
                            Selection.ends_at > _at(day.day, window["start_minute"]))
    elif day.day < now.date():
        # Past unpublished selections already expired.
        query = query.where(Selection.published_at.is_not(None))

    rows = db.execute(query.order_by(Selection.id)).all()
    if target.scope == "appointment" and not rows:
        raise HTTPException(409, "Only confirmed appointments without recorded attendance can be cancelled.")
    snapshot = [
        (str(selection.id), _status(selection, day, now))
        for selection, _ in rows
    ]
    token = sha256(dumps([str(day.id), target.model_dump(mode="json"), snapshot],
                         sort_keys=True).encode()).hexdigest()
    return rows, token


@router.post(ADMIN + "/{day_id}/cancellation-preview")
def cancellation_preview(club_id: UUID, day_id: UUID, target: CancelTarget, identity: Student, db: DB):
    _managed_club(db, club_id, identity.user.id)
    day = _day(db, club_id, day_id)
    now = utcnow()
    rows, token = _cancellation_targets(db, day, target, now)
    return {"preview_token": token, "affected": [
        {"selection_id": selection.id, "applicant_name": name,
         "status": _status(selection, day, now)} for selection, name in rows
    ]}


@router.post(ADMIN + "/{day_id}/cancel")
def cancel_interviews(club_id: UUID, day_id: UUID, data: CancelRequest, identity: Student, db: DB):
    club = _managed_club(db, club_id, identity.user.id)
    day = _day(db, club_id, day_id)
    now = utcnow()
    rows, token = _cancellation_targets(db, day, data.target, now)
    if token != data.preview_token:
        raise HTTPException(409, "The affected interviews changed. Preview the cancellation again.")
    audit = Cancellation(day_id=day.id, actor_id=identity.user.id,
                         target=data.target.model_dump(mode="json"), reason=data.reason)
    db.add(audit)
    db.flush()
    if data.target.scope == "day":
        day.cancelled_at = now
    elif data.target.scope == "period":
        day.periods = [window for window in day.periods if window != data.target.period.model_dump()]
    for selection, _ in rows:
        selection.released_at = now
        selection.cancellation_id = audit.id
        _notify(db, selection.application_id, "cancelled", audit.id,
                f"{club.name} cancelled your interview selection: {data.reason}")
    db.commit()
    return {"cancelled_count": len(rows)}


@router.put(ADMIN + "/{day_id}/appointments/{selection_id}/attendance", status_code=204)
def record_attendance(
    club_id: UUID, day_id: UUID, selection_id: UUID, data: Attendance, identity: Student, db: DB,
):
    _managed_club(db, club_id, identity.user.id)
    day = _day(db, club_id, day_id)
    selection = db.scalar(select(Selection).where(Selection.id == selection_id, Selection.day_id == day.id))
    if selection is None:
        raise HTTPException(404, "Interview appointment not found.")
    now = utcnow()
    if selection.released_at is not None or selection.published_at is None or selection.ends_at > now:
        raise HTTPException(409, "Attendance requires a finished, confirmed interview.")
    if selection.attendance is not None:
        if selection.attendance == data.status:
            return
        raise HTTPException(409, "Attendance was already recorded.")
    selection.attendance = data.status
    selection.attendance_by = identity.user.id
    selection.attendance_at = now
    db.commit()


@router.get("/me/interview-appointments")
def my_appointments(identity: Student, db: DB):
    rows = db.execute(select(Selection, Club.name, Day, Cancellation.reason).join(
        Application, Application.id == Selection.application_id,
    ).join(Club, Club.id == Application.club_id).join(Day, Day.id == Selection.day_id)
        .outerjoin(Cancellation, Cancellation.id == Selection.cancellation_id)
        .where(Application.student_id == identity.user.id)
        .distinct(Application.id)
        .order_by(Application.id, Selection.selected_at.desc(), Selection.id.desc())).all()
    now = utcnow()
    appointments = []
    for selection, club_name, day, reason in rows:
        booking = _student_booking(selection, day, reason, now)
        if booking is not None and booking["status"] != "unscheduled":
            appointments.append({**booking, "id": selection.id,
                "application_id": selection.application_id, "club_name": club_name,
                "published_at": selection.published_at,
                "notice": "Your interview appointment is confirmed."
                if booking["status"] == "confirmed" else None})
    return {"appointments": sorted(appointments, key=lambda row: (row["day"], row["club_name"]))}


@router.get("/me/interview-notices")
def my_notices(identity: Student, db: DB):
    rows = db.execute(select(Notice, Club.name).join(
        Application, Application.id == Notice.application_id,
    ).join(Club, Club.id == Application.club_id).where(
        Application.student_id == identity.user.id,
    ).order_by(Notice.created_at.desc(), Notice.id.desc())).all()
    return {"notices": [{"id": notice.id, "application_id": notice.application_id,
                         "club_name": name, "kind": notice.kind, "message": notice.message,
                         "created_at": notice.created_at} for notice, name in rows]}
