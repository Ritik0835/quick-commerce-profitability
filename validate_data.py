#!/usr/bin/env python3
"""Validate the generated quick-commerce CSV tables using only the Python standard library."""
import argparse, csv
from collections import defaultdict
from decimal import Decimal
from pathlib import Path

def read(path):
    with path.open("r", newline="", encoding="utf-8-sig") as f:
        return list(csv.DictReader(f))

def main():
    p = argparse.ArgumentParser()
    p.add_argument("--data-dir", default="data")
    args = p.parse_args()
    d = Path(args.data_dir)
    customers = read(d / "customers.csv")
    orders = read(d / "orders.csv")
    items = read(d / "order_items.csv")
    stores = read(d / "dark_stores.csv")
    logs = read(d / "delivery_logs.csv")
    customer_ids = {r["customer_id"] for r in customers}
    store_ids = {r["store_id"] for r in stores}
    order_ids = {r["order_id"] for r in orders}
    item_totals = defaultdict(Decimal)
    for row in items:
        item_totals[row["order_id"]] += Decimal(row["line_total_inr"])
    order_values = {r["order_id"]: Decimal(r["order_value_inr"]) for r in orders}
    checks = {
        "100000 orders": len(orders) == 100000,
        "8-12 stores": 8 <= len(stores) <= 12,
        "180-day date span": len({r["order_date"] for r in orders}) == 180,
        "unique order IDs": len(order_ids) == len(orders),
        "orders reference known customers": all(r["customer_id"] in customer_ids for r in orders),
        "orders reference known stores": all(r["store_id"] in store_ids for r in orders),
        "items reference known orders": all(r["order_id"] in order_ids for r in items),
        "delivery logs reference known orders": all(r["order_id"] in order_ids for r in logs),
        "one delivery log per order": len(logs) == len(orders) and len({r["order_id"] for r in logs}) == len(orders),
        "item totals reconcile to order values": all(item_totals[oid].quantize(Decimal("0.01")) == val for oid, val in order_values.items()),
        "all data flagged synthetic": all(r["synthetic_data_flag"] == "YES" for table in [customers, orders, items, stores, logs] for r in table),
    }
    for label, ok in checks.items():
        print(f"{'PASS' if ok else 'FAIL'} — {label}")
    if not all(checks.values()):
        raise SystemExit(1)
    print(f"\nValidated {len(customers):,} customers, {len(orders):,} orders, {len(items):,} items, {len(stores)} stores, {len(logs):,} delivery logs.")

if __name__ == "__main__":
    main()
