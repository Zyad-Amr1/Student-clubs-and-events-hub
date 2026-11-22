"""Contract and password-hashing tests not requiring a running database."""

from pydantic import ValidationError
import pytest

from app.auth.passwords import hash_password, verify_password
from app.auth.schemas import StudentRegistrationRequest


def valid_details():
    return {
        "full_name": "  Example Student  ",
        "email": " Student@Example.EDU ",
        "university_id": " ab-123 ",
        "password": "StrongPassphrase#123",
        "confirm_password": "StrongPassphrase#123",
    }


def test_registration_normalizes_input():
    payload = StudentRegistrationRequest.model_validate(valid_details())
    assert payload.full_name == "Example Student"
    assert payload.email == "student@example.edu"
    assert payload.university_id == "AB-123"


@pytest.mark.parametrize(
    "changes",
    [
        {"email": "not-an-email"},
        {"full_name": "  "},
        {"password": "short", "confirm_password": "short"},
        {"confirm_password": "DifferentPassword"},
        {"account_type": "student_affairs"},
        {"is_active": False},
        {"university_id": "\t\n"},
    ],
)
def test_registration_rejects_invalid_and_privileged_fields(changes):
    with pytest.raises(ValidationError):
        StudentRegistrationRequest.model_validate({**valid_details(), **changes})


def test_scrypt_hashes_are_salted_and_verifiable():
    password = "StrongPassphrase#123"
    first = hash_password(password)
    second = hash_password(password)
    assert first.startswith("scrypt$")
    assert first != second
    assert password not in first
    assert verify_password(password, first)
    assert not verify_password("wrong password", first)
    assert not verify_password(password, "invalid hash")
