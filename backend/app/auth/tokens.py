"""Short-lived HS256 access tokens bound to revocable PostgreSQL sessions."""

from datetime import datetime, timedelta, timezone
from uuid import UUID

import jwt

from app.config import get_jwt_secret

JWT_ISSUER = "campusconnect"
JWT_AUDIENCE = "campusconnect-android"
ACCESS_TOKEN_TTL = timedelta(hours=1)


def issue_token(user_id: UUID, token_id: UUID, now: datetime) -> tuple[str, datetime]:
    """Create a signed access token; never put roles or credential data in JWTs."""
    secret = get_jwt_secret()
    expires_at = now + ACCESS_TOKEN_TTL
    claims = {
        "sub": str(user_id),
        "jti": str(token_id),
        "iat": int(now.timestamp()),
        "exp": int(expires_at.timestamp()),
        "iss": JWT_ISSUER,
        "aud": JWT_AUDIENCE,
        "typ": "access",
    }
    encoded = jwt.encode(claims, secret, algorithm="HS256")
    return encoded, expires_at


def read_token(encoded: str) -> tuple[UUID, UUID]:
    """Validate algorithm, issuer, audience, expiry and required claims."""
    secret = get_jwt_secret()
    claims = jwt.decode(
        encoded,
        secret,
        algorithms=["HS256"],
        issuer=JWT_ISSUER,
        audience=JWT_AUDIENCE,
        options={"require": ["sub", "jti", "iat", "exp", "iss", "aud"]},
    )
    if claims.get("typ") != "access":
        raise jwt.InvalidTokenError("Unexpected token type")
    try:
        return UUID(claims["sub"]), UUID(claims["jti"])
    except (ValueError, TypeError, AttributeError, KeyError):
        raise jwt.InvalidTokenError("Malformed token identifier") from None


def utcnow() -> datetime:
    return datetime.now(timezone.utc)
