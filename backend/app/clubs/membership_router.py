"""Student applications and club-scoped membership review."""
from datetime import datetime
from typing import Literal
from uuid import UUID

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel, ConfigDict
from sqlalchemy import select

from app.auth.tokens import utcnow
from app.clubs.management_router import DB, Page, Student, _managed_club
from app.models.club import Club, ClubApprovalStatus
from app.models.membership_application import MembershipApplication as Application
from app.models.user import User

router = APIRouter(prefix="/api/v1", tags=["Membership applications"])
PAGE_SIZE = 20


class ApplicationView(BaseModel):
    id: UUID
    club_id: UUID
    club_name: str
    applicant_name: str
    status: str
    submitted_at: datetime
    interview_required_at: datetime | None
    accepted_at: datetime | None


class ApplicationPage(BaseModel):
    applications: list[ApplicationView]
    has_more: bool


class Decision(BaseModel):
    model_config = ConfigDict(extra="forbid")
    decision: Literal["interview_required", "accepted"]


def _view(application: Application, club_name: str, applicant_name: str):
    return ApplicationView(
        id=application.id, club_id=application.club_id, club_name=club_name,
        applicant_name=applicant_name, status=application.status,
        submitted_at=application.submitted_at,
        interview_required_at=application.interview_required_at,
        accepted_at=application.accepted_at,
    )


def _list(db: DB, conditions, page: int, *, oldest_first: bool = False):
    order = (
        (Application.submitted_at.asc(), Application.id.asc()) if oldest_first
        else (Application.submitted_at.desc(), Application.id.desc())
    )
    rows = db.execute(
        select(Application, Club.name, User.full_name)
        .join(Club, Club.id == Application.club_id)
        .join(User, User.id == Application.student_id)
        .where(*conditions).order_by(*order)
        .offset((page - 1) * PAGE_SIZE).limit(PAGE_SIZE + 1)
    ).all()
    return ApplicationPage(
        applications=[_view(*row) for row in rows[:PAGE_SIZE]],
        has_more=len(rows) > PAGE_SIZE,
    )


@router.post("/clubs/{club_id}/applications", response_model=ApplicationView, status_code=201)
def apply(club_id: UUID, identity: Student, db: DB):
    club = db.scalar(select(Club).where(
        Club.id == club_id, Club.is_active.is_(True),
        Club.approval_status == ClubApprovalStatus.APPROVED,
    ).with_for_update())
    if club is None:
        raise HTTPException(404, "Club not found.")
    if db.scalar(select(Application.id).where(
        Application.club_id == club_id, Application.student_id == identity.user.id,
    )) is not None:
        raise HTTPException(409, "You already have a membership application for this club.")
    application = Application(club_id=club_id, student_id=identity.user.id)
    db.add(application)
    db.flush()
    result = _view(application, club.name, identity.user.full_name)
    db.commit()
    return result


@router.get("/me/applications", response_model=ApplicationPage)
def my_applications(identity: Student, db: DB, page: Page = 1):
    return _list(db, (Application.student_id == identity.user.id,), page)


@router.get("/me/memberships", response_model=ApplicationPage)
def my_memberships(identity: Student, db: DB, page: Page = 1):
    return _list(db, (Application.student_id == identity.user.id, Application.status == "accepted"), page)


@router.get("/club-admin/clubs/{club_id}/applications", response_model=ApplicationPage)
def club_applications(club_id: UUID, identity: Student, db: DB, page: Page = 1):
    _managed_club(db, club_id, identity.user.id)
    return _list(db, (Application.club_id == club_id,), page, oldest_first=True)


@router.post("/club-admin/clubs/{club_id}/applications/{application_id}/decision",
             response_model=ApplicationView)
def review_application(club_id: UUID, application_id: UUID, data: Decision, identity: Student, db: DB):
    club = _managed_club(db, club_id, identity.user.id)
    application = db.scalar(select(Application).where(
        Application.id == application_id, Application.club_id == club_id,
    ).with_for_update())
    if application is None:
        raise HTTPException(404, "Application not found.")
    if application.student_id == identity.user.id:
        raise HTTPException(403, "You cannot review your own application.")
    if application.status != "pending":
        raise HTTPException(409, "This application already has a review decision.")
    application.status = data.decision
    if data.decision == "accepted":
        application.accepted_at = utcnow()
    else:
        application.interview_required_at = utcnow()
    student = db.get(User, application.student_id)
    result = _view(application, club.name, student.full_name)
    db.commit()
    return result
