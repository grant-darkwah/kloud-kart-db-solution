# Kloud Kart DB Solution
**A PostgreSQL inventory integrity, reporting and audit solution for Kloud Kart Ltd.**
![PostgreSQL](https://img.shields.io/badge/PostgreSQL-18-336791?logo=postgresql&logoColor=white) ![Docker](https://img.shields.io/badge/Docker-Compose-2496ED?logo=docker&logoColor=white) ![Python](https://img.shields.io/badge/Python-3-3776AB?logo=python&logoColor=white) ![License](https://img.shields.io/badge/License-<LICENSE>-lightgrey)
## Table of Contents
- [Overview](#overview)
- [Business Requirements](#business-requirements)
- [Delivered Capabilities](#delivered-capabilities)
- [Technology Stack](#technology-stack)
- [Environments](#environments)
- [Getting Started](#getting-started)
- [Running the Pipeline](#running-the-pipeline)
- [Configuration](#configuration)
- [Operational Safety](#operational-safety)
- [Troubleshooting](#troubleshooting)
- [Contributing](#contributing)
- [License](#license)
## Overview
Kloud Kart Ltd. is an e-commerce business in Accra, Ghana, processing roughly 4,000 orders per day. This repository investigates the existing PostgreSQL database and delivers a tested, repeatable solution for inventory integrity, business reporting, hierarchical stock analysis and auditing. Developed as part of the AmaliTech *SQL for Data Professionals* program.
## Business Requirements
1. **Inventory integrity:** prevent concurrent purchases from overselling the last available unit.
2. **Customer reporting:** produce customer spending reports for Monday business reviews.
3. **Category analytics:** aggregate low-stock inventory through a recursive category hierarchy.
4. **Auditability:** maintain an inventory movement audit trail of inventory movements.
## Delivered Capabilities
| Stage | Capability | Requirement |
|---|---|---|
| 01 | Load and Look | Baseline |
| 02 | Diagnose | Baseline |
| 03 | Prevent Overselling | 1 |
| 04 | Build the Monday Report | 2 |
| 05 | Roll Up the Category Tree | 3 |
| 06 | Optimize and Prove Performance | 1-3 |
| 07 | Implement the Inventory Audit Trail | 4 |
| 08 | Final Documentation and Pipeline | All |
## Technology Stack
| Layer | Technology |
|---|---|
| Database | PostgreSQL 18 |
| Containerization | Docker, Docker Compose |
| Automation | Python, Bash |
| Query language | SQL |
| Version control | Git, GitHub |
## Environments
| Environment | Container | Host Port | Database |
|---|---|---:|---|
| Production | `kloudkart-prod` | `5432` | `kloudkart_prod` |
| Testing | `kloudkart-test` | `5433` | `kloudkart_test` |
> **Important:** all development, testing and assessment operations run against `kloudkart_test`. Production is isolated and must never be targeted by this pipeline.
## Getting Started
### Prerequisites
- Docker and Docker Compose
- A running, initialized `kloudkart-test` container
- Python 3 virtual environment at `.venv` with dependencies installed
- A `.env` file created from `.env.example`
The database must already contain the supplied schema and dataset. The pipeline does **not** reset the database or reload the original data.
### Setup
```bash
git clone git@github.com:grant-darkwah/kloud-kart-db-solution.git
cd kloud-kart-db-solution
cp .env.example .env
docker compose ps
source .venv/bin/activate
```
Edit `.env` with your credentials, then confirm `kloudkart-test` is listed as running.
## Running the Pipeline
From the repository root:
```bash
bash scripts/run_all.sh
```
Verify connectivity to the test database manually:
```bash
docker exec -it kloudkart-test psql -U <DB_USER> -d kloudkart_test
```
## Configuration
All settings are read from `.env`. Never commit this file; `.env.example` is the template.
| Variable | Purpose |
|---|---|
| `<DB_HOST>` | Database host (typically `localhost`) |
| `<DB_PORT>` | Must be `5433` for testing |
| `<TEST_DB_NAME>` | Must be `kloudkart_test` |
| `<TEST_DB_USER>` / `<DB_PASSWORD>` | Credentials for the test database |
Replace the placeholders with the exact variable names defined in `.env.example`.
## Operational Safety
- Confirm `DB_PORT=5433` and `DB_NAME=kloudkart_test` before every run.
- Do not commit `.env`, credentials or database dumps.
- Treat the pipeline as non-destructive to source data; it does not drop or reload the original dataset.
- Review SQL changes in a pull request before they are applied anywhere beyond the test database.
## Troubleshooting
| Symptom | Likely cause | Fix |
|---|---|---|
| Connection refused on `5433` | Test container not running | `docker compose up -d`, then `docker compose ps` |
| Authentication failed | `.env` out of sync with container | Re-copy from `.env.example` and match container credentials |
| `relation does not exist` | Schema or dataset not loaded | Initialize `kloudkart-test` with the supplied dataset |
| `ModuleNotFoundError` | `.venv` inactive or incomplete | `source .venv/bin/activate` and reinstall dependencies |
## Contributing
1. Branch from `main`: `git checkout -b feature/<short-description>`
2. Make focused changes and run `bash scripts/run_all.sh` against the test database.
3. Commit with clear messages and open a pull request describing the change and its verification.
