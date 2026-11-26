import pytest

from invoice import SiblingPolicy, make_invoice
from registration import Student


@pytest.fixture
def student():
    student = Student("2023001")
    student.register("SET312", 3)
    student.register("SET472", 3)
    return student


@pytest.mark.parametrize(
    "kind, expected",
    [
        ("regular", 7200),
        ("scholarship", 3600),
        ("international", 17000),
    ],
)
def test_invoice_total(student, kind, expected, tmp_path, monkeypatch):
    monkeypatch.chdir(tmp_path)
    assert make_invoice(student, kind) == expected


class FakeWriter:
    def __init__(self):
        self.saved = {}

    def write(self, student_id, text):
        self.saved[student_id] = text


def test_invoice_uses_injected_writer(student):
    fake = FakeWriter()
    make_invoice(student, "regular", writer=fake)
    assert fake.saved["2023001"] == "Invoice for 2023001: 7200 EGP"


def test_sibling_policy_is_registered_and_applies_default_discount(student):
    fake = FakeWriter()
    total = make_invoice(student, "sibling", writer=fake)
    assert total == 6480
    assert fake.saved["2023001"] == "Invoice for 2023001: 6480 EGP"


def test_sibling_policy_discount_is_configurable():
    assert SiblingPolicy(discount_rate=0.25).fee(10) == 9000
