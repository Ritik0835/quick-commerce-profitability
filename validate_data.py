#!/usr/bin/env python3
"""Validate the generated quick-commerce CSV tables using only the Python standard library."""
import argparse, csv
from collections import defaultdict
from decimal import Decimal
from pathlib import Path

def read(path):
    with path.open("r", newline="", encoding="utf-8-sig") as f:
        return list(csv.DictReader(f))

def numbers(path):
    out = {}
    for r in read(path):
        try:
            out[r["id"]] = float(r["value"])
        except ValueError:
            pass
    return out

def main():
    p = argparse.ArgumentParser()
    p.add_argument("--data-dir", default="data")
    p.add_argument("--assumptions", default="data/assumptions.csv")
    args = p.parse_args()
    d = Path(args.data_dir)
    a = numbers(Path(args.assumptions))
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

    adj = a["I17"] * 1e7 / (a["I02"] * 1e6)
    gov = a["I03"] * 1e7 / (a["I02"] * 1e6)
    cost = adj - a["I07"] / 100 * gov
    t = {"product_margin_inr": a["S22"] * adj, "ad_income_inr": a["S23"] * adj,
            "customer_fee_inr": (1 - a["S22"] - a["S23"]) * adj, "platform_discount_inr": a["S24"] * cost,
            "rider_payout_inr": a["S25"] * cost, "picking_packing_cost_inr": a["S26"] * cost,
            "payment_cost_inr": a["S27"] * cost}
    log_by_order = {r["order_id"]: r for r in logs}
    delivered = [r for r in orders if r["order_status"] == "delivered"]
    others = [r for r in orders if r["order_status"] != "delivered"]
    def avg(col):
        if col == "rider_payout_inr":
            return sum(float(log_by_order[r["order_id"]][col]) for r in delivered) / len(delivered)
        return sum(float(r[col]) for r in delivered) / len(delivered)
    got = {col: avg(col) for col in t}
    days = len({r["order_date"] for r in orders})
    fixed_per_order = sum(float(s["daily_fixed_cost_inr"]) for s in stores) * days / len(delivered)
    contribution = (got["product_margin_inr"] + got["ad_income_inr"] + got["customer_fee_inr"]
                    - got["platform_discount_inr"] - got["rider_payout_inr"] - got["picking_packing_cost_inr"]
                    - got["payment_cost_inr"] - fixed_per_order)
    home_city = {r["customer_id"]: r["home_city"] for r in customers}
    store_city = {r["store_id"]: r["city"] for r in stores}
    n_orders = defaultdict(int)
    for r in orders:
        n_orders[r["customer_id"]] += 1
    seg_total = defaultdict(int)
    seg_count = defaultdict(int)
    for r in customers:
        seg_total[r["customer_segment"]] += n_orders[r["customer_id"]]
        seg_count[r["customer_segment"]] += 1
    seg_avg = {k: seg_total[k] / seg_count[k] for k in seg_count}

    checks = {
        "order count matches S01": len(orders) == int(a["S01"]),
        "8-12 stores": 8 <= len(stores) <= 12,
        "date span matches S03": len({r["order_date"] for r in orders}) == int(a["S03"]),
        "unique order IDs": len(order_ids) == len(orders),
        "orders reference known customers": all(r["customer_id"] in customer_ids for r in orders),
        "orders reference known stores": all(r["store_id"] in store_ids for r in orders),
        "items reference known orders": all(r["order_id"] in order_ids for r in items),
        "delivery logs reference known orders": all(r["order_id"] in order_ids for r in logs),
        "one delivery log per order": len(logs) == len(orders) and len({r["order_id"] for r in logs}) == len(orders),
        "item totals reconcile to order values": all(item_totals[oid].quantize(Decimal("0.01")) == val for oid, val in order_values.items()),
        "all data flagged synthetic": all(r["synthetic_data_flag"] == "YES" for table in [customers, orders, items, stores, logs] for r in table),
        "cancelled orders have no delivery time": all(not log_by_order[r["order_id"]]["delivered_ts"] for r in orders if r["order_status"] == "cancelled"),
        "customers order only from stores in their home city": all(home_city[r["customer_id"]] == store_city[r["store_id"]] for r in orders),
        "high-frequency customers order more than regular, and regular more than new": seg_avg["high_frequency"] > seg_avg["regular"] > seg_avg["new"],
        "money columns are never negative": all(float(r[c]) >= 0 for r in orders for c in t if c != "rider_payout_inr") and all(float(r["rider_payout_inr"]) >= 0 for r in logs),
        "cancelled and returned orders carry no revenue or cost": all(float(r[c]) == 0 for r in others for c in t if c != "rider_payout_inr") and all(float(log_by_order[r["order_id"]]["rider_payout_inr"]) == 0 for r in others),
        "revenue and cost averages match the anchored targets (within 0.05 INR)": all(abs(got[c] - t[c]) < 0.05 for c in t),
        "store contribution per delivered order matches the reported contribution (within 0.10 INR)": abs(contribution - a["I07"] / 100 * gov) < 0.10,
        "mean net order value is within 2 INR of the anchor": abs(sum(float(r["order_value_inr"]) for r in delivered) / len(delivered) - a["I01"]) < 2,         
 
    }
    for label, ok in checks.items():
        print(f"{'PASS' if ok else 'FAIL'} — {label}")
    if not all(checks.values()):
        raise SystemExit(1)
    print(f"\nValidated {len(customers):,} customers, {len(orders):,} orders, {len(items):,} items, {len(stores)} stores, {len(logs):,} delivery logs.")

if __name__ == "__main__":
    main()
