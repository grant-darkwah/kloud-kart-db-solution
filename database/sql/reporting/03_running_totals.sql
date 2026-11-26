-- ============================================================
-- Stage 4: Monday Report
-- Query 03: Running Cumulative Spend per Customer
-- ============================================================

WITH reporting_period AS (
    SELECT
        DATE_TRUNC('month', CURRENT_DATE) - INTERVAL '11 months'
            AS start_date,
        CURRENT_DATE + INTERVAL '1 day' AS end_date
),

completed_orders AS (
    SELECT
        o.order_id,
        o.customer_id,
        o.order_date,
        o.total_amount
    FROM orders AS o
    JOIN customers AS c
        ON c.customer_id = o.customer_id
    CROSS JOIN reporting_period AS rp
    WHERE LOWER(TRIM(o.status)) IN ('completed', 'complete')
      AND o.order_date >= rp.start_date
      AND o.order_date < rp.end_date
)

SELECT
    c.customer_id,
    c.full_name,
    o.order_id,
    o.order_date,
    o.total_amount,
    SUM(o.total_amount) OVER (
        PARTITION BY c.customer_id
        ORDER BY o.order_date, o.order_id
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    )::numeric(14,2) AS running_total_spend
FROM completed_orders AS o
JOIN customers AS c
    ON c.customer_id = o.customer_id
ORDER BY
    c.customer_id,
    o.order_date,
    o.order_id;