# Stage 6 – Category Rollup Performance

## Environment
- Database: PostgreSQL 18.7
- Database: `kloudkart-test`
- Products: 4,023
- Categories: 94
- Valid reachable categories: 91
- Method: `EXPLAIN (ANALYZE, BUFFERS, VERBOSE)`
- Query: Complete Stage 5 category rollup report

## Benchmark Results

### Complete Category Report

| Run | Planning Time | Execution Time |
|---|---:|---:|
| 1 | 6.121 ms | 19.890 ms |
| 2 | 3.665 ms | 15.234 ms |
| 3 | 4.045 ms | 16.127 ms |
| Average | 4.610 ms | 17.084 ms |

### Main Category Rollup

| Metric | Result |
|---|---:|
| Warm-cache execution time | 3.265 ms |
| Categories returned | 91 |
| Low-stock products identified | 1,358 |
| Low-stock products included in valid root rollups | 1,347 |

## Key Findings

- The complete category report executes in approximately 17 ms on average.
- The main recursive category rollup executes in approximately 3.3 ms during the measured warm-cache run.
- PostgreSQL uses a recursive union to traverse the category hierarchy.
- Sequential scanning of the products table is reasonable for the current dataset.
- Hash aggregation completes in one batch without a disk spill in the observed main-query plan.
- No additional indexes or query rewrites are justified by the current measurements.

## Result Validation

The complete report returned 96 rows.

| Report Section | Rows |
|---|---:|
| Category rollup | 91 |
| Hierarchy exceptions | 3 |
| Unassigned inventory | 1 |
| Rollup validation | 1 |
| Total | 96 |

Root-category reconciliation:

- Valid root categories: 1,347 low-stock products and 5,034 units.
- Cyclic categories: 2 low-stock products and 8 units.
- Orphan categories: 0 low-stock products.
- Unassigned products: 9 low-stock products and 36 units.

The reconciliation is:

1,347 + 2 + 0 + 9 = 1,358 low-stock products.

## Important Notes

- Low stock is defined as `stock_quantity BETWEEN 1 AND 10`.
- Negative stock is classified as an inventory anomaly.
- Zero stock is classified as out of stock.
- Orphan and cyclic categories are reported separately.
- Products without category assignments are reported separately.
- Benchmark results describe the current test dataset and environment.
- Planning buffer statistics were captured, but a complete execution-buffer breakdown was not retained.

## Optimization Decision

The existing SQL implementation is retained.

No additional indexes, materialized views, or query rewrites are introduced because the measured execution times do not demonstrate a performance bottleneck.

Performance should be reassessed if product volume, category hierarchy complexity, or reporting frequency increases substantially.

## Conclusion

The complete category report executes in approximately 17 milliseconds on average in the current test environment.

The recursive hierarchy traversal and inventory aggregation meet the performance requirements of the current workload. The existing implementation is retained without unnecessary database complexity.