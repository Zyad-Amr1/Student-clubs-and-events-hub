from uuid import UUID

from fastapi.testclient import TestClient
from sqlalchemy import DateTime, Enum

from app.database import Base
from app.main import app
from app.models.club import ClubApprovalStatus


def test_club_model_has_public_fields_and_database_constraints():
    table = Base.metadata.tables["clubs"]

    assert list(table.primary_key.columns.keys()) == ["id"]
    assert table.c.id.type.python_type is UUID
    for name in (
        "name",
        "description",
        "category",
        "approval_status",
        "is_active",
        "created_at",
        "updated_at",
    ):
        assert not table.c[name].nullable
    assert table.c.logo_url.nullable
    assert isinstance(table.c.approval_status.type, Enum)
    assert table.c.approval_status.type.enums == ["pending", "approved", "rejected"]
    assert table.c.id.server_default is not None
    assert table.c.created_at.server_default is not None
    assert table.c.updated_at.server_onupdate is not None
    for name in ("created_at", "updated_at"):
        assert isinstance(table.c[name].type, DateTime)
        assert table.c[name].type.timezone

    constraint_names = {constraint.name for constraint in table.constraints}
    assert {
        "ck_clubs_name_nonblank",
        "ck_clubs_description_nonblank",
        "ck_clubs_category_nonblank",
        "ck_clubs_logo_url_nonblank",
        "ck_clubs_approval_status",
    } <= constraint_names
    browse_index = next(index for index in table.indexes if index.name == "ix_clubs_browse")
    assert tuple(column.name for column in browse_index.columns) == (
        "approval_status",
        "is_active",
        "name",
        "id",
    )
    assert {status.value for status in ClubApprovalStatus} == {"pending", "approved", "rejected"}


def test_club_browse_openapi_documents_authenticated_student_contract():
    operation = app.openapi()["paths"]["/api/v1/clubs"]["get"]

    assert operation["security"] == [{"HTTPBearer": []}]
    assert {"401", "403", "422"} <= set(operation["responses"])
    parameters = {parameter["name"]: parameter for parameter in operation["parameters"]}
    assert set(parameters) == {"page", "page_size", "search", "category"}
    assert parameters["page"]["schema"]["maximum"] == 10_000
    assert parameters["page_size"]["schema"]["maximum"] == 100
    assert parameters["search"]["required"] is False
    assert parameters["category"]["required"] is False
    assert set(app.openapi()["components"]["schemas"]["ClubBrowseResponse"]["properties"]) == {
        "clubs",
        "page",
        "page_size",
        "total",
    }
    assert set(app.openapi()["components"]["schemas"]["ClubSummary"]["properties"]) == {
        "id",
        "name",
        "description",
        "category",
        "logo_url",
    }


def test_club_browse_rejects_missing_and_invalid_bearer_tokens(monkeypatch):
    monkeypatch.setenv("JWT_SECRET_KEY", "test-only-club-browse-key-0123456789-abcdef")

    with TestClient(app) as client:
        missing = client.get("/api/v1/clubs")
        invalid = client.get("/api/v1/clubs", headers={"Authorization": "Bearer invalid"})

    assert missing.status_code == invalid.status_code == 401
    assert missing.headers["www-authenticate"] == "Bearer"
    assert invalid.headers["www-authenticate"] == "Bearer"
