# Stage 1 - Load and Look: Baseline Evidence

## 1. Database Environment

| Property | Value |
|---|---|
| PostgreSQL version | 18.7 |
| Test database | `kloudkart_test` |
| Test database user | `kloudkart_test` |
| Production database | `kloudkart_prod` |
| Production database user | `kloudkart_admin` |
| `max_connections` (test) | 500 |
| `max_connections` (production) | 500 |

## 2. Dataset Baseline

The assessment dataset was successfully loaded into the test database.

| Table | Row count |
|---|---:|
| categories | 94 |
| products | 4,023 |
| customers | 40,420 |
| orders | 159,384 |
| order_items | 336,559 |
| inventory_log | 282,352 |
| **Total** | **822,832** |

## 3. Initial Schema Observations

Inspection of the six tables established the following:

- Each table has a primary key.
- No foreign-key constraints were present.
- No secondary indexes were present.
- Only the primary-key columns were defined as `NOT NULL`.
- The remaining columns were nullable.
- No default values were defined on the inspected columns.

## 4. Initial Assessment

- All six expected tables exist in the `public` schema.
- The dataset contains 822,832 records.
- Both PostgreSQL environments use the required `max_connections` setting of 500.
- The test database is populated; the production database remains separate.

**Scope:** This document records the initial environment, dataset size, and observed schema structure. Data-quality diagnosis and performance analysis belong to subsequent assessment stages.