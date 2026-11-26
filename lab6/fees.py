from dataclasses import dataclass
from enum import Enum


BASE_RATE = 350
STAFF_CHILD_RATE = BASE_RATE * 0.5
HIGH_FEE_THRESHOLD = 6000
HIGH_FEE_REDUCTION = 200
SUMMER_FEE = 150


class StudentType(Enum):
    REGULAR = 1
    STAFF_CHILD = 2
    SCHOLARSHIP = 3


@dataclass(frozen=True)
class Course:
    hours: int


def _rate_for(student_type):
    if student_type is StudentType.REGULAR:
        return BASE_RATE
    if student_type is StudentType.STAFF_CHILD:
        return STAFF_CHILD_RATE
    if student_type is StudentType.SCHOLARSHIP:
        return 0
    raise ValueError(f"Unsupported student type: {student_type!r}")


def tuition_fee(courses, student_type, summer=False):
    rate = _rate_for(student_type)
    total = sum(course.hours * rate for course in courses)

    if total > HIGH_FEE_THRESHOLD:
        total -= HIGH_FEE_REDUCTION

    if summer:
        total += SUMMER_FEE

    return total


def process_all(students):
    return {
        student["name"]: tuition_fee(
            student["courses"],
            student["type"],
            student["summer"],
        )
        for student in students
    }
