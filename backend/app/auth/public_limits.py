"""Small in-process public-auth throttle keyed by the actual connection peer.

Forwarding headers are deliberately ignored. Configure Uvicorn trusted proxy
settings at deployment; do not trust arbitrary client-supplied X-Forwarded-For.
Limits are per worker and are NOT shared between processes or instances.
"""

from collections import deque
from threading import Lock
from time import monotonic

from fastapi import Request
from fastapi.responses import JSONResponse

_WINDOW_SECONDS = 60.0
_LIMITS = {"/api/v1/auth/login": 20, "/api/v1/auth/register": 8}
_MAX_PEERS = 10_000
_lock = Lock()
_attempts: dict[tuple[str, str], deque[float]] = {}


def clear_for_testing() -> None:
    """Reset isolated in-process test counters; not part of the API."""
    with _lock:
        _attempts.clear()


def check_public_auth_rate(request: Request) -> JSONResponse | None:
    path = request.scope.get("path", "")
    limit = _LIMITS.get(path)
    if request.method != "POST" or limit is None:
        return None
    # ASGI scope.client is the transport peer, not an untrusted HTTP header.
    client = request.client
    peer = client.host if client and client.host else "unknown"
    key = (peer, path)
    now = monotonic()
    with _lock:
        bucket = _attempts.get(key)
        if bucket is None:
            if len(_attempts) >= _MAX_PEERS:
                # Expired peers are safe to reclaim before failing closed.
                stale = [
                    k for k, q in _attempts.items()
                    if not q or q[-1] <= now - _WINDOW_SECONDS
                ]
                for k in stale:
                    _attempts.pop(k, None)
                if len(_attempts) >= _MAX_PEERS:
                    return JSONResponse(
                        status_code=503,
                        content={"detail": "Authentication temporarily unavailable"},
                        headers={"Retry-After": "60"},
                    )
            bucket = deque()
            _attempts[key] = bucket
        while bucket and bucket[0] <= now - _WINDOW_SECONDS:
            bucket.popleft()
        if len(bucket) >= limit:
            return JSONResponse(
                status_code=429,
                content={"detail": "Too many authentication attempts. Try later."},
                headers={"Retry-After": "60"},
            )
        # Count every request before body parsing, including unknown identities,
        # malformed input and invalid passwords.
        bucket.append(now)
    return None
