"""Club Head applications using the existing scoped administrator grants."""

from typing import Literal
from uuid import UUID

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel, ConfigDict, Field, model_validator
from sqlalchemy import select
from sqlalchemy.exc import IntegrityError

from app.auth.tokens import utcnow
from app.clubs.management_router import Affairs, DB, Student
from app.models.club import Club, ClubApprovalStatus
from app.models.club_administrator import ClubAdministrator
from app.models.club_head_request import ClubHeadRequest as Request
from app.models.user import AccountType, User

router = APIRouter(prefix="/api/v1", tags=["Club Head requests"])


class Decision(BaseModel):
    model_config = ConfigDict(extra="forbid", str_strip_whitespace=True)
    decision: Literal["approve", "reject"]
    reason: str | None = Field(default=None, max_length=1000)

    @model_validator(mode="after")
    def check_reason(self):
        if self.decision == "reject" and (not self.reason or "\x00" in self.reason):
            raise ValueError("Enter a valid rejection reason the applicant can see.")
        if self.decision == "approve" and self.reason is not None:
            raise ValueError("Only rejection takes a reason.")
        return self


def _active_club(db: DB, club_id: UUID, *, lock=False):
    query = select(Club).where(Club.id == club_id, Club.is_active.is_(True),
                               Club.approval_status == ClubApprovalStatus.APPROVED)
    club = db.scalar(query.with_for_update() if lock else query)
    if club is None:
        raise HTTPException(404, "Active club not found.")
    return club


def _has_head(db: DB, club_id: UUID):
    return db.scalar(select(ClubAdministrator.user_id).where(ClubAdministrator.club_id == club_id)) is not None


def _view(request, club_name, applicant_name=None):
    return {"id": request.id, "club_id": request.club_id, "club_name": club_name,
            "status": request.status, "reason": request.reason, "created_at": request.created_at,
            "decided_at": request.decided_at, "applicant_name": applicant_name}


@router.get("/clubs/{club_id}/head-vacancy")
def vacancy(club_id: UUID, identity: Student, db: DB):
    # One statement gives a consistent snapshot of availability and club visibility.
    assigned = select(ClubAdministrator.club_id).where(ClubAdministrator.club_id == Club.id).exists()
    pending = select(Request.id).where(Request.club_id == Club.id, Request.status == "pending").exists()
    row = db.execute(select(Club.name, assigned, pending).where(
        Club.id == club_id, Club.is_active.is_(True), Club.approval_status == ClubApprovalStatus.APPROVED,
    )).first()
    if row is None:
        raise HTTPException(404, "Active club not found.")
    name, has_head, has_pending = row
    return {"club_name": name, "availability": "assigned" if has_head else "locked" if has_pending else "open"}


@router.post("/clubs/{club_id}/head-requests", status_code=201)
def apply(club_id: UUID, identity: Student, db: DB):
    club = _active_club(db, club_id, lock=True)
    pending = db.scalar(select(Request.id).where(Request.club_id == club_id, Request.status == "pending"))
    if _has_head(db, club_id) or pending is not None:
        raise HTTPException(409, "Applications for this club are closed.")
    request = Request(club_id=club_id, student_id=identity.user.id)
    db.add(request)
    try:
        db.flush()
        result = _view(request, club.name)
        db.commit()
    except IntegrityError:
        db.rollback()
        raise HTTPException(409, "Applications for this club are closed.") from None
    return result


@router.get("/me/club-head-requests")
def my_requests(identity: Student, db: DB):
    rows = db.execute(select(Request, Club.name).join(Club, Club.id == Request.club_id)
                      .where(Request.student_id == identity.user.id)
                      .order_by(Request.created_at.desc(), Request.id)).all()
    return {"requests": [_view(*row) for row in rows]}


@router.get("/student-affairs/club-head-requests")
def pending_requests(identity: Affairs, db: DB):
    rows = db.execute(select(Request, Club.name, User.full_name).join(Club, Club.id == Request.club_id)
                      .join(User, User.id == Request.student_id).where(Request.status == "pending")
                      .order_by(Request.created_at, Request.id)).all()
    return {"requests": [_view(*row) for row in rows]}


@router.post("/student-affairs/club-head-requests/{request_id}/decision")
def decide(request_id: UUID, data: Decision, identity: Affairs, db: DB):
    club_id = db.scalar(select(Request.club_id).where(Request.id == request_id))
    if club_id is None:
        raise HTTPException(404, "Club Head request not found.")
    club = db.scalar(select(Club).where(Club.id == club_id).with_for_update())
    request = db.scalar(select(Request).where(Request.id == request_id).with_for_update())
    if request.status != "pending":
        raise HTTPException(409, "This request has already been reviewed.")
    if request.student_id == identity.user.id:
        raise HTTPException(403, "You cannot review your own request.")
    applicant = db.get(User, request.student_id, with_for_update=True)
    if data.decision == "approve":
        if not club.is_active or club.approval_status != ClubApprovalStatus.APPROVED:
            raise HTTPException(409, "Only active, approved clubs can receive a Club Head.")
        if not applicant.is_active or applicant.account_type != AccountType.STUDENT:
            raise HTTPException(409, "The applicant is no longer an active Student.")
        if _has_head(db, club_id):
            raise HTTPException(409, "This club already has a Club Head.")
        db.add(ClubAdministrator(club_id=club_id, user_id=applicant.id))
    request.status = "approved" if data.decision == "approve" else "rejected"
    request.reason = data.reason
    request.decided_at = utcnow()
    request.reviewed_by = identity.user.id
    result = _view(request, club.name, applicant.full_name)
    try:
        db.commit()
    except IntegrityError:
        db.rollback()
        raise HTTPException(409, "The Club Head assignment changed. Refresh and retry.") from None
    return result
