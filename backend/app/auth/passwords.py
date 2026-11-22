"""Memory-hard password hashing without third-party native extensions.

Uses the scrypt construction with a per-password random salt. Passwords are
never persisted or logged in plaintext. The format is versioned via its
scheme name and includes the work factors for future verification.
"""

import hashlib
import hmac
import secrets

_N = 1 << 17
_R = 8
_P = 1
_KEY_LENGTH = 32
_MAX_MEMORY = 256 * 1024 * 1024


def hash_password(password: str) -> str:
    """Return a salted scrypt password hash suitable for database storage."""
    salt = secrets.token_bytes(16)
    derived = hashlib.scrypt(
        password.encode("utf-8"),
        salt=salt,
        n=_N,
        r=_R,
        p=_P,
        dklen=_KEY_LENGTH,
        maxmem=_MAX_MEMORY,
    )
    return "$".join(("scrypt", str(_N), str(_R), str(_P), salt.hex(), derived.hex()))


def verify_password(password: str, encoded_hash: str) -> bool:
    """Verify a previously stored scrypt hash without timing-sensitive equality."""
    try:
        scheme, n, r, p, salt_hex, digest_hex = encoded_hash.split("$")
        if (scheme, int(n), int(r), int(p)) != ("scrypt", _N, _R, _P):
            return False
        salt, expected = bytes.fromhex(salt_hex), bytes.fromhex(digest_hex)
        if len(salt) != 16 or len(expected) != _KEY_LENGTH:
            return False
        actual = hashlib.scrypt(
            password.encode("utf-8"),
            salt=salt,
            n=_N,
            r=_R,
            p=_P,
            dklen=_KEY_LENGTH,
            maxmem=_MAX_MEMORY,
        )
    except (AttributeError, TypeError, ValueError):
        return False
    return hmac.compare_digest(actual, expected)
