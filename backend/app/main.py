"""CampusConnect FastAPI entry point."""

from fastapi import FastAPI, HTTPException, Request
from fastapi.exception_handlers import request_validation_exception_handler
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse

from app.auth.public_limits import check_public_auth_rate

from app.auth.router import router as auth_router
from app.auth.profile_router import router as profile_router
from app.clubs.router import router as clubs_router
from app.clubs.management_router import router as club_management_router
from app.clubs.membership_router import router as membership_router
from app.clubs.interview_router import router as interview_router
from app.events.router import router as events_router
from app.events.reservation_router import router as event_reservation_router
from app.events.review_router import router as event_review_router
from sqlalchemy import text
from sqlalchemy.exc import SQLAlchemyError

from app.config import DatabaseConfigurationError
from app.database import get_engine

app = FastAPI(title="CampusConnect API", version="0.1.0")
app.include_router(auth_router)
app.include_router(profile_router)
app.include_router(clubs_router)
app.include_router(club_management_router)
app.include_router(membership_router)
app.include_router(interview_router)
app.include_router(events_router)
app.include_router(event_reservation_router)
app.include_router(event_review_router)


@app.middleware("http")
async def throttle_public_auth(request: Request, call_next):
    denied = check_public_auth_rate(request)
    if denied is not None:
        return denied
    return await call_next(request)


@app.exception_handler(RequestValidationError)
async def sanitize_registration_validation(request: Request, exc: RequestValidationError):
    """Do not echo submitted passwords in FastAPI's 422 validation payload."""
    path = request.url.path
    is_club_management = (
        path.startswith("/api/v1/me/club-requests")
        or path.startswith("/api/v1/student-affairs/club-requests")
        or (path.startswith("/api/v1/club-admin/clubs/") and path.endswith("/profile"))
    )
    if not is_club_management and path not in {
        "/api/v1/auth/register", "/api/v1/auth/login",
        "/api/v1/auth/me", "/api/v1/auth/me/password",
    }:
        return await request_validation_exception_handler(request, exc)
    errors = [
        {key: error[key] for key in ("type", "loc", "msg") if key in error}
        for error in exc.errors()
    ]
    return JSONResponse(status_code=422, content={"detail": errors})


@app.get("/health")
def health() -> dict[str, str]:
    """Report application liveness independently of the database."""
    return {"status": "ok"}


@app.get(
    "/api/v1/health/db",
    responses={503: {"description": "Database unavailable"}},
)
def database_health() -> dict[str, str]:
    """Check that PostgreSQL accepts and executes a query."""
    try:
        with get_engine().connect() as connection:
            connection.execute(text("SELECT 1"))
    except (DatabaseConfigurationError, ImportError, SQLAlchemyError):
        raise HTTPException(status_code=503, detail="Database unavailable") from None
    return {"status": "ok"}
