"""Club creation, decisions, and scoped editing."""
from datetime import datetime
from typing import Annotated, Literal
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Query
from pydantic import BaseModel, ConfigDict, Field, field_validator, model_validator
from sqlalchemy import func, select, text
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.auth.dependencies import AuthenticatedIdentity, require_roles
from app.auth.tokens import utcnow
from app.clubs.schemas import ClubSummary
from app.database import get_db
from app.images import MAX_IMAGE_BASE64, normalized_image
from app.models.club import Club, ClubApprovalStatus
from app.models.club_administrator import ClubAdministrator
from app.models.club_request import ClubRequest
from app.models.user import AccountType, User

router = APIRouter(prefix="/api/v1", tags=["Club management"])
Student = Annotated[AuthenticatedIdentity, Depends(require_roles(AccountType.STUDENT))]
Affairs = Annotated[AuthenticatedIdentity, Depends(require_roles(AccountType.STUDENT_AFFAIRS))]
DB = Annotated[Session, Depends(get_db)]
Page = Annotated[int, Query(ge=1, le=10000)]
PAGE_SIZE = 20


class ClubContent(BaseModel):
    model_config = ConfigDict(extra="forbid", str_strip_whitespace=True)

    description: str = Field(min_length=1, max_length=3000)
    category: str = Field(min_length=1, max_length=80)
    logo_base64: str | None = Field(default=None, max_length=MAX_IMAGE_BASE64)

    @field_validator("description", "category")
    @classmethod
    def reject_null_byte(cls, value):
        if "\x00" in value:
            raise ValueError("Text contains an invalid character.")
        return value


class ClubProposal(ClubContent):
    name: str = Field(min_length=1, max_length=120)

    @field_validator("name")
    @classmethod
    def normalize_name(cls, value):
        return " ".join(cls.reject_null_byte(value).split())


class ClubDecision(BaseModel):
    model_config = ConfigDict(extra="forbid", str_strip_whitespace=True)

    decision: Literal["approve", "reject"]
    reason: str | None = Field(default=None, max_length=1000)

    @model_validator(mode="after")
    def validate_reason(self):
        if self.decision == "reject" and not self.reason:
            raise ValueError("Enter a reason the student can see.")
        if self.decision == "approve" and self.reason is not None:
            raise ValueError("A reason is only accepted for rejection.")
        if self.reason is not None and "\x00" in self.reason:
            raise ValueError("Reason contains an invalid character.")
        return self


