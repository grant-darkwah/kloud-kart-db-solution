# Kloud Kart Database Solution — Final Submission

## 1. Scope

This submission addresses four business requirements:

1. Prevent concurrent purchases from overselling inventory.
2. Produce customer spending reports for Monday business reviews.
3. Aggregate low-stock inventory through a recursive category hierarchy.
4. Maintain an audit trail of inventory movements.

The solution extends the supplied PostgreSQL database and preserves the original instructor-provided resources.

## 2. Implementation Summary

### Data diagnosis

The initial investigation established baseline row counts and examined referential integrity, category hierarchy quality, inventory consistency, order totals and customer identifiers.

Findings included orphaned records, a category cycle, an orphan category reference, negative stock, stock-to-log discrepancies, missing inventory-log notes, order-total mismatches and duplicate normalized email groups.

These findings identify data-quality issues; they do not independently establish financial loss or fraud.

### Overselling protection

The `place_order` function performs stock deduction and order creation transactionally. Its conditional stock update prevents competing transactions from both claiming the same final unit through the implemented purchase operation.

### Monday reporting

The reporting implementation provides customer spending, order counts, monthly spending over the trailing 12 months, cumulative spending and customer rankings.

It uses `orders.total_amount` because diagnosis identified mismatches between some order totals and their item-level sums.

### Recursive category rollup

The category rollup traverses nested categories without hard-coding hierarchy depth.

Stock classifications:
- Negative stock: anomaly
- Zero stock: out of stock
- 1–10 units: low stock
- Above 10 units: adequately stocked

### Inventory audit trail

Migration `002_inventory_audit_trail.sql` adds before-and-after quantities and available actor and reference metadata. It also installs audit behavior for product stock updates and protects audit records against ordinary updates and deletes.

## 3. Final Pipeline

Run the final pipeline from the repository root:

```bash
bash scripts/run_all.sh
