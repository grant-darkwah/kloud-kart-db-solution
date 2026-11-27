# Stage 3: Stop the Overselling

## Objective

Prevent concurrent customers from purchasing more stock than is available while ensuring every successful purchase creates an order and an inventory movement.

## Implementation

Created `database/migrations/001_prevent_overselling.sql`.

The migration:
- Creates dedicated sequences for order, order item, and inventory log IDs.
- Initialises sequences above existing maximum IDs.
- Creates the `place_order` PostgreSQL function.
- Uses a conditional stock update to reserve inventory atomically.
- Creates the order, order item, and inventory movement within the same transaction.

If sufficient stock is unavailable, the function returns `success = false`, a NULL order ID, and an out-of-stock message.

## Concurrency Strategy

The function uses a conditional `UPDATE`:

- PostgreSQL acquires a row-level lock on the product being updated.
- Concurrent transactions attempting to update the same product wait for the lock.
- The stock condition is re-evaluated after the lock becomes available.
- Only transactions with sufficient remaining stock can decrement the quantity.

This prevents two customers from purchasing the same final unit.

## Test Results

The instructor-supplied `provided_resources/race_test.py` was executed without modification.

| Test | Expected behaviour | Result |
|---|---|---|
| Two buyers, one unit (25 rounds) | Exactly one successful purchase per round | Passed |
| Flash sale (400 buyers, 50 units) | Exactly 50 successful purchases | Passed |
| Oversell attempt | Refuse purchase without changing stock | Passed |
| Audit trail | Every successful purchase creates a movement | Passed |

### Final concurrency results

- 25/25 last-unit rounds passed.
- 400 concurrent attempts: 50 successful, 350 refused.
- Flash-sale execution time: 8.01 seconds.
- Zero errors during the flash sale.
- Overselling prevented.
- All successful purchases recorded in `inventory_log`.

## Conclusion

The implementation passed all four instructor-supplied tests.

The database now prevents overselling under concurrent purchases and records successful sales in the inventory movement log.

The migration was applied and tested against the isolated test database.