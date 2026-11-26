-- ============================================================
-- Stage 2: Diagnosis
-- Script: 04_inventory_consistency.sql
-- Purpose: Investigate inventory consistency and stock accuracy.
-- Database: kloudkart_test
-- Read-only: Yes
-- ============================================================


-- 1. Identify products with negative stock quantities

SELECT
    product_id,
    product_name,
    stock_quantity,
    price
FROM products
WHERE stock_quantity < 0
ORDER BY stock_quantity ASC;


-- 2. Quantify negative stock

SELECT
    COUNT(*) AS products_with_negative_stock,
    SUM(ABS(stock_quantity)) AS total_units_below_zero,
    SUM(ABS(stock_quantity) * price) AS associated_product_value
FROM products
WHERE stock_quantity < 0;


-- 3. Calculate net inventory movement per product

WITH movement_totals AS (
    SELECT
        product_id,
        SUM(change_qty) AS net_movement
    FROM inventory_log
    WHERE product_id IS NOT NULL
    GROUP BY product_id
)
SELECT
    p.product_id,
    p.product_name,
    p.stock_quantity,
    COALESCE(mt.net_movement, 0) AS net_movement,
    p.stock_quantity - COALESCE(mt.net_movement, 0) AS difference
FROM products p
LEFT JOIN movement_totals mt
    ON p.product_id = mt.product_id
WHERE p.stock_quantity <> COALESCE(mt.net_movement, 0)
ORDER BY ABS(
    p.stock_quantity - COALESCE(mt.net_movement, 0)
) DESC
LIMIT 30;


-- 4. Quantify stock-to-movement discrepancies

WITH movement_totals AS (
    SELECT
        product_id,
        SUM(change_qty) AS net_movement
    FROM inventory_log
    WHERE product_id IS NOT NULL
    GROUP BY product_id
),
stock_comparison AS (
    SELECT
        p.product_id,
        p.stock_quantity,
        COALESCE(mt.net_movement, 0) AS net_movement
    FROM products p
    LEFT JOIN movement_totals mt
        ON p.product_id = mt.product_id
)
SELECT
    COUNT(*) FILTER (
        WHERE stock_quantity <> net_movement
    ) AS products_with_discrepancies,
    SUM(
        ABS(stock_quantity - net_movement)
    ) FILTER (
        WHERE stock_quantity <> net_movement
    ) AS total_absolute_difference
FROM stock_comparison;


-- 5. Examine inventory movement reasons

SELECT
    reason,
    COUNT(*) AS movement_count,
    SUM(change_qty) AS net_quantity_change,
    COUNT(*) FILTER (WHERE change_qty > 0) AS positive_movements,
    COUNT(*) FILTER (WHERE change_qty < 0) AS negative_movements,
    COUNT(*) FILTER (WHERE change_qty = 0) AS zero_movements
FROM inventory_log
GROUP BY reason
ORDER BY movement_count DESC;


-- 6. Identify unusual inventory movement quantities

SELECT
    log_id,
    product_id,
    change_qty,
    reason,
    created_at
FROM inventory_log
WHERE ABS(change_qty) >= 100
ORDER BY ABS(change_qty) DESC
LIMIT 30;

-- 7. Inspect stock-take records

SELECT
    log_id,
    product_id,
    change_qty,
    reason,
    created_at,
    note
FROM inventory_log
WHERE reason = 'stock_take'
ORDER BY created_at
LIMIT 30;


-- 8. Inspect correction records

SELECT
    log_id,
    product_id,
    change_qty,
    reason,
    created_at,
    note
FROM inventory_log
WHERE reason = 'correction'
ORDER BY created_at
LIMIT 30;