from functools import lru_cache
from pathlib import Path

from pydantic import SecretStr, ValidationError
from pydantic_settings import BaseSettings, SettingsConfigDict
from sqlalchemy.engine import URL, make_url
from sqlalchemy.exc import ArgumentError


class DatabaseConfigurationError(Exception):
    """Database settings could not be loaded."""


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=Path(__file__).resolve().parents[1] / ".env",
        env_file_encoding="utf-8",
        extra="ignore",
        hide_input_in_errors=True,
    )

    database_url: SecretStr


@lru_cache(maxsize=1)
def get_database_url() -> URL:
    try:
        url = make_url(Settings().database_url.get_secret_value())
    except (ValidationError, ArgumentError, OSError, ValueError):
        raise DatabaseConfigurationError("Invalid or missing DATABASE_URL") from None

    if url.drivername != "postgresql+psycopg":
        raise DatabaseConfigurationError("DATABASE_URL must use postgresql+psycopg")
    return url
