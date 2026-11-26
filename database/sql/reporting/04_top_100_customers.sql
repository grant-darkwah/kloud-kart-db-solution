-- ============================================================
-- Stage 4: Monday Report
-- Query 04: Top 100 Customers by Completed Spending
-- ============================================================

WITH completed_orders AS (
    SELECT
        o.order_id,
        o.customer_id,
        o.total_amount
    FROM orders AS o
    JOIN customers AS c
        ON c.customer_id = o.customer_id
    WHERE LOWER(TRIM(o.status)) IN ('completed', 'complete')
      AND o.order_date < CURRENT_DATE + INTERVAL '1 day'
),

customer_spending AS (
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
)

SELECT
    customer_id,
    full_name,
    completed_order_count,
    total_spend,
    ROW_NUMBER() OVER (
        ORDER BY total_spend DESC, customer_id
    ) AS spending_rank
FROM customer_spending
ORDER BY spending_rank
LIMIT 100;