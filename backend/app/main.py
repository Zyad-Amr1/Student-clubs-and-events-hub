"""CampusConnect FastAPI entry point.

Milestone 1 scaffold only. Authentication endpoints are not implemented yet.
"""

from fastapi import FastAPI

app = FastAPI(title="CampusConnect API", version="0.1.0")


@app.get("/health")
def health() -> dict[str, str]:
    """Lightweight readiness check; does not imply database connectivity."""
    return {"status": "ok"}
