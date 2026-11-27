# Stage 8 — Final Pipeline Evidence

**Execution date:** 27 November 2026
**Target database:** `kloudkart_test`
**Pipeline:** `bash scripts/run_all.sh`

## Overall Result

The final pipeline completed successfully against the isolated test database.

Both required migrations were verified. Both inventory audit triggers were enabled at the end of execution.

## Concurrency Test Results

| Test | Result |
|---|---|
| Two buyers competing for one unit | 25/25 rounds passed; exactly one winner per round |
| Flash sale: 400 buyers, 50 units | 50 sold, 350 refused, 0 errors |
| Flash-sale duration | 12.84 seconds |
| Oversized purchase | Refused; stock unchanged |
| Audit trail after contention | 5 sales and 5 movements recorded |

## Final Database Checks

- Database: `kloudkart_test`
- Database user: `kloudkart_test`
- Inventory audit records at final check: 282,352
- Both inventory audit triggers: enabled

The audit-record count includes existing inventory log records. It should not be interpreted as the number of movements generated exclusively by the new audit mechanism.

## Pipeline Verification

The pipeline:

1. Verified the test database and source tables.
2. Ran the diagnosis SQL.
3. Verified migrations 001 and 002.
4. Executed reporting and performance SQL.
5. Executed the recursive category rollup.
6. Ran the original instructor race test through its wrapper.
7. Restored append-only audit protection.
8. Performed final database and audit checks.

## Execution Log

Full execution output:

`evidence/final/run-all-20261127-110525.log`

Generated log files are excluded from version control. This document preserves the key final results.

## Safety Boundary

The pipeline ran against `kloudkart_test`. It did not reset the database, reload the supplied dataset or modify production.