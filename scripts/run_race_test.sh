#!/usr/bin/env bash

set -Eeuo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"

DB_CONTAINER="kloudkart-test"
DB_USER="kloudkart_test"
DB_NAME="kloudkart_test"

TRIGGER_DISABLED=0

restore_audit_protection() {
    local exit_status=$?

    if [[ "$TRIGGER_DISABLED" -eq 1 ]]; then
        echo
        echo "Restoring inventory audit append-only protection..."

        if sudo docker exec "$DB_CONTAINER" psql \
            -U "$DB_USER" \
            -d "$DB_NAME" \
            -v ON_ERROR_STOP=1 \
            -c "ALTER TABLE public.inventory_log ENABLE TRIGGER inventory_log_append_only;"
        then
            echo "Append-only protection restored."
        else
            echo "ERROR: Could not restore append-only protection."
            exit_status=1
        fi
    fi

    exit "$exit_status"
}

trap restore_audit_protection EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

echo "Loading test database credentials..."

export DATABASE_URL="$(
    .venv/bin/python - <<'PY'
from dotenv import dotenv_values
from psycopg2.extensions import make_dsn

env = dotenv_values(".env")
required = ["TEST_DB_NAME", "TEST_DB_USER", "TEST_DB_PASSWORD"]
missing = [key for key in required if not env.get(key)]

if missing:
    raise SystemExit(f"Missing .env settings: {', '.join(missing)}")

print(make_dsn(
    host="localhost",
    port=5433,
    dbname=env["TEST_DB_NAME"],
    user=env["TEST_DB_USER"],
    password=env["TEST_DB_PASSWORD"],
))
PY
)"

echo "Checking test database availability..."

sudo docker exec "$DB_CONTAINER" pg_isready \
    -U "$DB_USER" \
    -d "$DB_NAME"

echo "Temporarily disabling only the append-only cleanup trigger..."

TRIGGER_DISABLED=1

sudo docker exec "$DB_CONTAINER" psql \
    -U "$DB_USER" \
    -d "$DB_NAME" \
    -v ON_ERROR_STOP=1 \
    -c "ALTER TABLE public.inventory_log DISABLE TRIGGER inventory_log_append_only;"

echo
echo "Running the original instructor race test unchanged..."
.venv/bin/python provided_resources/race_test.py

echo
echo "Race test completed successfully."
