#!/usr/bin/env bash
# Build the quick-commerce database from the committed CSVs.
#
# Usage:
#   scripts/load.sh            # create the DB if missing, refuse if it has tables
#   scripts/load.sh --reset    # drop and rebuild the DB (destroys local data)
#
# Environment:
#   QC_DB   database name (default: quick_commerce)
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

DB="${QC_DB:-quick_commerce}"
RESET=0
if [[ "${1:-}" == "--reset" ]]; then
    RESET=1
elif [[ $# -gt 0 ]]; then
    echo "Unknown argument: $1" >&2
    echo "Usage: scripts/load.sh [--reset]" >&2
    exit 2
fi

for cmd in psql createdb dropdb; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo "$cmd not found; install PostgreSQL client tools first." >&2
        exit 1
    fi
done

REQUIRED_FILES=(
    assumptions.csv
    customers.csv
    dark_stores.csv
    orders.csv
    order_items.csv
    delivery_logs.csv
    excel_reference.csv
)
for file in "${REQUIRED_FILES[@]}"; do
    if [[ ! -f "data/$file" ]]; then
        echo "Missing data/$file. Run the generator or restore the committed data first." >&2
        exit 1
    fi
done

if [[ "$RESET" -eq 1 ]]; then
    echo "Dropping and recreating database '$DB'"
    dropdb --if-exists "$DB"
fi

EXISTS="$(psql -X -At -d postgres -v db="$DB" <<'SQL'
SELECT 1 FROM pg_database WHERE datname = :'db';
SQL
)"
if [[ "$EXISTS" != "1" ]]; then
    echo "Creating database '$DB'"
    createdb "$DB"
fi

TABLE_COUNT="$(psql -X -At -d "$DB" \
    -c "SELECT count(*) FROM information_schema.tables WHERE table_schema = 'public'")"
if [[ "$TABLE_COUNT" -ne 0 ]]; then
    echo "Database '$DB' already contains $TABLE_COUNT tables or views." >&2
    echo "Run scripts/load.sh --reset to rebuild it from the committed CSVs." >&2
    exit 1
fi

run_sql() {
    echo "Running sql/$1"
    psql -X -q -v ON_ERROR_STOP=1 -d "$DB" -f "sql/$1" -o /dev/null
}

run_sql 01_schema.sql
run_sql 02_load.sql
run_sql 04_views.sql
run_sql 09_break_even.sql

psql -X -d "$DB" -Atc "
    SELECT 'orders=' || count(*) FROM orders
    UNION ALL SELECT 'delivered_orders=' || count(*) FROM orders WHERE order_status = 'delivered'
    UNION ALL SELECT 'order_items=' || count(*) FROM order_items
    UNION ALL SELECT 'delivery_logs=' || count(*) FROM delivery_logs
    UNION ALL SELECT 'v_order_cm=' || count(*) FROM v_order_cm
"
echo "Loaded database '$DB'."
