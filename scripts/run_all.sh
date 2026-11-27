
#!/usr/bin/env bash

set -Eeuo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"

DB_CONTAINER="kloudkart-test"
DB_USER="kloudkart_test"
DB_NAME="kloudkart_test"

LOG_DIR="evidence/final"
mkdir -p "$LOG_DIR"

LOG_FILE="$LOG_DIR/run-all-$(date +%Y%m%d-%H%M%S).log"
exec > >(tee -a "$LOG_FILE") 2>&1

echo "============================================================"
echo "KLOUD KART LTD. — FINAL SQL PIPELINE"
echo "============================================================"
echo "Started: $(date)"
echo "Target:  $DB_NAME"
echo "Log:     $LOG_FILE"
echo

fail() {
    echo "ERROR: $*" >&2
    exit 1
}

run_sql() {
    local file="$1"

    [[ -f "$file" ]] || fail "SQL file not found: $file"

    echo
    echo "------------------------------------------------------------"
    echo "Executing: $file"
    echo "------------------------------------------------------------"

    sudo docker exec -i "$DB_CONTAINER" psql \
        -U "$DB_USER" \
        -d "$DB_NAME" \
        -v ON_ERROR_STOP=1 < "$file"
}

# ------------------------------------------------------------
# 1. Verify environment and database
# ------------------------------------------------------------

echo "[1/8] Checking environment..."

[[ -f .env ]] || fail ".env file is missing."
[[ -x .venv/bin/python ]] || fail "Python virtual environment is missing."
[[ -f provided_resources/race_test.py ]] || fail "Instructor race test is missing."
[[ -x scripts/run_race_test.sh ]] || fail "Race-test wrapper is missing."

set -a
source .env
set +a

[[ -n "${TEST_DB_NAME:-}" ]] || fail "TEST_DB_NAME is missing."
[[ -n "${TEST_DB_USER:-}" ]] || fail "TEST_DB_USER is missing."
[[ -n "${TEST_DB_PASSWORD:-}" ]] || fail "TEST_DB_PASSWORD is missing."

[[ "$TEST_DB_NAME" == "$DB_NAME" ]] \
    || fail "Configured test database does not match the expected test database."

[[ "$TEST_DB_USER" == "$DB_USER" ]] \
    || fail "Configured test database user does not match the expected user."

sudo docker inspect "$DB_CONTAINER" >/dev/null 2>&1 \
    || fail "Test database container is not available."

CONTAINER_STATUS="$(
    sudo docker inspect \
        --format '{{.State.Status}}' "$DB_CONTAINER"
)"

[[ "$CONTAINER_STATUS" == "running" ]] \
    || fail "Test database container is not running."

DB_IDENTITY="$(
    sudo docker exec "$DB_CONTAINER" psql \
        -U "$DB_USER" -d "$DB_NAME" \
        -At -v ON_ERROR_STOP=1 \
        -c "SELECT current_database() || '|' || current_user;"
)"

[[ "$DB_IDENTITY" == "$DB_NAME|$DB_USER" ]] \
    || fail "Connected database identity is unexpected: $DB_IDENTITY"

echo "Database identity verified: $DB_IDENTITY"

# ------------------------------------------------------------
# 2. Verify source tables and data
# ------------------------------------------------------------

echo
echo "[2/8] Checking source tables and data..."

sudo docker exec "$DB_CONTAINER" psql \
    -U "$DB_USER" -d "$DB_NAME" \
    -v ON_ERROR_STOP=1 \
    -c "
DO \$\$
BEGIN
    IF to_regclass('public.categories') IS NULL
       OR to_regclass('public.products') IS NULL
       OR to_regclass('public.customers') IS NULL
       OR to_regclass('public.orders') IS NULL
       OR to_regclass('public.order_items') IS NULL
       OR to_regclass('public.inventory_log') IS NULL
    THEN
        RAISE EXCEPTION 'One or more required source tables are missing.';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM public.customers)
       OR NOT EXISTS (SELECT 1 FROM public.products)
    THEN
        RAISE EXCEPTION 'Required source data is missing.';
    END IF;
END
\$\$;
"

echo "Required tables and source data verified."

# ------------------------------------------------------------
# 3. Run original data diagnosis
# ------------------------------------------------------------

echo
echo "[3/8] Running Stage 2 diagnosis..."

