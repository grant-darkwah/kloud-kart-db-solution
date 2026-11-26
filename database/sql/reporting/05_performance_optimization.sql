
/*
===============================================================================
KLOUD KART LTD. — STAGE 4: MONDAY REPORT PERFORMANCE OPTIMISATION
===============================================================================

Purpose:
    Document and reproduce the PostgreSQL performance optimisation techniques
    evaluated while building the Monday customer spending reports.

Business objective:
    Produce customer spending reports, monthly spending summaries, running
    totals and top-100 customer rankings within seconds on an ordinary computer.

Optimisations investigated:
    1. Query profiling using EXPLAIN (ANALYZE, BUFFERS).
    2. Expression statistics for normalised order statuses.
    3. Refreshing PostgreSQL planner statistics using ANALYZE.
    4. Session-level memory tuning using work_mem.

IMPORTANT:
    Run this script against the intended database.

    The expression statistics are persistent database objects.
    ANALYZE refreshes planner statistics.
    SET work_mem changes memory configuration only for the current session.

    No business records are inserted, updated or deleted by these commands.
===============================================================================
*/


/*
-------------------------------------------------------------------------------
1. EXPRESSION STATISTICS FOR NORMALISED ORDER STATUS
-------------------------------------------------------------------------------

Problem identified:
    The orders table contains inconsistent status values, including:

        completed
        Completed
        COMPLETED
         completed
        complete

    These values represent two logical completed-order statuses but are stored
    as different raw text values.

    The reporting queries normalise these values using:

        LOWER(TRIM(status))

    LOWER() converts text to lowercase.
    TRIM() removes leading and trailing whitespace.

Why this matters:
    PostgreSQL uses statistics to estimate how many rows a query will return.
    These estimates help the query planner choose an execution strategy.

    Ordinary column statistics describe the stored status values. They do not
    necessarily describe the distribution of a transformed expression such as
    LOWER(TRIM(status)).

Solution:
    Create expression statistics for the exact expression used in the
    reporting filter.

Expected benefit:
    Give the query planner better information when estimating the number of
    orders matching the normalised completed statuses.

Observed result:
    Before creating expression statistics:
        Estimated qualifying orders: 1,582
        Actual qualifying orders:    111,339

    After creating expression statistics and refreshing statistics:
        Estimated qualifying orders: 109,909
        Actual qualifying orders:    111,339

    The estimate improved substantially.

Note:
    CREATE STATISTICS does not create an index and does not change table data.
*/

CREATE STATISTICS IF NOT EXISTS orders_normalized_status_stats
ON (LOWER(TRIM(status)))
FROM orders;


/*
-------------------------------------------------------------------------------
2. REFRESH TABLE AND EXPRESSION STATISTICS
-------------------------------------------------------------------------------

Command:
    ANALYZE orders;

Purpose:
    ANALYZE collects statistics about the contents of a table and makes them
    available to the PostgreSQL query planner.

Why it is necessary:
    The planner relies on statistics to estimate row counts and choose
    execution plans.

    After creating expression statistics, ANALYZE must be run so PostgreSQL
    can collect statistics for the new expression.

Effect:
    - Refreshes planner statistics for the orders table.
    - Updates the information used for query planning.
    - Does not modify business records.
    - Does not create an index.

Important distinction:
    ANALYZE improves the information available to the planner. It does not
    guarantee that every query will execute faster.

Observed result:
    The estimated number of qualifying orders changed from 1,582 to 109,909,
    much closer to the actual count of 111,339.
*/

ANALYZE orders;


/*
-------------------------------------------------------------------------------
3. SESSION-LEVEL MEMORY TUNING
-------------------------------------------------------------------------------

Command:
    SET work_mem = '32MB';

Problem identified:
    The original customer spending query used an external sort.

    An external sort means PostgreSQL could not complete the sort entirely
    in memory and had to use temporary disk storage.

    A later execution plan also showed hash aggregation using multiple batches
    and writing intermediate data to disk.

Why this matters:
    Disk-based intermediate operations can increase query execution time.

Solution:
    Increase work_mem for the current database session to 32 MB.

What work_mem controls:
    It is the approximate amount of memory available to an individual
    sort or hash operation before PostgreSQL resorts to temporary disk storage.

Important:
    work_mem is not a global memory limit for the entire query or database.

    A query can contain multiple memory-consuming operations, and concurrent
    sessions can each use memory.

    Therefore, increasing work_mem globally without considering workload
    concurrency can increase overall memory consumption.

Observed result:

    Before increasing work_mem:
        Hash aggregate batches: 5
        Disk usage:             3,432 KB
        Execution time:         743.846 ms

    After increasing work_mem:
        Hash aggregate batches: 1
        Disk usage:             None
        Execution time:         557.974 ms

    Execution time improved by approximately 25%.

Note:
    The observed improvement applies to the tested customer spending query.
    It should not be interpreted as a guarantee for every query or workload.
*/

