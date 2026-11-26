import pytest

from registration import RegistrationError, Student


def test_register_adds_hours():
    student = Student("2023001")
    student.register("SET312", 3)
    assert student.total_hours == 3


def test_cannot_go_over_18_hours():
    student = Student("2023001")
    student.register("SET312", 15)
    with pytest.raises(RegistrationError, match="credit-hour limit is 18"):
        student.register("SET472", 4)
    assert student.total_hours == 15


def test_cannot_register_same_course_twice():
    student = Student("2023001")
    student.register("SET312", 3)
    with pytest.raises(RegistrationError, match="already registered"):
        student.register("SET312", 3)


def test_drop_removes_course_and_releases_hours():
    student = Student("2023001")
    student.register("SET312", 3)
    student.register("SET472", 4)

    student.drop("SET312")

    assert student.total_hours == 4
    assert "SET312" not in student.courses


def test_drop_rejects_unregistered_course():
    student = Student("2023001")
    with pytest.raises(RegistrationError, match="is not registered"):
        student.drop("SET312")
