
-- ============================================================
-- Stage 5: Roll Up the Category Tree
-- Script: 01_low_stock_category_rollup.sql
-- Purpose: Aggregate low-stock products through the category
--          hierarchy without hard-coding hierarchy depth.
-- Database: kloudkart_test
-- Read-only: Yes
--
-- Business rule:
--   Low stock = stock_quantity BETWEEN 1 AND 10.
--
-- Stock classifications:
--   Negative stock = Inventory anomaly
--   Zero stock     = Out of stock
--   1-10 units     = Low stock
--   Above 10       = Adequately stocked
--
-- Hierarchy handling:
--   Valid categories = Included in recursive rollup.
--   Orphan categories = Reported separately.
--   Cyclic categories = Reported separately.
--   Unassigned products = Reported separately.
--
-- Important:
--   No changes are made to the supplied database schema.
--   No inventory records are modified.
-- ============================================================


-- ============================================================
-- 1. Build the valid category hierarchy
-- ============================================================

WITH RECURSIVE category_tree AS (

    SELECT
        category_id,
        category_name,
        parent_id,
        0 AS depth,
        ARRAY[category_id] AS path
    FROM categories
    WHERE parent_id IS NULL

    UNION ALL

    SELECT
        child.category_id,
        child.category_name,
        child.parent_id,
        parent.depth + 1,
        parent.path || child.category_id
    FROM categories child
    JOIN category_tree parent
        ON child.parent_id = parent.category_id
    WHERE NOT child.category_id = ANY(parent.path)
),

-- ============================================================
-- 2. Identify low-stock products
-- ============================================================

low_stock_products AS (
    SELECT
        product_id,
        product_name,
        category_id,
        stock_quantity
    FROM products
    WHERE stock_quantity BETWEEN 1 AND 10
),

-- ============================================================
-- 3. Map each category to its ancestors
-- ============================================================

category_ancestors AS (
    SELECT
        descendant.category_id AS descendant_id,
        ancestor.category_id AS ancestor_id
    FROM category_tree descendant
    CROSS JOIN LATERAL
        UNNEST(descendant.path) AS path_ids(ancestor_id)
    JOIN categories ancestor
        ON ancestor.category_id = path_ids.ancestor_id
),

-- ============================================================
-- 4. Roll up low-stock products through all ancestors
-- ============================================================

category_rollup AS (
    SELECT
        ct.category_id,
        ct.category_name,
        ct.parent_id,
        ct.depth,
        COUNT(lsp.product_id) AS low_stock_products,
        COALESCE(SUM(lsp.stock_quantity), 0) AS low_stock_units
    FROM category_tree ct
    LEFT JOIN category_ancestors ca
        ON ca.ancestor_id = ct.category_id
    LEFT JOIN low_stock_products lsp
        ON lsp.category_id = ca.descendant_id
    GROUP BY
        ct.category_id,
        ct.category_name,
        ct.parent_id,
        ct.depth
),

-- ============================================================
-- 5. Detect circular category relationships
-- ============================================================

cycle_walk AS (
    SELECT
        category_id AS start_id,
        category_id AS current_id,
        parent_id,
        ARRAY[category_id] AS path,
        NULL::integer AS cycle_entry_id
    FROM categories

    UNION ALL

    SELECT
        cw.start_id,
        parent.category_id,
        parent.parent_id,
        cw.path || parent.category_id,
        CASE
            WHEN parent.category_id = ANY(cw.path)
                THEN parent.category_id
            ELSE NULL
        END
    FROM cycle_walk cw
    JOIN categories parent
        ON cw.parent_id = parent.category_id
    WHERE cw.parent_id IS NOT NULL
      AND cw.cycle_entry_id IS NULL
),

-- ============================================================
-- 6. Identify the actual members of each cycle
-- ============================================================

cycle_members AS (
    SELECT DISTINCT
        cycle_member.category_id
    FROM cycle_walk cw
    CROSS JOIN LATERAL UNNEST(
        cw.path[
            ARRAY_POSITION(cw.path, cw.cycle_entry_id):
            CARDINALITY(cw.path) - 1
        ]
    ) AS cycle_member(category_id)
    WHERE cw.cycle_entry_id IS NOT NULL
),

