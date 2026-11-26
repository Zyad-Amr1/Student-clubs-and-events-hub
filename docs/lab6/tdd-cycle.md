# TDD Evidence — Red → Green → Refactor

The commits below are on the submission branch and preserve the test-first sequence.

| Stage | Commit | Evidence |
|---|---|---|
| Starter | [3101b08](https://github.com/Zyad-Amr1/Student-clubs-and-events-hub/commit/3101b08be443d992b9bef6e31d2d7cde2349f0a1) | Supplied grade kata source added. |
| Red — tests | [fd27f28](https://github.com/Zyad-Amr1/Student-clubs-and-events-hub/commit/fd27f288cd680e744d26f3d9694401fb699b4c6b) and [2211b36](https://github.com/Zyad-Amr1/Student-clubs-and-events-hub/commit/2211b36ff8f007e8ba472608da8c7c4babfdc470) | Boundary tests and tuition regression tests added before implementation. |
| Red — failing stub | [ef1cee6](https://github.com/Zyad-Amr1/Student-clubs-and-events-hub/commit/ef1cee60f37002da4a916022f578534ee3d42a54) | Deliberate `NotImplementedError` stub made the new tuition tests fail: 9 failed, 12 passed. |
| Green | [79c4627](https://github.com/Zyad-Amr1/Student-clubs-and-events-hub/commit/79c46279dd94ab7048ee369b56dd462cca152759) | Implemented fee calculation; the complete Lab 6 suite passed. |
| Refactor | [602315d](https://github.com/Zyad-Amr1/Student-clubs-and-events-hub/commit/602315da0b68cea8394d3fd98b5f1ca3c910c11a) | Extracted `_rate_for` and simplified aggregation without changing behavior. |

## Final local verification after refactoring

```text
Lab 6: 21 passed
fees.py: 100% statement coverage, 100% branch coverage
grades.py: 100% statement coverage, 100% branch coverage
Combined: 100% statement coverage, 100% branch coverage

Lab 7 unit tests: 11 passed
```

The failing run was reproduced locally against the deliberate stub. The final green and refactor runs were rerun locally after the implementation changes.
