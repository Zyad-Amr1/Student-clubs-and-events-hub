"""MVP public auth request throttling and scrypt memory-concurrency guard."""

from concurrent.futures import ThreadPoolExecutor
from threading import BoundedSemaphore, Event

import pytest

from app.auth import passwords
from app.auth import public_limits
from app.auth import router as auth_router
from test_event_creation import (
    draft_client,
    draft_test_engine,
    synthetic_test_password_hash,
)


def test_nonexistent_email_and_untrusted_forwarding_headers_cannot_avoid_rate_limit(
    draft_client, monkeypatch
):
    # Repeated requests stay cheap; middleware still sees every attempt.
    monkeypatch.setattr(auth_router, "hash_password", lambda password: "synthetic")
    url = "/api/v1/auth/login"
    for index in range(20):
        response = draft_client.post(
            url,
            json={"email": f"nonexistent-{index}@example.edu", "password": "wrong"},
            headers={"X-Forwarded-For": f"10.0.0.{index + 1}"},
        )
        assert response.status_code == 401, (index, response.text)
    denied = draft_client.post(
        url,
        json={"email": "nonexistent-unique@example.edu", "password": "wrong"},
        headers={"X-Forwarded-For": "192.0.2.20"},
    )
    assert denied.status_code == 429
    assert denied.headers["retry-after"] == "60"


def test_invalid_register_attempts_are_counted_and_valid_registration_survives(
    draft_client, draft_test_engine
):
    registered = draft_client.post("/api/v1/auth/register", json={
        "full_name": "Rate Limited Test Student",
        "email": "rate-register@example.edu",
        "university_id": "RATE-STUDENT",
        "password": "StrongRegistrationPass#123",
        "confirm_password": "StrongRegistrationPass#123",
    })
    assert registered.status_code == 201, registered.text
    for _ in range(7):
        invalid = draft_client.post("/api/v1/auth/register", json={})
        assert invalid.status_code == 422
    denied = draft_client.post("/api/v1/auth/register", json={})
    assert denied.status_code == 429


def test_scrypt_slots_are_bounded_without_real_concurrent_memory_stress(monkeypatch):
    from hashlib import scrypt as real_scrypt
    started = Event()
    release = Event()
    active = []
    def simulated_scrypt(*args, **kwargs):
        active.append(1)
        if len(active) >= 2:
            started.set()
        assert release.wait(10)
        return b"x" * 32

    monkeypatch.setattr(passwords.hashlib, "scrypt", simulated_scrypt)
    with ThreadPoolExecutor(max_workers=2) as executor:
        left = executor.submit(passwords.hash_password, "a")
        right = executor.submit(passwords.hash_password, "b")
        assert started.wait(10)
        with pytest.raises(passwords.PasswordHashCapacityError):
            passwords.hash_password("third")
        release.set()
        assert left.result(timeout=5).startswith("scrypt$")
        assert right.result(timeout=5).startswith("scrypt$")
    # Existing versioned hashing parameters were not altered.
    assert (passwords._N, passwords._R, passwords._P) == (131072, 8, 1)


def test_public_login_returns_503_when_scrypt_slots_busy(draft_client, monkeypatch):
    occupied = BoundedSemaphore(1)
    assert occupied.acquire(blocking=False)
    monkeypatch.setattr(passwords, "_HASH_SLOTS", occupied)
    try:
        denied = draft_client.post("/api/v1/auth/login", json={
            "email": "not-a-student@example.edu", "password": "wrong",
        })
        assert denied.status_code == 503
        assert denied.headers["retry-after"] == "1"
        assert "password" not in denied.text.lower()
    finally:
        occupied.release()


def test_in_process_limits_have_bounded_number_of_peer_buckets(
    draft_client, monkeypatch
):
    monkeypatch.setattr(public_limits, "_MAX_PEERS", 1)
    # Exercise the limiter directly with two distinct socket peers, not headers.
    from starlette.requests import Request
    def make_request(ip):
        return Request({"type": "http", "method": "POST", "path": "/api/v1/auth/login",
                        "headers": [], "client": (ip, 12345)})
    assert public_limits.check_public_auth_rate(make_request("203.0.113.1")) is None
    denied = public_limits.check_public_auth_rate(make_request("203.0.113.2"))
    assert denied is not None
    assert denied.status_code == 503
