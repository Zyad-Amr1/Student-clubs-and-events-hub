FEE_PER_HOUR = 1200


class RegularPolicy:
    def fee(self, hours):
        return hours * FEE_PER_HOUR


class ScholarshipPolicy:
    def fee(self, hours):
        return hours * FEE_PER_HOUR * 0.5


class SiblingPolicy:
    """Apply the configured sibling discount to the regular tuition rate.

    The assignment screenshot does not state a percentage, so the default
    is an explicit 10% discount and can be configured by callers.
    """

    DEFAULT_DISCOUNT_RATE = 0.10

    def __init__(self, discount_rate=DEFAULT_DISCOUNT_RATE):
        self.discount_rate = discount_rate

    def fee(self, hours):
        return hours * FEE_PER_HOUR * (1 - self.discount_rate)


class InternationalPolicy:
    RATE = 2000
    SERVICE_FEE = 5000

    def fee(self, hours):
        return hours * self.RATE + self.SERVICE_FEE


POLICIES = {
    "regular": RegularPolicy(),
    "scholarship": ScholarshipPolicy(),
    "sibling": SiblingPolicy(),
    "international": InternationalPolicy(),
}


class FileWriter:
    def write(self, student_id, text):
        with open(f"invoice_{student_id}.txt", "w") as file:
            file.write(text)


def make_invoice(student, kind, writer=None):
    policy = POLICIES[kind]
    total = policy.fee(student.total_hours)
    text = f"Invoice for {student.student_id}: {int(total)} EGP"
    (writer or FileWriter()).write(student.student_id, text)
    return total
