# SET312 Lab 6 — Submission

## Deliverables

- `coverage-report.svg`: coverage report rendered from the actual Coverage.py output.
- `coverage-report.txt`: exact report output.
- `coverage-answer.txt`: requested one-sentence answer.
- `smells-table.md`: completed code-smell analysis for the supplied `legacy_invoice.py`.
- `team-story.feature`: three Gherkin scenarios for CampusConnect event reservations.
- `tdd-cycle.md`: Red → Green → Refactor evidence and commit links.
- `test-results.md`: local results and hosted verification status.

## Code folders

- [`../../lab6/`](../../lab6/) — grade/fee starter code, tests, and completed `fees.py`.
- [`../../lab7/`](../../lab7/) — course registration feature with Drop scenario, step definitions, invoice refactoring, and tests.

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
grades.py      12      0     10      0   100%
-------------------------------------------------------
TOTAL          44      0     20      0   100%
```

The measured modules have 100% statement and branch coverage.
