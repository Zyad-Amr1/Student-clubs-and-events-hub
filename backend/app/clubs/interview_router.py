"""Interview-day capacity, FCFS previews and explicit appointment publication."""
from datetime import date, datetime, time, timedelta, timezone
from typing import Literal
from uuid import UUID

from fastapi import APIRouter, HTTPException
from pydantic import AwareDatetime, BaseModel, ConfigDict, Field, model_validator
from sqlalchemy import func, or_, select, text

from app.auth.tokens import utcnow
from app.clubs.management_router import DB, Student, _managed_club
from app.models.club import Club, ClubApprovalStatus
from app.models.interview import InterviewDay as Day, InterviewSelection as Selection
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
    status: Literal["proposed", "unscheduled", "confirmed"]
    starts_at: datetime | None = None
    ends_at: datetime | None = None


class PublishItem(BaseModel):
    model_config = ConfigDict(extra="forbid")
    selection_id: UUID
    starts_at: AwareDatetime
    ends_at: AwareDatetime


class Publish(BaseModel):
    model_config = ConfigDict(extra="forbid")
    appointments: list[PublishItem] = Field(min_length=1, max_length=1440)


def _day(db: DB, club_id: UUID, day_id: UUID) -> Day:
    day = db.scalar(select(Day).where(Day.club_id == club_id, Day.id == day_id))
    if day is None:
        raise HTTPException(404, "Interview day not found.")
    return day


def _active_count(db: DB, day_id: UUID) -> int:
    return db.scalar(select(func.count()).select_from(Selection).where(
        Selection.day_id == day_id, Selection.released_at.is_(None),
    ))


def _admin_view(day: Day, count: int) -> DayView:
    return DayView(id=day.id, day=day.day, capacity=day.capacity, selected=count,
                   duration_minutes=day.duration_minutes, periods=day.periods)


def _at(day: date, minute: int) -> datetime:
    return datetime.combine(day, time.min, timezone.utc) + timedelta(minutes=minute)


def _fits(start, end, day: date, setup: DaySetup) -> bool:
    return end - start >= timedelta(minutes=setup.duration_minutes) and any(
        _at(day, p.start_minute) <= start < end <= _at(day, p.end_minute) for p in setup.periods
    )


@router.get(ADMIN)
def admin_days(club_id: UUID, identity: Student, db: DB) -> dict[str, list[DayView]]:
    _managed_club(db, club_id, identity.user.id)
    days = db.scalars(select(Day).where(Day.club_id == club_id).order_by(Day.day)).all()
    return {"days": [_admin_view(day, _active_count(db, day.id)) for day in days]}


@router.put(ADMIN + "/by-date/{day_date}", response_model=DayView)
def save_day(club_id: UUID, day_date: date, data: DaySetup, identity: Student, db: DB):
    _managed_club(db, club_id, identity.user.id)
    if day_date < utcnow().date() or day_date == date.max:
        raise HTTPException(422, "Choose today or a future interview date in UTC.")
    day = db.scalar(select(Day).where(Day.club_id == club_id, Day.day == day_date))
    if day is None:
        day = Day(club_id=club_id, day=day_date)
        db.add(day)
        count = 0
    else:
        count = _active_count(db, day.id)
        if data.capacity < count:
            raise HTTPException(409, "Capacity cannot be below current day selections.")
        confirmed = db.scalars(select(Selection).where(
            Selection.day_id == day.id, Selection.published_at.is_not(None),
        ))
        if any(not _fits(item.starts_at, item.ends_at, day_date, data) for item in confirmed):
            raise HTTPException(409, "The change would invalidate a confirmed interview.")
    day.capacity = data.capacity
    day.duration_minutes = data.duration_minutes
    day.periods = [period.model_dump() for period in data.periods]
    db.flush()
    response = _admin_view(day, count)
    db.commit()
    return response


def _owned_application(db: DB, application_id: UUID, student_id: UUID, *, lock=False):
    application = db.scalar(select(Application).where(
        Application.id == application_id, Application.student_id == student_id,
    ))
    if application is None:
        raise HTTPException(404, "Application not found.")
    club_query = select(Club).where(
        Club.id == application.club_id, Club.is_active.is_(True),
        Club.approval_status == ClubApprovalStatus.APPROVED,
    )
    if lock:
        club_query = club_query.with_for_update()
    if db.scalar(club_query) is None:
        raise HTTPException(404, "Club not available.")
    if lock:
        db.refresh(application, with_for_update=True)
    if application.status != "interview_required":
        raise HTTPException(409, "This application is not eligible for an interview.")
    return application


def _selection(db: DB, application_id: UUID):
    return db.scalar(select(Selection).where(
        Selection.application_id == application_id, Selection.released_at.is_(None),
    ))


