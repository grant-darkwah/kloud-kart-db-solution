-- ============================================================
-- Stage 2: Diagnosis
-- Script: 03_category_hierarchy.sql
-- Purpose: Diagnose category hierarchy integrity.
-- Database: kloudkart_test
-- Read-only: Yes
-- ============================================================


-- 1. Identify root categories

SELECT
    category_id,
    category_name,
    parent_id
FROM categories
WHERE parent_id IS NULL
ORDER BY category_id;


-- 2. Identify categories referencing non-existent parents

SELECT
    child.category_id,
    child.category_name,
    child.parent_id AS missing_parent_id
FROM categories child
LEFT JOIN categories parent
    ON child.parent_id = parent.category_id
WHERE child.parent_id IS NOT NULL
  AND parent.category_id IS NULL
ORDER BY child.category_id;


-- 3. Detect circular relationships using a recursive CTE

WITH RECURSIVE category_paths AS (
    SELECT
        category_id AS start_id,
        category_id AS current_id,
        parent_id,
        ARRAY[category_id] AS path,
        FALSE AS cycle_detected
    FROM categories

    UNION ALL

    SELECT
        cp.start_id,
        parent.category_id,
        parent.parent_id,
        cp.path || parent.category_id,
        parent.category_id = ANY(cp.path)
    FROM category_paths cp
    JOIN categories parent
        ON cp.parent_id = parent.category_id
    WHERE cp.parent_id IS NOT NULL
      AND NOT cp.cycle_detected
)
SELECT DISTINCT
    start_id,
    path AS circular_path
FROM category_paths
WHERE cycle_detected
ORDER BY start_id;


-- 4. Calculate hierarchy depth from root categories

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
)
SELECT
    MAX(depth) AS maximum_reachable_depth,
    COUNT(*) AS root_reachable_categories
FROM category_tree;


-- 5. Identify categories unreachable from root categories

WITH RECURSIVE category_tree AS (
    SELECT
        category_id,
        ARRAY[category_id] AS path
    FROM categories
    WHERE parent_id IS NULL

    UNION ALL

    SELECT
        child.category_id,
        parent.path || child.category_id
    FROM categories child
    JOIN category_tree parent
        ON child.parent_id = parent.category_id
    WHERE NOT child.category_id = ANY(parent.path)
)
SELECT
    c.category_id,
    c.category_name,
    c.parent_id
FROM categories c
WHERE NOT EXISTS (
    SELECT 1
    FROM category_tree ct
    WHERE ct.category_id = c.category_id
)
ORDER BY c.category_id;