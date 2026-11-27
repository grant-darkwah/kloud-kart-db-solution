# Stage 7 — Leave the Trail

## Objective

Introduce an auditable inventory movement trail that records future stock changes, preserves existing inventory history, and prevents ordinary modification or deletion of audit records.

The implementation must retain Stage 3's atomic order-placement and overselling protection.

## Implementation

Migration: `database/migrations/002_inventory_audit_trail.sql`

### 1. Audit metadata

Extended `inventory_log` with:

- `quantity_before`
- `quantity_after`
- `actor`
- `reference_type`
- `reference_id`

New audit records must contain valid stock balances, a movement quantity, a non-empty reason, a timestamp, a product reference, and an actor.

Historical records retain NULL audit metadata where the original information cannot reliably be reconstructed.

### 2. Automatic inventory auditing

Created `capture_inventory_audit()` and the `products_inventory_audit` trigger.

Every change to an existing product's `stock_quantity` automatically creates an inventory log record containing:

- Product identifier
- Quantity changed
- Previous and resulting stock balances
- Movement reason
- Database session role
- Optional transaction reference
- Timestamp

Unclassified direct stock updates are recorded as `manual_adjustment`.

The stock update and audit insert execute in the same database transaction. If the audit insert fails, the stock update is rolled back.

### 3. Order integration

Replaced `place_order()` to supply transaction-local audit context before updating stock.

The automatic trigger records the sale and links it to the generated order ID. The previous manual inventory log insertion was removed to prevent duplicate audit records.

The conditional stock update remains in place to prevent overselling.

### 4. Append-only protection

Created `prevent_inventory_log_mutation()` and the `inventory_log_append_only` trigger.

Ordinary UPDATE and DELETE operations against inventory log records are rejected. Corrections must be recorded as compensating movements.

### 5. Historical integrity preservation

Added three constraints using `NOT VALID`:

- `inventory_log_balance_check`
- `inventory_log_actor_check`
- `inventory_log_product_fk`

Existing historical exceptions are preserved, while new records are subject to the constraints.

## Test environment

- Database: `kloudkart_test`
- PostgreSQL: 18
- Migration: `002_inventory_audit_trail.sql`
- Production database: Not modified

## Functional test results

| Test | Expected behaviour | Result |
|---|---|---|
| Automatic audit capture | Stock update creates a movement record with correct before/after balances | PASS |
| Default movement reason | Unclassified update receives `manual_adjustment` | PASS |
| Actor identification | Database session role is recorded | PASS |
| Order integration | Successful sale creates one audit record linked to its order | PASS |
| Duplicate prevention | No separate manual audit record is created by `place_order()` | PASS |
| Append-only UPDATE | Existing audit record cannot be updated | PASS |
| Append-only DELETE | Existing audit record cannot be deleted | PASS |
| Overselling protection | Zero-stock sale is rejected | PASS |
| Failed order integrity | No stock change, audit record, or order item is created after rejection | PASS |
| Foreign-key enforcement | New inventory record referencing a nonexistent product is rejected | PASS |

### Automatic audit capture evidence

A transaction reduced product 5001's stock from 90 to 89.

The generated audit record contained:

- `change_qty`: -1
- `reason`: `manual_adjustment`
- `quantity_before`: 90
- `quantity_after`: 89
- `actor`: `kloudkart_test`

The transaction was rolled back after inspection.

### Successful order evidence

A one-unit order was successfully placed in a test transaction.

- Order ID: 659545
- Product ID: 5001
- Movement: -1
- Reason: `sale`
- Before: 90
- After: 89
- Reference type: `order`
- Reference ID: 659545

Exactly one matching audit record was generated. The test transaction was rolled back.

### Overselling rejection evidence

An attempted one-unit sale against a zero-stock product was rejected with:

`Out of stock or product unavailable`

Verified:

- Stock remained unchanged.
- No inventory audit record was created.
- No order item was created.
- The order was not accepted.

### Append-only evidence

Both UPDATE and DELETE attempts were rejected with the expected append-only exception.

### Foreign-key evidence

An attempted inventory log insertion referencing product ID `-999999` was rejected with a foreign-key violation.

## Historical data preservation

The original orphan inventory references were preserved.

| Metric | Result |
|---|---:|
| Orphan inventory records | 120 |
| Distinct missing product IDs | 111 |

The three new constraints remain marked `NOT VALID`:

- `inventory_log_actor_check`
- `inventory_log_balance_check`
- `inventory_log_product_fk`

This is intentional. PostgreSQL enforces these constraints for new or modified rows without requiring existing historical records to pass validation.

## Limitations and trust boundaries

1. `SESSION_USER` identifies the authenticated PostgreSQL role, not necessarily an individual employee.
2. Transaction-local audit settings can be supplied by a database client. Movement reasons and references are therefore not tamper-proof.
3. The append-only trigger blocks ordinary UPDATE and DELETE operations, but privileged database owners or administrators can bypass trigger protections.
4. The trigger audits changes to existing products' stock quantities. It does not independently audit initial stock values supplied when a product is inserted.
5. Historical stock balances, actors, and transaction references cannot reliably be reconstructed from the original data.

## Stage 7 outcome

The migration was successfully applied to the isolated test database.

All listed functional and integrity checks passed. Stage 3's conditional stock reservation remains operational, historical orphan records were preserved, and future stock changes are automatically recorded.

Production deployment has not been performed.
