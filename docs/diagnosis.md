# Stage 2: Database Diagnosis

## Overview

The assessment dataset contains 822,832 records across six tables. The investigation identified data quality, referential integrity, category hierarchy, inventory consistency, and financial reporting issues.

The findings below summarise the key risks and recommended actions.

## 1. Data Completeness

**Key findings**
- 37 products (0.92%) have no category assignment.
- 148 order items (0.04%) have missing unit prices.
- 281,927 inventory records (99.85%) have no movement notes.

**Business impact**
- Unassigned products may be excluded from category-based reporting.
- Missing prices affect the accuracy of sales calculations.
- Missing notes reduce the context available when reviewing stock movements.

**Recommended actions**
- Review and assign missing product categories.
- Investigate missing historical selling prices rather than replacing them with current product prices.
- Improve inventory movement documentation.

## 2. Referential Integrity

**Key findings**
- 692 order items reference 689 non-existent orders.
- 210 orders reference 190 non-existent customers.
- 120 inventory movements reference 111 non-existent products.
- No orphan product-to-category references were found among non-NULL category IDs.

**Business impact**

Missing relationships can lead to incomplete reports, unreliable customer analysis, and inventory movements that cannot be associated with existing products.

The affected recorded values are 826,327.80 for orphan order items and 665,180.61 for orphan customer orders. These are affected transaction values, not confirmed financial losses. The currency was not established.

**Recommended actions**
- Investigate and reconcile orphan records.
- Introduce appropriate foreign key constraints after existing data has been reviewed and corrected.

## 3. Category Hierarchy

**Key findings**
- The database contains 94 categories and 7 root categories.
- Category 9003 references a non-existent parent (8999).
- Categories 9001 and 9002 form a circular relationship.
- Only 91 categories are reachable from the root categories.
- The maximum reachable hierarchy depth is 3.

**Business impact**

Broken relationships and circular references can cause categories to be excluded or incorrectly processed during hierarchical reporting.

**Recommended actions**
- Resolve the missing parent reference.
- Break the circular relationship.
- Implement a recursive, cycle-safe query that supports changing hierarchy depth.

## 4. Inventory Consistency

**Key findings**
- 14 products have negative stock, totalling 27 units below zero.
- 144 products have differences between their current stock quantities and net recorded inventory movements.
- The total absolute difference across these products is 2,553 units.
- All 90 `stock_take` records have a movement quantity of zero.
- Inventory corrections contain inconsistent or unclear notes.

**Business impact**

Negative stock can result in overselling. Differences between stock balances and movement records make reconciliation difficult.

The comparison assumes the inventory log contains the complete movement history. Its completeness has not been established, so the differences do not independently prove that current stock quantities are incorrect.

**Recommended actions**
- Prevent stock quantities from falling below zero.
- Investigate stock discrepancies.
- Standardise movement reasons and documentation.
- Ensure every stock movement is recorded consistently.

## 5. Financial Data Quality

**Key findings**
- 148 order items have NULL prices, while 152 have zero prices.
- These records affect 298 distinct orders.
- 2,279 orders have differences between their recorded totals and calculated item totals, among orders with fully priced items.
- Six order items have quantities of 100 or more; the maximum is 9,999.
- 577 groups contain repeated order, product, quantity, and price combinations, with 578 excess rows.

**Business impact**

These issues can affect sales reporting, revenue analysis, and the reliability of transaction records.

The order-total differences are not confirmed losses. Zero-priced items and repeated combinations may be legitimate business transactions; further investigation is required.

**Recommended actions**
- Investigate missing and zero-priced items.
- Establish how order totals are calculated and reconcile unexplained differences.
- Review unusually large quantities.
- Investigate repeated combinations before treating them as duplicates or deleting records.

## Diagnosis Summary

| Area | Priority finding |
|---|---|
| Data completeness | Missing product categories, prices, and inventory notes |
| Referential integrity | Orphan records across three relationships |
| Category hierarchy | Missing parent and circular relationship |
| Inventory consistency | Negative stock and unexplained quantity differences |
| Financial quality | Missing prices and order-total mismatches |

## Conclusion

The database has several integrity and data quality weaknesses that affect inventory control, reporting, and auditing.

The next stages will address these issues in line with Nana Adjei's requirements: prevent overselling, improve reporting performance, support dynamic category rollups, and provide a reliable inventory movement audit trail.

All findings are based on the supplied dataset and the diagnostic SQL scripts. Where the available data does not establish a root cause, further investigation is required.