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


class AuthenticationConfigurationError(Exception):
    """Authentication secret is missing or too short."""


class AuthenticationSettings(BaseSettings):
    model_config = Settings.model_config
    jwt_secret_key: SecretStr | None = None


def get_jwt_secret() -> str:
    """Read the local secret without printing it or requiring DB settings."""
    try:
        settings = AuthenticationSettings()
        secret = settings.jwt_secret_key.get_secret_value() if settings.jwt_secret_key else ""
    except (ValidationError, OSError, ValueError):
        raise AuthenticationConfigurationError("JWT secret is not configured") from None
    if len(secret.encode("utf-8")) < 32:
        raise AuthenticationConfigurationError("JWT secret is missing or too short")
    return secret
