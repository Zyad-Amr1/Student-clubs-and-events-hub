from datetime import datetime, timedelta, timezone
from uuid import UUID

from fastapi.testclient import TestClient
import pytest
from pydantic import ValidationError
from sqlalchemy import DateTime, Enum

from app.database import Base
from app.clubs.schemas import EventSummary
from app.main import app
from app.models.event import EventApprovalStatus


def test_event_model_has_database_constraints_and_explicit_publication_state():
    table = Base.metadata.tables["events"]

    assert list(table.primary_key.columns.keys()) == ["id"]
    assert table.c.id.type.python_type is UUID
    for name in (
        "club_id",
        "title",
        "description",
        "venue",
        "starts_at",
        "seat_capacity",
        "approval_status",
        "is_published",
        "created_at",
        "updated_at",
    ):
        assert not table.c[name].nullable
    assert table.c.ends_at.nullable
    assert table.c.approval_status.type.enums == ["draft", "pending", "approved", "rejected"]
    assert isinstance(table.c.approval_status.type, Enum)
    assert table.c.approval_status.server_default is not None
    assert table.c.is_published.server_default is not None
    assert table.c.id.server_default is not None
    assert table.c.created_at.server_default is not None
    assert table.c.updated_at.server_onupdate is not None

    for name in ("starts_at", "ends_at", "created_at", "updated_at"):
        assert isinstance(table.c[name].type, DateTime)
        assert table.c[name].type.timezone

    foreign_key = next(iter(table.foreign_key_constraints))
    assert foreign_key.name == "fk_events_club_id_clubs"
    assert foreign_key.ondelete == "CASCADE"
    assert [(element.parent.name, element.target_fullname) for element in foreign_key.elements] == [
        ("club_id", "clubs.id")
    ]

    constraint_names = {constraint.name for constraint in table.constraints}
    assert {
        "ck_events_title_nonblank",
        "ck_events_description_nonblank",
        "ck_events_venue_nonblank",
        "ck_events_seat_capacity_positive",
        "ck_events_ends_after_start",
        "ck_events_approval_status",
    } <= constraint_names

    upcoming_index = next(index for index in table.indexes if index.name == "ix_events_club_upcoming")
    assert tuple(column.name for column in upcoming_index.columns) == (
        "club_id",
        "approval_status",
        "is_published",
        "starts_at",
        "id",
    )
    assert {status.value for status in EventApprovalStatus} == {
        "draft",
        "pending",
        "approved",
        "rejected",
    }


def test_club_details_openapi_documents_student_only_paged_contract():
    operation = app.openapi()["paths"]["/api/v1/clubs/{club_id}"]["get"]

    assert operation["security"] == [{"HTTPBearer": []}]
    assert {"401", "403", "404", "422"} <= set(operation["responses"])
    parameters = {parameter["name"]: parameter for parameter in operation["parameters"]}
    assert set(parameters) == {"club_id", "page", "page_size"}
    assert parameters["page"]["schema"]["minimum"] == 1
    assert parameters["page"]["schema"]["maximum"] == 10_000
    assert parameters["page_size"]["schema"]["maximum"] == 100

    schemas = app.openapi()["components"]["schemas"]
    assert set(schemas["ClubDetailsResponse"]["properties"]) == {
        "club",
        "events",
        "page",
        "page_size",
        "total",
    }
    assert set(schemas["EventSummary"]["properties"]) == {
        "id",
        "title",
        "description",
        "venue",
        "starts_at",
        "ends_at",
        "seat_capacity",
    }


def test_club_details_rejects_missing_and_invalid_bearer_tokens(monkeypatch):
    monkeypatch.setenv("JWT_SECRET_KEY", "test-only-event-details-key-0123456789-abcdef")
    club_id = "b04a96b6-e718-4d7e-88db-e99bec1abf08"

    with TestClient(app) as client:
        missing = client.get(f"/api/v1/clubs/{club_id}")
        invalid = client.get(
            f"/api/v1/clubs/{club_id}", headers={"Authorization": "Bearer invalid"}
        )

    assert missing.status_code == invalid.status_code == 401
    assert missing.headers["www-authenticate"] == "Bearer"
    assert invalid.headers["www-authenticate"] == "Bearer"


def test_event_response_normalizes_aware_times_to_utc_and_rejects_naive_times():
    starts_at = datetime(2030, 5, 1, 20, 0, tzinfo=timezone(timedelta(hours=2)))
    event = EventSummary(
        id=UUID(int=1),
        title="Public event",
        description="Public event details",
        venue="Main Hall",
        starts_at=starts_at,
        ends_at=None,
        seat_capacity=50,
    )

    assert event.starts_at == datetime(2030, 5, 1, 18, 0, tzinfo=timezone.utc)
    serialized_start = event.model_dump(mode="json")["starts_at"]
    assert serialized_start.endswith("Z") or serialized_start.endswith("+00:00")
    with pytest.raises(ValidationError):
        EventSummary(
            id=UUID(int=2),
            title="Naive event",
            description="Naive event details",
            venue="Main Hall",
            starts_at=datetime(2030, 5, 1, 18, 0),
            ends_at=None,
            seat_capacity=50,
        )
