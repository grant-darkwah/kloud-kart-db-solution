-- ============================================================
-- Stage 4: Monday Report
-- Query 01: Customer Spending Summary
-- ============================================================

WITH completed_orders AS (
    SELECT
        order_id,
        customer_id,
        total_amount
    FROM orders
    WHERE LOWER(TRIM(status)) IN ('completed', 'complete')
      AND order_date < CURRENT_DATE + INTERVAL '1 day'
)

SELECT
    c.customer_id,
    c.full_name,
    COUNT(o.order_id) AS completed_order_count,
    COALESCE(SUM(o.total_amount), 0)::numeric(14,2) AS total_spend
FROM customers AS c
LEFT JOIN completed_orders AS o
    ON c.customer_id = o.customer_id
GROUP BY
    c.customer_id,
    c.full_name
ORDER BY
    total_spend DESC,
    c.customer_id;