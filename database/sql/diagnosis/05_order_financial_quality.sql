-- ============================================================
-- Stage 2: Diagnosis
-- Script: 05_order_financial_quality.sql
-- Purpose: Investigate order and financial data quality.
-- Database: kloudkart_test
-- Read-only: Yes
-- ============================================================


-- 1. Identify order items with missing unit prices

SELECT
    COUNT(*) AS missing_price_items,
    SUM(quantity) AS affected_units,
    COUNT(DISTINCT order_id) AS affected_orders
FROM order_items
WHERE unit_price IS NULL;


-- 2. Identify zero-priced order items

SELECT
    COUNT(*) AS zero_price_items,
    SUM(quantity) AS affected_units,
    COUNT(DISTINCT order_id) AS affected_orders
FROM order_items
WHERE unit_price = 0;


-- 3. Inspect missing and zero-priced order items

SELECT
    order_item_id,
    order_id,
    product_id,
    quantity,
    unit_price
FROM order_items
WHERE unit_price IS NULL
   OR unit_price = 0
ORDER BY order_id, order_item_id
LIMIT 30;


-- 4. Compare order totals with calculated item totals

WITH item_totals AS (
    SELECT
        order_id,
        SUM(quantity * unit_price) AS calculated_total,
        COUNT(*) FILTER (
            WHERE unit_price IS NULL
        ) AS missing_price_items
    FROM order_items
    GROUP BY order_id
)
SELECT
    COUNT(*) AS fully_priced_orders,
    COUNT(*) FILTER (
        WHERE o.total_amount <> it.calculated_total
    ) AS mismatched_orders,
    SUM(
        ABS(o.total_amount - it.calculated_total)
    ) FILTER (
        WHERE o.total_amount <> it.calculated_total
    ) AS total_absolute_difference
FROM orders o
JOIN item_totals it
    ON o.order_id = it.order_id
WHERE it.missing_price_items = 0;


-- 5. Identify orders containing missing unit prices

SELECT
    COUNT(DISTINCT order_id) AS orders_with_missing_prices
FROM order_items
WHERE unit_price IS NULL;


-- 6. Identify unusually large order quantities

SELECT
    COUNT(*) AS large_quantity_items,
    MAX(quantity) AS maximum_quantity,
    SUM(quantity) AS total_units_in_large_items
FROM order_items
WHERE quantity >= 100;


-- 7. Inspect the largest order quantities

SELECT
    order_item_id,
    order_id,
    product_id,
    quantity,
    unit_price
FROM order_items
WHERE quantity >= 100
ORDER BY quantity DESC
LIMIT 30;


-- 8. Identify repeated order/product/quantity/price combinations

SELECT
    order_id,
    product_id,
    quantity,
    unit_price,
    COUNT(*) AS occurrences
FROM order_items
GROUP BY
    order_id,
    product_id,
    quantity,
    unit_price
HAVING COUNT(*) > 1
ORDER BY occurrences DESC, order_id
LIMIT 30;


-- 9. Quantify repeated combinations

WITH repeated_groups AS (
    SELECT
        COUNT(*) AS occurrences
    FROM order_items
    GROUP BY
        order_id,
        product_id,
        quantity,
        unit_price
    HAVING COUNT(*) > 1
)
SELECT
    COUNT(*) AS repeated_groups,
    SUM(occurrences) AS records_in_repeated_groups,
    SUM(occurrences - 1) AS excess_records
FROM repeated_groups;