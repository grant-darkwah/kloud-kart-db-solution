# Kloud Kart DB Solution

**A PostgreSQL-based inventory management and analytics solution for Kloud Kart Ltd.**

> SQL for Data Professionals — AmaliTech Assessment

---

## 1. Project Overview

Kloud Kart Ltd. is an e-commerce business operating in Accra, Ghana, processing approximately 4,000 orders daily.

Its existing PostgreSQL database supports significant business operations but lacks important data integrity controls, inventory concurrency protection, optimized reporting capabilities, and a reliable inventory audit trail.

The purpose of this project is to investigate the existing database, identify its operational risks, and implement tested SQL and application-level solutions to address the business requirements.

The solution will use the existing PostgreSQL environment rather than introduce an entirely new database platform.

## 2. Business Requirements

The solution addresses four requirements identified by Nana Adjei.

### 2.1 Prevent Inventory Overselling

Prevent two customers from purchasing the last available unit simultaneously.

The expected behaviour is:

- Exactly one purchase succeeds.
- The competing purchase receives a clear `out of stock` response.
- Inventory never becomes negative through the implemented purchase operation.
- Concurrent purchases are handled safely using PostgreSQL transaction controls.

### 2.2 Build a Fast Monday Report

Generate a customer spending report containing:

- Total customer spending.
- Number of orders per customer.
- Monthly spending over the trailing 12 months.
- Running cumulative spending per customer.
- A ranking of the top 100 customers.

The report should execute within seconds on an ordinary laptop.

### 2.3 Implement Recursive Low-Stock Visibility

Provide visibility into low-stock products across a hierarchical product category structure.

The implementation must:

- Support nested categories.
- Avoid hard-coded hierarchy depth.
- Aggregate low-stock information through parent categories.
- Handle malformed hierarchy relationships safely.
- Avoid double-counting inventory.

### 2.4 Implement an Inventory Audit Trail

Maintain a record of inventory movements, including:

- Sales.
- Restocks.
- Stock corrections.

Each movement should retain sufficient information to establish what happened, when it happened, and why the inventory changed.

---

## 3. Technology Stack

| Technology | Purpose |
|---|---|
| PostgreSQL 18 | Relational database and transaction processing |
| Docker | Database containerization |
| Docker Compose | Environment orchestration |
| Python | Application logic and automated testing |
| Streamlit | Business operations dashboard |
| SQL | Data integrity, reporting and database operations |
| Git and GitHub | Version control and project collaboration |

---

## 4. Architecture

The project will use separate PostgreSQL environments for testing and production.

| Environment | Container | Host Port | Database |
|---|---|---:|---|
| Production | `kloudkart-prod` | `5432` | `kloudkart_prod` |
| Testing | `kloudkart-test` | `5433` | `kloudkart_test` |

Each environment has its own database credentials and persistent Docker volume.

The intended application architecture consists of:

1. PostgreSQL database layer.
2. Python application and business logic.
3. Streamlit operations dashboard.
4. Automated testing and performance measurement.

The testing environment will be used for destructive operations, concurrency testing, experiments and validation. Production will remain isolated from those activities.

---

## 5. Assessment Roadmap

Implementation follows the eight stages of the assessment.

| Stage | Description |
|---|---|
| 01 | Load and Look |
| 02 | Diagnose |
| 03 | Stop the Overselling |
| 04 | Build the Monday Report |
| 05 | Roll Up the Category Tree |
| 06 | Make It Fast, and Prove It |
| 07 | Leave the Trail |
| 08 | Write It Up |

Each stage will produce documented implementation work and supporting evidence.

---

## 6. Streamlit Operations Dashboard

A Streamlit dashboard will provide a business-facing interface for the completed database capabilities.

The planned dashboard sections are:

| Dashboard Section | Business Capability |
|---|---|
| Monday Report | Customer spending, order counts, monthly spending and customer rankings |
| Inventory Overview | Current stock levels and low-stock visibility |
| Category Rollup | Recursive low-stock aggregation through the category hierarchy |
| Stock Operations | Inventory purchase and stock movement operations |
| Audit Trail | Historical inventory movements and explanations |

The dashboard will consume the implemented application and database services. It will not bypass the transaction controls responsible for preventing overselling.

---

## 7. Repository Structure

The project will be organized into the following logical areas:

```text
kloud-kart-db-solution/
│
├── dashboard/
│
├── database/
│   ├── init/
│   ├── migrations/
│   └── sql/
│
├── docs/
│   └── adr/
│
├── evidence/
│   ├── baseline/
│   └── benchmarks/
│
├── provided_resources/
│   ├── data/
│   ├── load.sql
│   ├── race_test.py
│   └── schema.sql
│
├── scripts/
│
├── src/
│   └── kloud_kart_db_solution/
│
├── tests/
│
├── compose.yaml
├── Dockerfile
├── .env.example
├── .gitignore
├── README.md
└── requirements.txt
```

This structure may evolve as implementation progresses.

---

## 8. Assessment Resources

The `provided_resources/` directory contains the original assessment materials:

- `schema.sql`
- `load.sql`
- `race_test.py`
- Original CSV dataset

**Instructor-provided files must remain unchanged.**

Any additional database objects, SQL implementations, Python scripts, documentation and tests will be maintained separately within this repository.

---

## 9. Development Principles

The project follows these principles:

- **Data integrity:** Protect business-critical data through appropriate database constraints and transaction controls.
- **Concurrency safety:** Use PostgreSQL mechanisms to prevent conflicting inventory operations.
- **Performance measurement:** Benchmark queries before and after optimization.
- **Auditability:** Preserve a traceable history of inventory movements.
- **Reproducibility:** Use Docker to provide consistent development and testing environments.
- **Separation of concerns:** Keep database logic, application logic and dashboard presentation appropriately separated.
- **Incremental development:** Implement, validate, document, commit and push work in logical increments.
- **Evidence-based decisions:** Distinguish confirmed data problems from structural risks and unverified assumptions.

---

## 10. Project Status

**Current phase:** Infrastructure setup and Stage 1 — Load and Look.

The Docker Compose configuration has been created, and both PostgreSQL environments have been started and verified.

Implementation results, automated test outcomes, performance measurements and final assessment conclusions will be documented as the corresponding stages are completed.

---

## 11. Reproducibility

The intended submission will allow the instructor to:

1. Clone the repository.
2. Configure the required environment variables.
3. Start the PostgreSQL environments using Docker Compose.
4. Initialize the assessment database using the original supplied resources.
5. Execute the implemented SQL and application components.
6. Run automated tests, including the supplied race test.
7. Launch the Streamlit dashboard.
8. Review the supporting documentation and benchmark evidence.

Detailed execution instructions will be added as the implementation is completed.

---

## 12. License and Assessment Use

This repository is maintained for the SQL for Data Professionals assessment.

The original instructor-provided assessment resources are retained for the purpose of completing and reproducing the assigned work.