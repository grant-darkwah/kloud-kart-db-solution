-- ============================================================
-- Stage 2: Diagnosis
-- Script: 01_data_completeness.sql
-- Purpose: Identify missing values in important business columns.
-- Database: kloudkart_test
-- Read-only: Yes
-- ============================================================

-- 1. Categories
SELECT
    'categories' AS table_name,
    COUNT(*) AS total_rows,
    COUNT(*) FILTER (WHERE category_name IS NULL) AS null_category_name,
    COUNT(*) FILTER (WHERE parent_id IS NULL) AS null_parent_id
FROM categories;

-- 2. Products
SELECT
    'products' AS table_name,
    COUNT(*) AS total_rows,
    COUNT(*) FILTER (WHERE product_name IS NULL) AS null_product_name,
    COUNT(*) FILTER (WHERE category_id IS NULL) AS null_category_id,
    COUNT(*) FILTER (WHERE price IS NULL) AS null_price,
    COUNT(*) FILTER (WHERE stock_quantity IS NULL) AS null_stock_quantity,
    COUNT(*) FILTER (WHERE created_at IS NULL) AS null_created_at
FROM products;

-- 3. Customers
SELECT
    'customers' AS table_name,
    COUNT(*) AS total_rows,
    COUNT(*) FILTER (WHERE email IS NULL) AS null_email,
    COUNT(*) FILTER (WHERE phone IS NULL) AS null_phone
FROM customers;

-- 4. Orders
SELECT
    'orders' AS table_name,
    COUNT(*) AS total_rows,
    COUNT(*) FILTER (WHERE customer_id IS NULL) AS null_customer_id,
    COUNT(*) FILTER (WHERE order_date IS NULL) AS null_order_date,
    COUNT(*) FILTER (WHERE status IS NULL) AS null_status,
    COUNT(*) FILTER (WHERE total_amount IS NULL) AS null_total_amount
FROM orders;

-- 5. Order items
SELECT
    'order_items' AS table_name,
    COUNT(*) AS total_rows,
    COUNT(*) FILTER (WHERE order_id IS NULL) AS null_order_id,
    COUNT(*) FILTER (WHERE product_id IS NULL) AS null_product_id,
    COUNT(*) FILTER (WHERE quantity IS NULL) AS null_quantity,
    COUNT(*) FILTER (WHERE unit_price IS NULL) AS null_unit_price
FROM order_items;

-- 6. Inventory log
SELECT
    'inventory_log' AS table_name,
    COUNT(*) AS total_rows,
    COUNT(*) FILTER (WHERE product_id IS NULL) AS null_product_id,
    COUNT(*) FILTER (WHERE change_qty IS NULL) AS null_change_qty,
    COUNT(*) FILTER (WHERE reason IS NULL) AS null_reason,
    COUNT(*) FILTER (WHERE created_at IS NULL) AS null_created_at,
    COUNT(*) FILTER (WHERE note IS NULL) AS null_note
FROM inventory_log;


-- 7. NULL percentage for important business columns

SELECT
    'products' AS table_name,
    'category_id' AS column_name,
    COUNT(*) FILTER (WHERE category_id IS NULL) AS null_rows,
    ROUND(
        100.0 * COUNT(*) FILTER (WHERE category_id IS NULL)
        / COUNT(*),
        4
    ) AS null_percentage
FROM products

UNION ALL

SELECT
    'order_items',
    'unit_price',
    COUNT(*) FILTER (WHERE unit_price IS NULL),
    ROUND(
        100.0 * COUNT(*) FILTER (WHERE unit_price IS NULL)
        / COUNT(*),
        4
    )
FROM order_items

UNION ALL

SELECT
    'inventory_log',
    'note',
    COUNT(*) FILTER (WHERE note IS NULL),
    ROUND(
        100.0 * COUNT(*) FILTER (WHERE note IS NULL)
        / COUNT(*),
        4
    )
FROM inventory_log;


-- 8. Inspect products without category assignments

SELECT
    product_id,
    product_name,
    price,
    stock_quantity
FROM products
WHERE category_id IS NULL
ORDER BY product_id
LIMIT 20;


-- 9. Inspect order items without unit prices

SELECT
    order_item_id,
    order_id,
    product_id,
    quantity,
    unit_price
FROM order_items
WHERE unit_price IS NULL
ORDER BY order_item_id
LIMIT 20;


-- 10. Inspect inventory log reason distribution

SELECT
    reason,
    COUNT(*) AS record_count,
    COUNT(*) FILTER (WHERE note IS NULL) AS missing_notes
FROM inventory_log
GROUP BY reason
ORDER BY record_count DESC;