def _student_booking(selection: Selection | None, day: Day | None):
    if selection is None:
        return None
    return {
        "day_id": day.id, "day": day.day,
        "status": "confirmed" if selection.published_at else "day_selected",
        "starts_at": selection.starts_at, "ends_at": selection.ends_at,
    }


@router.get(SELF)
def student_interview(application_id: UUID, identity: Student, db: DB):
    application = _owned_application(db, application_id, identity.user.id)
    days = db.scalars(select(Day).where(
        Day.club_id == application.club_id, Day.day >= utcnow().date(),
    ).order_by(Day.day)).all()
    selection = _selection(db, application.id)
    selected_day = db.get(Day, selection.day_id) if selection else None
    return {
        "days": [StudentDay(id=day.id, day=day.day,
                            seats_available=day.capacity - _active_count(db, day.id)) for day in days],
        "booking": _student_booking(selection, selected_day),
    }


@router.put(SELF)
def choose_day(application_id: UUID, data: PickDay, identity: Student, db: DB):
    application = _owned_application(db, application_id, identity.user.id, lock=True)
    day = _day(db, application.club_id, data.day_id)
    if day.day < utcnow().date():
        raise HTTPException(409, "This interview day has ended.")
    current = _selection(db, application.id)
    if current is not None and current.day_id == day.id:
        return _student_booking(current, day)
    if current is not None and current.published_at is not None:
        raise HTTPException(409, "This interview appointment is already confirmed.")
    if _active_count(db, day.id) >= day.capacity:
        raise HTTPException(409, "This interview day is full. Choose another day.")
    if current is not None:
        current.released_at = utcnow()
        db.flush()
    selection = Selection(application_id=application.id, day_id=day.id)
    db.add(selection)
    db.flush()
    response = _student_booking(selection, day)
    db.commit()
    return response


@router.delete(SELF, status_code=204)
def withdraw_selection(application_id: UUID, identity: Student, db: DB):
    application = _owned_application(db, application_id, identity.user.id, lock=True)
    current = _selection(db, application.id)
    if current is None:
        return
    if current.published_at is not None:
        raise HTTPException(409, "This interview appointment is already confirmed.")
    current.released_at = utcnow()
    db.commit()


def _generate(db: DB, day: Day) -> list[Slot]:
    rows = db.execute(
        select(Selection, Application.student_id, User.full_name)
        .join(Application, Application.id == Selection.application_id)
        .join(User, User.id == Application.student_id)
        .where(Selection.day_id == day.id, Selection.released_at.is_(None),
               or_(Selection.published_at.is_not(None),
                   (Application.status == "interview_required") & User.is_active.is_(True)
                   & (User.account_type == AccountType.STUDENT)))
        .order_by(Application.submitted_at, Application.id)
    ).all()
    if not rows:
        return []

    student_ids = {student_id for _, student_id, _ in rows}
    confirmed = db.execute(select(Selection, Application.club_id, Application.student_id)
        .join(Application, Application.id == Selection.application_id)
        .where(Selection.published_at.is_not(None),
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
    for item, student, name in rows:
        if item.published_at is not None:
            result.append(Slot(selection_id=item.id, applicant_name=name, status="confirmed",
                               starts_at=item.starts_at, ends_at=item.ends_at))
            continue
        slot = Slot(selection_id=item.id, applicant_name=name, status="unscheduled")
        blocked = club_busy + student_busy.get(student, [])
        for period in day.periods:
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
def preview(club_id: UUID, day_id: UUID, identity: Student, db: DB) -> dict[str, list[Slot]]:
    _managed_club(db, club_id, identity.user.id)
    return {"slots": _generate(db, _day(db, club_id, day_id))}


@router.post(ADMIN + "/{day_id}/schedule", status_code=204)
def publish(club_id: UUID, day_id: UUID, data: Publish, identity: Student, db: DB):
    # A student may interview for multiple clubs. Serialize publishing across clubs
    # before checking those conflicts, then lock the club against selection changes.
    db.execute(text("SELECT pg_advisory_xact_lock(74019205)"))
    _managed_club(db, club_id, identity.user.id)
    day = _day(db, club_id, day_id)
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
    db.commit()


@router.get("/me/interview-appointments")
def my_appointments(identity: Student, db: DB):
    rows = db.execute(select(Selection, Club.name).join(
        Application, Application.id == Selection.application_id,
    ).join(Club, Club.id == Application.club_id).where(
        Application.student_id == identity.user.id, Selection.published_at.is_not(None),
    ).order_by(Selection.starts_at, Selection.id)).all()
    return {"appointments": [
        {"id": appointment.id, "club_name": club_name, "starts_at": appointment.starts_at,
         "ends_at": appointment.ends_at, "published_at": appointment.published_at,
         "notice": "Your interview appointment is confirmed."}
        for appointment, club_name in rows
    ]}
