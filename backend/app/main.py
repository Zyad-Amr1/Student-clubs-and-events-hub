"""CampusConnect FastAPI entry point."""

from fastapi import FastAPI, HTTPException
from sqlalchemy import text
from sqlalchemy.exc import SQLAlchemyError

from app.config import DatabaseConfigurationError
from app.database import get_engine

app = FastAPI(title="CampusConnect API", version="0.1.0")


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
