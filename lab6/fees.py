from dataclasses import dataclass
from enum import Enum


class StudentType(Enum):
    REGULAR = 1
    STAFF_CHILD = 2
    SCHOLARSHIP = 3


@dataclass(frozen=True)
class Course:
    hours: int


def tuition_fee(courses, student_type, summer=False):
    raise NotImplementedError("Implement tuition fee calculation")


def process_all(students):
    raise NotImplementedError("Implement batch fee calculation")
