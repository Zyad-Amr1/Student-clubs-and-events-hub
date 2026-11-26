import pytest

from fees import Course, StudentType, process_all, tuition_fee
from legacy_fees import calc


def legacy_courses(*hours):
    return [{"h": hours_value} for hours_value in hours]


def courses(*hours):
    return [Course(hours_value) for hours_value in hours]


def student(name, kind, summer=False):
    return {
        "name": name,
        "type": kind,
        "courses": courses(3),
        "summer": summer,
    }


@pytest.mark.parametrize(
    "hours, code, kind, summer",
    [
        ((3, 3, 3), 1, StudentType.REGULAR, False),
        ((3, 3, 3, 3, 3, 3), 1, StudentType.REGULAR, True),
        ((3, 4), 2, StudentType.STAFF_CHILD, False),
        ((3, 3), 3, StudentType.SCHOLARSHIP, True),
    ],
)
def test_same_result_as_legacy(hours, code, kind, summer):
    old = calc(legacy_courses(*hours), code, 2026, summer, None)
    new = tuition_fee(courses(*hours), kind, summer)
    assert new == old


def test_large_fee_gets_reduction():
    assert tuition_fee(courses(6, 6, 6), StudentType.REGULAR) == 6100


def test_scholarship_student_is_not_skipped():
    students = [
        student("Sara", StudentType.REGULAR),
        student("Omar", StudentType.SCHOLARSHIP),
    ]
    assert process_all(students) == {"Sara": 1050, "Omar": 0}


def test_empty_course_list_has_no_fee():
    assert tuition_fee([], StudentType.REGULAR) == 0


def test_process_all_accepts_an_empty_student_list():
    assert process_all([]) == {}


def test_unknown_student_type_is_rejected():
    with pytest.raises(ValueError, match="Unsupported student type"):
        tuition_fee(courses(3), "unknown")
