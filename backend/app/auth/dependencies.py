"""Authorization enforced by signature validation and DB-backed revocation."""

from collections.abc import Callable
from dataclasses import dataclass
from uuid import UUID

import jwt
from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy.orm import Session

from app.auth.tokens import read_token, utcnow
from app.config import AuthenticationConfigurationError
from app.database import get_db
from app.models.auth_session import AuthSession
from app.models.user import AccountType, User

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


def verified_token_ids(
    credentials: HTTPAuthorizationCredentials | None = Depends(_bearer),
) -> tuple[UUID, UUID]:
    if credentials is None or credentials.scheme.lower() != "bearer":
        raise _unauthorized()

    try:
        return read_token(credentials.credentials)
    except AuthenticationConfigurationError:
        raise HTTPException(
            status_code=503, detail="Authentication unavailable"
        ) from None
    except jwt.InvalidTokenError:
        raise _unauthorized() from None


def current_identity(
    token_ids: tuple[UUID, UUID] = Depends(verified_token_ids),
    db: Session = Depends(get_db),
) -> AuthenticatedIdentity:
    user_id, token_id = token_ids
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


def require_roles(*allowed_roles: AccountType) -> Callable[[AuthenticatedIdentity], AuthenticatedIdentity]:
    """Require one of the specified account types from the authenticated database user."""
    def authorize(identity: AuthenticatedIdentity = Depends(current_identity)) -> AuthenticatedIdentity:
        if identity.user.account_type not in allowed_roles:
            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Insufficient permissions")
        return identity

    return authorize