class ClubRequestView(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    name: str
    description: str
    category: str
    logo_url: str | None
    status: Literal["pending", "approved", "rejected", "withdrawn"]
    rejection_reason: str | None
    club_id: UUID | None
    created_at: datetime
    closed_at: datetime | None


class RequestPage(BaseModel):
    requests: list[ClubRequestView]
    has_more: bool


class SimilarClubs(BaseModel):
    clubs: list[ClubSummary]


def _page(db: Session, query, page: int) -> RequestPage:
    rows = db.scalars(query.offset((page - 1) * PAGE_SIZE).limit(PAGE_SIZE + 1)).all()
    return RequestPage(requests=rows[:PAGE_SIZE], has_more=len(rows) > PAGE_SIZE)


def _lock_name_registry(db: Session) -> None:
    # A name may move from the pending queue to the active clubs table.
    # Serialize both checks and all writes that move or reserve a name.
    db.execute(text("SELECT pg_advisory_xact_lock(74019204)"))


def _name_key(name):
    compact = func.btrim(func.regexp_replace(name, "[[:space:]]+", " ", "g"))
    return func.casefold(compact.collate("pg_unicode_fast"))


def _active_name_taken(db: Session, key: str) -> bool:
    return db.scalar(select(Club.id).where(
        Club.is_active.is_(True), _name_key(Club.name) == key,
    ).limit(1)) is not None


def _ensure_name(db: Session, name: str, current_id: UUID | None = None) -> str:
    key = db.scalar(select(_name_key(text(":club_name"))), {"club_name": name})
    pending = select(ClubRequest.id).where(ClubRequest.name_key == key, ClubRequest.status == "pending")
    if current_id is not None:
        pending = pending.where(ClubRequest.id != current_id)
    if _active_name_taken(db, key) or db.scalar(pending.limit(1)) is not None:
        raise HTTPException(409, "An active club or pending request already uses this name.")
    return key


def _apply_content(target: Club | ClubRequest, data: ClubContent) -> None:
    if "logo_base64" in data.model_fields_set:
        try:
            target.logo_url = normalized_image(data.logo_base64) if data.logo_base64 is not None else None
        except ValueError as error:
            raise HTTPException(422, str(error)) from None
    target.description = data.description
    target.category = data.category


def _pending(db: Session, request_id: UUID, student_id: UUID | None = None) -> ClubRequest:
    query = select(ClubRequest).where(ClubRequest.id == request_id)
    if student_id is not None:
        query = query.where(ClubRequest.student_id == student_id)
    request = db.scalar(query.with_for_update())
    if request is None:
        raise HTTPException(404, "Club request not found.")
    if request.status != "pending":
        raise HTTPException(409, "This request is already closed.")
    return request


def _save_request(db: Session, request: ClubRequest) -> ClubRequest:
    try:
        db.commit()
    except IntegrityError:
        db.rollback()
        raise HTTPException(409, "A conflicting club request already exists.") from None
    db.refresh(request)
    return request


@router.get("/me/club-requests", response_model=RequestPage)
def my_requests(identity: Student, db: DB, page: Page = 1):
    return _page(db, select(ClubRequest).where(
        ClubRequest.student_id == identity.user.id
    ).order_by(ClubRequest.created_at.desc(), ClubRequest.id.desc()), page)


@router.post("/me/club-requests", response_model=ClubRequestView, status_code=201)
def submit_request(data: ClubProposal, identity: Student, db: DB):
    _lock_name_registry(db)
    existing = db.scalar(select(ClubRequest.id).where(
        ClubRequest.student_id == identity.user.id, ClubRequest.status == "pending",
    ))
    if existing is not None:
        raise HTTPException(409, "You already have a pending club request.")
    request = ClubRequest(student_id=identity.user.id, name=data.name,
                          name_key=_ensure_name(db, data.name))
    _apply_content(request, data)
    db.add(request)
    return _save_request(db, request)


@router.put("/me/club-requests/{request_id}", response_model=ClubRequestView)
def edit_request(request_id: UUID, data: ClubProposal, identity: Student, db: DB):
    _lock_name_registry(db)
    request = _pending(db, request_id, identity.user.id)
    request.name_key = _ensure_name(db, data.name, request.id)
    request.name = data.name
    _apply_content(request, data)
    return _save_request(db, request)


@router.post("/me/club-requests/{request_id}/withdraw", response_model=ClubRequestView)
def withdraw_request(request_id: UUID, identity: Student, db: DB):
    _lock_name_registry(db)
    request = _pending(db, request_id, identity.user.id)
    request.status = "withdrawn"
    request.closed_at = utcnow()
    return _save_request(db, request)


@router.get("/student-affairs/club-requests", response_model=RequestPage)
def review_queue(_: Affairs, db: DB, page: Page = 1):
    return _page(db, select(ClubRequest).where(ClubRequest.status == "pending")
                 .order_by(ClubRequest.created_at, ClubRequest.id), page)


@router.get("/student-affairs/club-requests/{request_id}/similar", response_model=SimilarClubs)
def similar_clubs(request_id: UUID, _: Affairs, db: DB):
    request = db.get(ClubRequest, request_id)
    if request is None:
        raise HTTPException(404, "Club request not found.")
    clubs = db.scalars(select(Club).where(
        Club.is_active.is_(True),
        Club.approval_status == ClubApprovalStatus.APPROVED,
        func.lower(Club.category) == request.category.lower(),
    ).order_by(Club.name, Club.id).limit(20)).all()
    return SimilarClubs(clubs=clubs)


@router.post("/student-affairs/club-requests/{request_id}/decision", response_model=ClubRequestView)
def decide_request(request_id: UUID, data: ClubDecision, identity: Affairs, db: DB):
    _lock_name_registry(db)
    request = _pending(db, request_id)
    if request.student_id == identity.user.id:
        raise HTTPException(403, "You cannot review your own request.")
    if data.decision == "approve":
        student = db.get(User, request.student_id, with_for_update=True)
        if student is None or not student.is_active or student.account_type != AccountType.STUDENT:
            raise HTTPException(409, "The requester is no longer an active student.")
        _ensure_name(db, request.name, request.id)
        club = Club(name=request.name, description=request.description, category=request.category,
                    logo_url=request.logo_url, approval_status=ClubApprovalStatus.APPROVED,
                    is_active=True)
        db.add(club)
        db.flush()
        db.add(ClubAdministrator(club_id=club.id, user_id=student.id))
        request.club_id = club.id
        request.status = "approved"
    else:
        request.status = "rejected"
        request.rejection_reason = data.reason
    request.reviewed_by = identity.user.id
    request.closed_at = utcnow()
    return _save_request(db, request)


def _managed_club(db: Session, club_id: UUID, student_id: UUID) -> Club:
    club = db.scalar(select(Club).where(
        Club.id == club_id, Club.is_active.is_(True),
        Club.approval_status == ClubApprovalStatus.APPROVED,
    ).with_for_update())
    grant = db.get(ClubAdministrator, (club_id, student_id)) if club else None
    if grant is None:
        raise HTTPException(404, "Managed club not found.")
    return club


@router.get("/club-admin/clubs/{club_id}/profile", response_model=ClubSummary)
def managed_profile(club_id: UUID, identity: Student, db: DB):
    return _managed_club(db, club_id, identity.user.id)


@router.put("/club-admin/clubs/{club_id}/profile", response_model=ClubSummary)
def update_managed_profile(club_id: UUID, data: ClubContent, identity: Student, db: DB):
    club = _managed_club(db, club_id, identity.user.id)
    _apply_content(club, data)
    db.commit()
    db.refresh(club)
    return club
