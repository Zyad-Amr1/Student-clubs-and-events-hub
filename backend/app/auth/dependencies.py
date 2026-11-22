"""Authorization enforced by signature validation and DB-backed revocation."""

from dataclasses import dataclass

import jwt
from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy.orm import Session

from app.auth.tokens import read_token, utcnow
from app.config import AuthenticationConfigurationError
from app.database import get_db
from app.models.auth_session import AuthSession
from app.models.user import User

_bearer = HTTPBearer(auto_error=False)


@dataclass
class AuthenticatedIdentity:
    user: User
    session: AuthSession


def _unauthorized() -> HTTPException:
    return HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Invalid or expired session",
        headers={"WWW-Authenticate": "Bearer"},
    )


def current_identity(
    credentials: HTTPAuthorizationCredentials | None = Depends(_bearer),
    db: Session = Depends(get_db),
) -> AuthenticatedIdentity:
    if credentials is None or credentials.scheme.lower() != "bearer":
        raise _unauthorized()

    try:
        user_id, token_id = read_token(credentials.credentials)
    except AuthenticationConfigurationError:
        raise HTTPException(
            status_code=503, detail="Authentication unavailable"
        ) from None
    except jwt.InvalidTokenError:
        raise _unauthorized() from None

    auth_session = db.get(AuthSession, token_id)
    user = db.get(User, user_id)
    if (
        auth_session is None
        or user is None
        or auth_session.user_id != user.id
        or auth_session.revoked_at is not None
        or auth_session.expires_at <= utcnow()
        or not user.is_active
    ):
        raise _unauthorized()
    return AuthenticatedIdentity(user=user, session=auth_session)
