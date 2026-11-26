# Test Results

## Local tests — verified

### Lab 6

- pytest -q: **21 passed**.
- coverage run --branch --source=fees,grades -m pytest -q: **21 passed**.
- Coverage.py: **100% statement coverage and 100% branch coverage** across fees.py and grades.py.
- compileall: passed.

### Lab 7

- pytest -q: **11 passed**.
- compileall: passed.
- Tests include registration limits, duplicate prevention, course drop and released credit hours, invoice policy totals, injected writer behavior, and sibling pricing.

## Hosted GitHub Actions — all checks passed

Workflow: [Lab 6 Assignment Checks](https://github.com/Zyad-Amr1/Student-clubs-and-events-hub/actions/runs/45872622132)

- Lab 6 unit tests: **21 passed**.
- Branch coverage gate: **100%**.
- Lab 7 unit tests: **11 passed**.
- Behave: **1 feature passed, 7 scenarios passed, 29 steps passed; 0 failed**.
- Ruff: **All checks passed**.

The team-story feature is included as the three requested Gherkin scenarios for Part D. The executable Behave workflow runs the course-registration feature, whose steps are implemented in features/steps/registration_steps.py.
