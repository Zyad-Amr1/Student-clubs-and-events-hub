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


def tuition_fee(courses, student_type, summer=False):
    total = 0

    for course in courses:
        if student_type is StudentType.REGULAR:
            total += course.hours * BASE_RATE
        elif student_type is StudentType.STAFF_CHILD:
            total += course.hours * STAFF_CHILD_RATE
        elif student_type is StudentType.SCHOLARSHIP:
            total += 0
        else:
            raise ValueError(f"Unsupported student type: {student_type!r}")

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
