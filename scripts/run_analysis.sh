#!/usr/bin/env bash
# Re-run every SQL check and analysis against a loaded quick-commerce database.
# Fails on the first SQL error or assertion failure. Use scripts/load.sh first.
#
# Environment:
#   QC_DB   database name (default: quick_commerce)
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

DB="${QC_DB:-quick_commerce}"

if ! psql -X -d "$DB" -Atc "SELECT 1" >/dev/null 2>&1; then
    echo "Cannot connect to database '$DB'. Run scripts/load.sh first." >&2
    exit 1
fi

for file in \
    03_quality_checks.sql \
    05_queries.sql \
    06_kpis.sql \
    07_reconcile.sql \
    09_break_even.sql \
    08_assertions.sql; do
    echo "===== sql/$file ====="
    psql -X -v ON_ERROR_STOP=1 -d "$DB" -f "sql/$file"
done
