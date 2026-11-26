# Docker Infrastructure

## Overview

Kloud Kart uses two isolated PostgreSQL 18 environments managed by Docker Compose.

| Environment | Container | Database | Host Port |
|---|---|---|---|
| Production | kloudkart-prod | kloudkart_prod | 5432 |
| Testing | kloudkart-test | kloudkart_test | 5433 |

Each environment has a separate named Docker volume and database credentials.

## Requirements

- Docker Engine
- Docker Compose
- A configured `.env` file

## Environment Configuration

Copy the example configuration:

    cp .env.example .env

Configure separate production and testing credentials in `.env`.

Never commit `.env` to GitHub.

## Start the Environments

From the project root:

    sudo docker compose up -d

Check container status:

    sudo docker compose ps

Both PostgreSQL services should report healthy.

## Database Initialization

The testing database automatically initializes when its data volume is empty.

Initialization performs the following operations:

1. Executes the original `schema.sql`.
2. Loads the six CSV files using the original `load.sql`.
3. Runs ANALYZE.
4. Displays the loaded row counts.

The original assessment resources are mounted read-only.

Production does not automatically load the assessment dataset.

## Database Access

Production:

    sudo docker exec -it kloudkart-prod \
      psql -U kloudkart_admin -d kloudkart_prod

Testing:

    sudo docker exec -it kloudkart-test \
      psql -U kloudkart_test -d kloudkart_test

## Logs

View testing database initialization and runtime logs:

    sudo docker logs kloudkart-test

View production logs:

    sudo docker logs kloudkart-prod

## Reset Testing Environment

WARNING: This operation permanently deletes the testing database and its data.

Stop and remove the testing container:

    sudo docker compose stop postgres-test
    sudo docker compose rm -f postgres-test

Remove only the testing volume:

    sudo docker volume rm kloud-kart-db-solution_kloudkart_test_data

Recreate the testing service:

    sudo docker compose up -d postgres-test

PostgreSQL will initialize the empty testing volume and reload the assessment dataset.

Never remove the production volume when resetting the testing environment.

## Production Environment

Production is isolated from the assessment initialization process.

Its application schema will be introduced through controlled database migrations as the solution is implemented.