-- ============================================================
-- 7. Classify hierarchy exceptions
-- ============================================================

hierarchy_exceptions AS (
    SELECT
        c.category_id,
        c.category_name,
        c.parent_id,
        CASE
            WHEN parent.category_id IS NULL
                 AND c.parent_id IS NOT NULL
                THEN 'orphan_category'

            WHEN cm.category_id IS NOT NULL
                THEN 'cyclic_category'

            ELSE 'unreachable_category'
        END AS exception_type
    FROM categories c
    LEFT JOIN categories parent
        ON parent.category_id = c.parent_id
    LEFT JOIN cycle_members cm
        ON cm.category_id = c.category_id
    WHERE NOT EXISTS (
        SELECT 1
        FROM category_tree ct
        WHERE ct.category_id = c.category_id
    )
),

-- ============================================================
-- 8. Report inventory associated with hierarchy exceptions
-- ============================================================

exception_inventory AS (
    SELECT
        he.category_id,
        he.category_name,
        he.parent_id,
        he.exception_type,
        COUNT(p.product_id) AS total_products,
        COUNT(p.product_id) FILTER (
            WHERE p.stock_quantity BETWEEN 1 AND 10
        ) AS low_stock_products,
        COALESCE(
            SUM(p.stock_quantity) FILTER (
                WHERE p.stock_quantity BETWEEN 1 AND 10
            ), 0
        ) AS low_stock_units
    FROM hierarchy_exceptions he
    LEFT JOIN products p
        ON p.category_id = he.category_id
    GROUP BY
        he.category_id,
        he.category_name,
        he.parent_id,
        he.exception_type
),

-- ============================================================
-- 9. Report products without category assignments
-- ============================================================

unassigned_inventory AS (
    SELECT
        COUNT(*) AS total_products,
        COUNT(*) FILTER (
            WHERE stock_quantity BETWEEN 1 AND 10
        ) AS low_stock_products,
        COALESCE(
            SUM(stock_quantity) FILTER (
                WHERE stock_quantity BETWEEN 1 AND 10
            ), 0
        ) AS low_stock_units
    FROM products
    WHERE category_id IS NULL
),

-- ============================================================
-- 10. Validate the root-category totals
-- ============================================================

rollup_validation AS (
    SELECT
        COUNT(*) AS categories_in_rollup,
        COALESCE(
            SUM(low_stock_products) FILTER (
                WHERE parent_id IS NULL
            ), 0
        ) AS root_low_stock_products,
        COALESCE(
            SUM(low_stock_units) FILTER (
                WHERE parent_id IS NULL
            ), 0
        ) AS root_low_stock_units
    FROM category_rollup
)

-- ============================================================
-- 11. Produce the complete category and exception report
-- ============================================================

SELECT
    'category_rollup' AS report_section,
    cr.category_id,
    cr.category_name,
    cr.parent_id,
    cr.depth,
    NULL::text AS exception_type,
    NULL::bigint AS total_products,
    cr.low_stock_products,
    cr.low_stock_units,
    NULL::bigint AS categories_in_rollup
FROM category_rollup cr

UNION ALL

SELECT
    'hierarchy_exception',
    ei.category_id,
    ei.category_name,
    ei.parent_id,
    NULL::integer,
    ei.exception_type,
    ei.total_products,
    ei.low_stock_products,
    ei.low_stock_units,
    NULL::bigint
FROM exception_inventory ei

UNION ALL

SELECT
    'unassigned_inventory',
    NULL::integer,
    'Products without category assignment',
    NULL::integer,
    NULL::integer,
    'unassigned_products',
    ui.total_products,
    ui.low_stock_products,
    ui.low_stock_units,
    NULL::bigint
FROM unassigned_inventory ui

UNION ALL

SELECT
    'rollup_validation',
    NULL::integer,
    'Root-category reconciliation',
    NULL::integer,
    NULL::integer,
    'root_totals',
    NULL::bigint,
    rv.root_low_stock_products,
    rv.root_low_stock_units,
    rv.categories_in_rollup
FROM rollup_validation rv

ORDER BY
    report_section,
    category_id NULLS LAST;