SET work_mem = '32MB';


/*
-------------------------------------------------------------------------------
4. QUERY PERFORMANCE PROFILING
-------------------------------------------------------------------------------

Command:
    EXPLAIN (ANALYZE, BUFFERS)

Purpose:
    Inspect how PostgreSQL executes a query and identify potential performance
    bottlenecks.

EXPLAIN:
    Displays the execution plan selected by PostgreSQL.

ANALYZE:
    Executes the query and reports actual execution statistics, including
    actual row counts and execution time.

BUFFERS:
    Reports database buffer activity, including shared buffers and temporary
    blocks read or written.

Important execution-plan information:

    1. Estimated rows:
       Number of rows PostgreSQL expects an operation to process.

    2. Actual rows:
       Number of rows the operation actually processes.

    3. Execution time:
       Time PostgreSQL took to execute the query.

    4. Sequential Scan:
       Reads table pages sequentially. This can be efficient when a large
       proportion of a table qualifies.

    5. Hash Join:
       Uses a hash table to match rows between relations.

    6. HashAggregate:
       Groups rows using a hash-based aggregation strategy.

    7. Sort Method:
       Shows whether sorting was performed in memory or using disk.

    8. Temporary buffers:
       Help identify intermediate operations that use temporary storage.

Usage:
    Apply EXPLAIN (ANALYZE, BUFFERS) to each reporting query to compare
    estimated and actual execution behaviour.

Example: Customer spending summary.
*/

EXPLAIN (ANALYZE, BUFFERS)
SELECT
    c.customer_id,
    c.full_name,
    COUNT(o.order_id) AS completed_order_count,
    COALESCE(SUM(o.total_amount), 0)::numeric(14,2) AS total_spend
FROM customers AS c
LEFT JOIN orders AS o
    ON c.customer_id = o.customer_id
   AND LOWER(TRIM(o.status)) IN ('completed', 'complete')
   AND o.order_date < CURRENT_DATE + INTERVAL '1 day'
GROUP BY
    c.customer_id,
    c.full_name
ORDER BY
    total_spend DESC,
    c.customer_id;


/*
-------------------------------------------------------------------------------
5. INDEXING DECISION
-------------------------------------------------------------------------------

No additional indexes were introduced solely to optimise the tested
reporting queries.

Reason:
    The execution plans showed PostgreSQL using sequential scans and hash
    joins for the qualifying orders and customer records.

    A substantial proportion of orders qualified for the completed-order
    reports. Reading the table sequentially was a reasonable strategy for
    this workload.

Engineering decision:
    Indexes should be introduced when execution-plan evidence demonstrates
    that they are beneficial.

    Indexes also introduce storage requirements and additional work when
    records are inserted, updated or deleted.

    Avoid adding indexes without measuring their impact.
*/


/*
-------------------------------------------------------------------------------
6. STAGE 4 BENCHMARK RESULTS
-------------------------------------------------------------------------------

Test environment:
    Database:       kloudkart-test
    PostgreSQL:     Version 18
    Dataset:        822,832 total rows
    work_mem:       32 MB
    Measurement:    EXPLAIN (ANALYZE, BUFFERS)

Observed execution times:

    Customer spending summary:       557.974 ms
    Monthly customer spending:       638.416 ms
    Running customer spending:       606.084 ms
    Top 100 customers:               499.292 ms

Conclusion:
    All four reporting queries completed in under one second in the tested
    environment.

    Expression statistics improved the planner's row estimates.
    Session-level memory tuning eliminated the observed hash aggregation
    disk spill in the customer spending benchmark.

    Performance was measured rather than assumed.

IMPORTANT:
    These are observed test-environment results. Actual performance can vary
    with hardware, database activity, cache state and concurrent workloads.
===============================================================================
*/
