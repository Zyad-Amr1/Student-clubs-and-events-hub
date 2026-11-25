"""Reset only the in-process public-auth rate counters between isolated tests."""
import pytest

from app.auth.public_limits import clear_for_testing


@pytest.fixture(autouse=True)
def isolated_auth_rate_counters():
    clear_for_testing()
    yield
    clear_for_testing()
