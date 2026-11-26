# Task C1 — Code Smells in `legacy_invoice.py`

| # | Code smell | Evidence in the starter file | Why it is a problem | Refactoring applied / recommended |
|---|---|---|---|---|
| 1 | Type Code / Conditional Logic | `kind` is a string and a long `if/elif` selects the pricing rule. | Adding a new pricing type requires editing the central function and increases conditional complexity. | Replace the type-based conditional with policy objects (`RegularPolicy`, `ScholarshipPolicy`, `InternationalPolicy`, and `SiblingPolicy`) selected through `POLICIES`. |
| 2 | Magic Numbers | `1200`, `0.5`, `2000`, and `5000` are embedded in calculations. | The meaning of each number is not explicit and changes must be made in multiple places. | Replace magic numbers with named constants such as `FEE_PER_HOUR`, `RATE`, and `SERVICE_FEE`. |
| 3 | Long Method / Mixed Responsibilities | `make_invoice` calculates the amount, formats invoice text, opens a file, writes it, closes it, prints it, and returns the total. | Calculation, presentation, persistence, and console output are coupled in one operation. | Delegate pricing to a policy, keep invoice formatting in `make_invoice`, and move file output to `FileWriter`. |
| 4 | Manual Resource Management | `open(...)`, `write(...)`, and `close()` are called manually. | An exception between opening and closing can leave the file handle open. | Use a context manager (`with open(...) as file`) in `FileWriter.write`. |
| 5 | Primitive String Construction | Invoice text is built with chained string concatenation and `str(int(total))`. | Formatting is harder to read and edit. | Use an f-string in one clearly named formatting expression. |
| 6 | Hidden Side Effects / Tight Coupling | The function writes to a fixed filename and prints to the console. | A calculation test also causes filesystem and console side effects, making it harder to isolate. | Inject a writer dependency; tests can pass `FakeWriter` and verify output without creating a real file. |

## Refactoring outcome

`invoice.py` uses the Policy/Strategy approach: each pricing rule is represented by an object exposing `fee(hours)`. `make_invoice` selects the policy and delegates the calculation. `FileWriter` owns the filesystem operation and uses a context manager. The added `SiblingPolicy` is configurable.

**Sibling discount assumption:** the supplied assignment screenshot names `SiblingPolicy` but does not specify its discount percentage. The implementation therefore uses an explicit configurable default of 10% (`SiblingPolicy.DEFAULT_DISCOUNT_RATE = 0.10`). If the full handout specifies another percentage, that value should replace the default.
