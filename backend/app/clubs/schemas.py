"""Public response schemas for club browsing."""

from uuid import UUID

from pydantic import BaseModel, ConfigDict


class ClubSummary(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    name: str
    description: str
    category: str
    logo_url: str | None


class ClubBrowseResponse(BaseModel):
    clubs: list[ClubSummary]
    page: int
    page_size: int
    total: int
