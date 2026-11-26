#!/bin/bash

set -euo pipefail

echo "=========================================="
echo "Initializing Kloud Kart TEST database"
echo "=========================================="

cd /provided_resources

echo "Step 1: Creating database schema..."

psql \
    --username "$POSTGRES_USER" \
    --dbname "$POSTGRES_DB" \
    --set ON_ERROR_STOP=1 \
    --file schema.sql

echo "Step 2: Loading assessment dataset..."

psql \
    --username "$POSTGRES_USER" \
    --dbname "$POSTGRES_DB" \
    --set ON_ERROR_STOP=1 \
    --file load.sql

echo "Kloud Kart TEST database initialization completed."
