-- ============================================================
-- Stage 4: Monday Report
-- Query 02: Monthly Customer Spending
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
    CROSS JOIN reporting_period AS rp
    WHERE LOWER(TRIM(o.status)) IN ('completed', 'complete')
      AND o.order_date >= rp.start_date
      AND o.order_date < rp.end_date
)

SELECT
    c.customer_id,
    c.full_name,
    DATE_TRUNC('month', o.order_date)::date AS spend_month,
    COUNT(o.order_id) AS completed_order_count,
    SUM(o.total_amount)::numeric(14,2) AS monthly_spend
FROM completed_orders AS o
JOIN customers AS c
    ON c.customer_id = o.customer_id
GROUP BY
    c.customer_id,
    c.full_name,
    DATE_TRUNC('month', o.order_date)
ORDER BY
    c.customer_id,
    spend_month;