for file in database/sql/diagnosis/*.sql; do
    run_sql "$file"
done

# ------------------------------------------------------------
# 4. Apply migrations in order
# ------------------------------------------------------------

echo
echo "[4/8] Checking and applying database migrations..."

PLACE_ORDER_EXISTS="$(
    sudo docker exec "$DB_CONTAINER" psql \
        -U "$DB_USER" -d "$DB_NAME" \
        -At -v ON_ERROR_STOP=1 \
        -c "SELECT to_regprocedure('public.place_order(bigint,bigint,integer)') IS NOT NULL;"
)"

if [[ "$PLACE_ORDER_EXISTS" != "t" ]]; then
    run_sql database/migrations/001_prevent_overselling.sql
else
    echo "Migration 001 already installed; skipping."
fi

AUDIT_COLUMN_COUNT="$(
    sudo docker exec "$DB_CONTAINER" psql \
        -U "$DB_USER" -d "$DB_NAME" \
        -At -v ON_ERROR_STOP=1 \
        -c "
        SELECT COUNT(*)
        FROM information_schema.columns
        WHERE table_schema = 'public'
          AND table_name = 'inventory_log'
          AND column_name IN (
              'quantity_before',
              'quantity_after',
              'actor',
              'reference_type',
              'reference_id'
          );
        "
)"

AUDIT_TRIGGER_COUNT="$(
    sudo docker exec "$DB_CONTAINER" psql \
        -U "$DB_USER" -d "$DB_NAME" \
        -At -v ON_ERROR_STOP=1 \
        -c "
        SELECT COUNT(*)
        FROM pg_trigger
        WHERE NOT tgisinternal
          AND tgname IN (
              'inventory_log_append_only',
              'products_inventory_audit'
          )
          AND tgrelid IN (
              'public.inventory_log'::regclass,
              'public.products'::regclass
          );
        "
)"

if [[ "$AUDIT_COLUMN_COUNT" == "0" && "$AUDIT_TRIGGER_COUNT" == "0" ]]; then
    run_sql database/migrations/002_inventory_audit_trail.sql
elif [[ "$AUDIT_COLUMN_COUNT" == "5" && "$AUDIT_TRIGGER_COUNT" == "2" ]]; then
    echo "Migration 002 already installed; skipping."
else
    fail "Partial or inconsistent Stage 7 migration detected. Manual inspection required."
fi

# Verify both audit triggers are enabled before continuing.
INITIAL_TRIGGER_COUNT="$(
    sudo docker exec "$DB_CONTAINER" psql \
        -U "$DB_USER" -d "$DB_NAME" \
        -At -v ON_ERROR_STOP=1 \
        -c "
        SELECT COUNT(*)
        FROM pg_trigger
        WHERE NOT tgisinternal
          AND tgenabled = 'O'
          AND (
              (tgrelid = 'public.inventory_log'::regclass
               AND tgname = 'inventory_log_append_only')
              OR
              (tgrelid = 'public.products'::regclass
               AND tgname = 'products_inventory_audit')
          );
        "
)"

[[ "$INITIAL_TRIGGER_COUNT" == "2" ]] \
    || fail "Both inventory audit triggers must be enabled before continuing."

echo "Both migrations verified. Both audit triggers are enabled."

# ------------------------------------------------------------
# 5. Configure performance and run customer reports
# ------------------------------------------------------------

echo
echo "[5/8] Running performance configuration and customer reports..."

REPORT_BUNDLE="$(mktemp)"
trap 'rm -f "$REPORT_BUNDLE"' EXIT

cat \
    database/sql/reporting/05_performance_optimization.sql \
    database/sql/reporting/01_customer_spending.sql \
    database/sql/reporting/02_monthly_spending.sql \
    database/sql/reporting/03_running_totals.sql \
    database/sql/reporting/04_top_100_customers.sql \
    > "$REPORT_BUNDLE"

echo "Executing performance setup and all four reports in one session..."

sudo docker exec -i "$DB_CONTAINER" psql \
    -U "$DB_USER" \
    -d "$DB_NAME" \
    -v ON_ERROR_STOP=1 < "$REPORT_BUNDLE"

# ------------------------------------------------------------
# 6. Run recursive category rollup
# ------------------------------------------------------------

echo
echo "[6/8] Running Stage 5 category rollup..."

run_sql database/sql/category/01_low_stock_category_rollup.sql

# ------------------------------------------------------------
# 7. Run unchanged instructor race test
# ------------------------------------------------------------

echo
echo "[7/8] Running the original instructor race test..."

bash scripts/run_race_test.sh

# ------------------------------------------------------------
# 8. Final database checks
# ------------------------------------------------------------

echo
echo "[8/8] Running final database checks..."

sudo docker exec "$DB_CONTAINER" psql \
    -U "$DB_USER" -d "$DB_NAME" \
    -v ON_ERROR_STOP=1 \
    -c "
SELECT
    current_database() AS database_name,
    current_user AS database_user;

SELECT
    COUNT(*) AS inventory_audit_records
FROM public.inventory_log;
"

FINAL_TRIGGER_COUNT="$(
    sudo docker exec "$DB_CONTAINER" psql \
        -U "$DB_USER" -d "$DB_NAME" \
        -At -v ON_ERROR_STOP=1 \
        -c "
        SELECT COUNT(*)
        FROM pg_trigger
        WHERE NOT tgisinternal
          AND tgenabled = 'O'
          AND (
              (tgrelid = 'public.inventory_log'::regclass
               AND tgname = 'inventory_log_append_only')
              OR
              (tgrelid = 'public.products'::regclass
               AND tgname = 'products_inventory_audit')
          );
        "
)"

[[ "$FINAL_TRIGGER_COUNT" == "2" ]] \
    || fail "Final check failed: both inventory audit triggers must be enabled."

echo
echo "============================================================"
echo "FINAL PIPELINE COMPLETED SUCCESSFULLY"
echo "============================================================"
echo "Finished: $(date)"
echo "Database: $DB_NAME"
echo "Both audit triggers: ENABLED"
echo "Execution log: $LOG_FILE"
