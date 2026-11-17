#!/usr/bin/env bash
# Full read-only verification: regenerate the data, compare it with the committed
# files, build a throwaway database, run every SQL check and drop that database.
# The committed data and the default quick_commerce database are never modified.
#
# Environment:
#   QC_VERIFY_DB   throwaway database name (default: quick_commerce_verify)
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

VERIFY_DB="${QC_VERIFY_DB:-quick_commerce_verify}"
if [[ "$VERIFY_DB" == "quick_commerce" ]]; then
    echo "QC_VERIFY_DB must not be 'quick_commerce'; refusing to overwrite it." >&2
    exit 2
fi

TMP="$(mktemp -d)"
DB_CREATED=0
cleanup() {
    rm -rf "$TMP" || true
    if [[ "$DB_CREATED" -eq 1 ]]; then
        dropdb --if-exists "$VERIFY_DB" >/dev/null 2>&1 || true
    fi
}
trap cleanup EXIT

echo "== Regenerating data in $TMP/generated"
python3 generate_synthetic_data.py \
    --assumptions "$ROOT/data/assumptions.csv" \
    --output-dir "$TMP/generated" > "$TMP/generate.log"

echo "== Running the 19 Python data checks"
python3 validate_data.py \
    --data-dir "$TMP/generated" \
    --assumptions "$ROOT/data/assumptions.csv" > "$TMP/validate.log"

echo "== Comparing regenerated files with committed files"
for file in \
    customers.csv \
    orders.csv \
    order_items.csv \
    dark_stores.csv \
    delivery_logs.csv \
    generation_summary.txt; do
    if ! cmp -s "data/$file" "$TMP/generated/$file"; then
        echo "Regenerated $file differs from the committed file." >&2
        exit 1
    fi
    echo "IDENTICAL $file"
done

echo "== Building throwaway database '$VERIFY_DB'"
export QC_DB="$VERIFY_DB"
DB_CREATED=1
bash scripts/load.sh --reset > "$TMP/load.log"

echo "== Running SQL checks, analysis and assertions"
bash scripts/run_analysis.sh > "$TMP/analysis.log" 2> "$TMP/analysis.err"

echo "Verification passed: 19 data checks, 21 SQL quality checks and all headline assertions."
