
# Stage 5 – Category Hierarchy Low-Stock Rollup

## Environment

- Database: PostgreSQL 18.7
- Database: `kloudkart_test`
- Products: 4,023
- Categories: 94
- Execution method: PostgreSQL recursive CTEs
- SQL script: `database/sql/category/01_low_stock_category_rollup.sql`
- Operation: Read-only

## Business Rule

A product is classified as low stock when:

```sql
stock_quantity BETWEEN 1 AND 10
```

Stock classifications:

| Stock Quantity | Classification |
|---|---|
| Below 0 | Inventory anomaly |
| 0 | Out of stock |
| 1–10 | Low stock |
| Above 10 | Adequately stocked |

The threshold is a demonstration business rule and can be adjusted according to replenishment policy.

## Category Rollup Results

| Root Category | Low-Stock Products | Low-Stock Units |
|---|---:|---:|
| Electronics | 417 | 1,543 |
| Home Appliances | 180 | 719 |
| Fashion | 253 | 915 |
| Groceries | 258 | 975 |
| Health and Beauty | 130 | 486 |
| Baby and Toys | 109 | 396 |
| Flash Sale Items | 0 | 0 |
| **Total** | **1,347** | **5,034** |

## Hierarchy Validation

| Metric | Result |
|---|---:|
| Total categories | 94 |
| Root categories | 7 |
| Root-reachable categories | 91 |
| Maximum reachable depth | 3 |
| Categories included in rollup | 91 |

The recursive query traverses the category hierarchy dynamically without hard-coding its depth.

## Hierarchy Exceptions

| Category ID | Category | Exception | Low-Stock Products |
|---|---|---|---:|
| 9001 | Seasonal Promotions | Cyclic category | 2 |
| 9002 | Promotions | Cyclic category | 0 |
| 9003 | Clearance | Orphan parent (8999) | 0 |

The cyclic relationship is:

`9001 → 9002 → 9001`

The orphan category references a parent category that does not exist.

These categories are excluded from the valid root-based rollup and reported separately.

## Unassigned Products

| Metric | Result |
|---|---:|
| Products without category assignments | 37 |
| Unassigned low-stock products | 9 |
| Unassigned low-stock units | 36 |

Products without category assignments are reported separately rather than silently excluded from the overall inventory analysis.

## Low-Stock Reconciliation

| Classification | Low-Stock Products |
|---|---:|
| Valid root hierarchies | 1,347 |
| Cyclic categories | 2 |
| Orphan categories | 0 |
| Unassigned products | 9 |
| **Total** | **1,358** |

The reconciliation matches the independently measured total of 1,358 low-stock products.

## Key Findings

- Recursive CTEs successfully traverse the category hierarchy.
- Parent categories include low-stock products from all descendants.
- The implementation does not assume a fixed hierarchy depth.
- Cyclic and orphan categories are identified separately.
- Unassigned products are included in exception reporting.
- Root-category totals reconcile with the valid hierarchy inventory.

## Important Notes

- Parent and child category counts overlap because parent totals include descendant products.
- Root-category totals should be used for non-overlapping hierarchy reconciliation.
- Negative and zero-stock products are not included in the low-stock rollup.
- The category hierarchy contains existing integrity issues that require separate remediation.
- No supplied schema files or inventory records were modified.

## Conclusion

The category rollup provides a hierarchical view of low-stock inventory across all 91 root-reachable categories. The implementation also exposes cyclic relationships, orphan categories, and unassigned products, ensuring that the 1,358 low-stock products are accounted for rather than silently omitted.
