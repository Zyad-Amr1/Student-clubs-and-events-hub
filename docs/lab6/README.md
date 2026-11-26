# SET312 Lab 6 — Submission

## Deliverables

- coverage-report.svg: coverage report rendered from the actual Coverage.py output.
- coverage-report.txt: exact report output.
- coverage-answer.txt: requested one-sentence answer.
- smells-table.md: completed code-smell analysis for the supplied legacy_invoice.py.
- behave-output.txt: real hosted Behave output.
- team-story.feature: three Gherkin scenarios for CampusConnect event reservations.
- tdd-cycle.md: Red → Green → Refactor evidence and commit links.
- test-results.md: local and hosted verification.

## Code folders

- [../../lab6/](../../lab6/) — grade/fee starter code, tests, and completed fees.py.
- [../../lab7/](../../lab7/) — course registration feature with Drop scenario, step definitions, invoice refactoring, and tests.

## Coverage command

```bash
coverage run --branch --source=fees,grades -m pytest -q
coverage report -m
```

Actual output:

```text
Name        Stmts   Miss Branch BrPart  Cover   Missing
-------------------------------------------------------
fees.py        32      0     10      0   100%
grades.py      10      0      6      0   100%
-------------------------------------------------------
TOTAL          42      0     16      0   100%
```

The measured modules have 100% statement and branch coverage.

## Hosted CI

[GitHub Actions — all checks passed](https://github.com/Zyad-Amr1/Student-clubs-and-events-hub/actions/runs/45872485198)

- 21 Lab 6 tests passed; coverage 100%.
- 11 Lab 7 tests passed.
- Behave: 7 scenarios and 29 steps passed.
- Ruff: all checks passed.
