# Stage 4 – Monday Report Performance

## Environment
- Database: PostgreSQL 18
- Dataset: 822,832 rows
- Database: `kloudkart-test`
- `work_mem`: 32 MB
- Method: `EXPLAIN (ANALYZE, BUFFERS)`

## Benchmark Results

| Query | Execution Time |
|---|---:|
| Customer Spending Summary | 557.974 ms |
| Monthly Customer Spending | 638.416 ms |
| Running Customer Spending | 606.084 ms |
| Top 100 Customers | 499.292 ms |

## Key Findings

- All four reports execute in under one second.
- Expression statistics improved status-filter row estimates.
- Increasing `work_mem` eliminated hash aggregation disk spills.
- PostgreSQL uses sequential scans and hash joins effectively.
- Top 100 uses `top-N heapsort`.
- No additional indexes are justified by current benchmarks.

## Important Notes

- Only `completed` and `complete` orders are included.
- Status values are normalised using `LOWER(TRIM(status))`.
- Future-dated orders are excluded.
- Monthly reporting covers the trailing 12 calendar months.
- Running totals are calculated per customer within that period.
- Customer spending uses recorded order totals.

## Outstanding Improvements

- Remove redundant customer joins in Queries 03 and 04.
- Revalidate results after SQL simplification.
- Document benchmark conditions and results.

## Conclusion

All four reporting queries meet Nana Adjei's requirement
for a Monday report that runs in seconds on an ordinary
computer.