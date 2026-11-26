-- ============================================================
-- Stage 2: Diagnosis
-- Script: 02_referential_integrity.sql
-- Purpose: Identify records referencing non-existent parent IDs.
-- Database: kloudkart_test
-- Read-only: Yes
-- ============================================================


-- 1. Order items referencing non-existent orders

SELECT
    'order_items -> orders' AS relationship,
    COUNT(*) AS orphan_records,
    COUNT(DISTINCT oi.order_id) AS missing_parent_ids,
    COALESCE(SUM(oi.quantity), 0) AS affected_units,
    COALESCE(SUM(oi.quantity * oi.unit_price), 0) AS affected_value
FROM order_items oi
LEFT JOIN orders o
    ON oi.order_id = o.order_id
WHERE o.order_id IS NULL;


-- 2. Orders referencing non-existent customers

SELECT
    'orders -> customers' AS relationship,
    COUNT(*) AS orphan_records,
    COUNT(DISTINCT o.customer_id) AS missing_parent_ids,
    COALESCE(SUM(o.total_amount), 0) AS affected_order_value
FROM orders o
LEFT JOIN customers c
    ON o.customer_id = c.customer_id
WHERE c.customer_id IS NULL;


-- 3. Inventory movements referencing non-existent products

SELECT
    'inventory_log -> products' AS relationship,
    COUNT(*) AS orphan_records,
    COUNT(DISTINCT il.product_id) AS missing_parent_ids,
    COALESCE(SUM(il.change_qty), 0) AS net_quantity_change
FROM inventory_log il
LEFT JOIN products p
    ON il.product_id = p.product_id
WHERE p.product_id IS NULL;


-- 4. Products referencing non-existent categories

SELECT
    'products -> categories' AS relationship,
    COUNT(*) AS orphan_records,
    COUNT(DISTINCT p.category_id) AS missing_parent_ids
FROM products p
LEFT JOIN categories c
    ON p.category_id = c.category_id
WHERE p.category_id IS NOT NULL
  AND c.category_id IS NULL;


-- ============================================================
-- 5. Inspect orphan order references
-- ============================================================

SELECT
    oi.order_id,
    COUNT(*) AS affected_items,
    SUM(oi.quantity) AS affected_units,
    SUM(oi.quantity * oi.unit_price) AS affected_value
FROM order_items oi
LEFT JOIN orders o
    ON oi.order_id = o.order_id
WHERE o.order_id IS NULL
GROUP BY oi.order_id
ORDER BY affected_value DESC NULLS LAST
LIMIT 20;


-- ============================================================
-- 6. Inspect orphan customer references
-- ============================================================

SELECT
    o.customer_id,
    COUNT(*) AS affected_orders,
    SUM(o.total_amount) AS affected_order_value
FROM orders o
LEFT JOIN customers c
    ON o.customer_id = c.customer_id
WHERE c.customer_id IS NULL
GROUP BY o.customer_id
ORDER BY affected_order_value DESC NULLS LAST
LIMIT 20;


-- ============================================================
-- 7. Inspect orphan inventory product references
-- ============================================================

SELECT
    il.product_id,
    COUNT(*) AS movement_count,
    SUM(il.change_qty) AS net_quantity_change
FROM inventory_log il
LEFT JOIN products p
    ON il.product_id = p.product_id
WHERE p.product_id IS NULL
GROUP BY il.product_id
ORDER BY movement_count DESC
LIMIT 20;