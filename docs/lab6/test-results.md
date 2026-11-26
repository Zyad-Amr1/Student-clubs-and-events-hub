# Test Results

## Local tests — verified

### Lab 6

- `pytest -q`: **21 passed**.
- `coverage run --branch --source=fees,grades -m pytest -q`: **21 passed**.
- Coverage.py report: **100% statement coverage and 100% branch coverage** across `fees.py` and `grades.py`.
- `compileall`: passed.

### Lab 7

- `pytest -q`: **11 passed**.
- `compileall`: passed.
- Tests include course registration limits, duplicate prevention, course drop and released credit hours, invoice policy totals, injected writer behavior, and sibling pricing.

## Hosted Behave and Ruff

The repository workflow `.github/workflows/lab6-assignment.yml` installs the real `behave` and `ruff` packages and runs the feature files and lint checks on the submission branch. The hosted Behave result is reported only after GitHub Actions completes; no local Behave result is claimed because package installation is unavailable in the current offline execution environment.
