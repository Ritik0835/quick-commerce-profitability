#!/usr/bin/env python3
"""Generate reproducible relational synthetic quick-commerce data.

Reads all simulation parameters from assumptions.csv. Creates customers, orders,
order_items, dark_stores, and delivery_logs. Every generated row is synthetic.
"""
from __future__ import annotations
import argparse, csv, random, math
from itertools import accumulate
from collections import Counter
from datetime import date, datetime, time, timedelta
from pathlib import Path

def load_assumptions(path):
    with path.open("r", newline="", encoding="utf-8-sig") as f:
        rows = list(csv.DictReader(f))
    if not rows:
        raise ValueError(f"No rows found in {path}")
    return rows

def row_for(rows, row_id):
    matches = [r for r in rows if r.get("id", "").strip() == row_id]
    if len(matches) != 1:
        raise ValueError(f"Expected exactly one row with id={row_id}; found {len(matches)}")
    return matches[0]

def number(rows, row_id):
    try:
        return float(row_for(rows, row_id)["value"])
    except (TypeError, ValueError, KeyError) as exc:
        raise ValueError(f"Assumption {row_id} must contain a numeric value") from exc

def string_value(rows, row_id):
    return row_for(rows, row_id).get("value", "").strip()

def write_csv(path, fields, rows):
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=fields)
        writer.writeheader()
        writer.writerows(rows)

def pick_hour(rng, peak_weight, open_hour, close_hour):
    # Peak windows: lunch (12-14) and dinner (18-21). Other hours have weight 1.
    hours = list(range(open_hour, close_hour + 1))
    weights = [peak_weight if h in (12, 13, 18, 19, 20) else (1.5 if h in (11, 14, 17, 21) else 1.0) for h in hours]
    return rng.choices(hours, weights=weights, k=1)[0]
def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--assumptions", default="data/assumptions.csv")
    parser.add_argument("--output-dir", default="data")
    args = parser.parse_args()
    assumptions_path = Path(args.assumptions)
    outdir = Path(args.output_dir)
    rows = load_assumptions(assumptions_path)

    total_orders = int(number(rows, "S01"))
    store_count = int(number(rows, "S02"))
    days = int(number(rows, "S03"))
    seed = int(number(rows, "S04"))
    customer_count = int(number(rows, "S05"))
    start_date = date.fromisoformat(string_value(rows, "S06"))
    weekday_multiplier = number(rows, "S07")
    weekend_multiplier = number(rows, "S08")
    peak_hour_weight = number(rows, "S09")
    stockout_period_count = int(number(rows, "S10"))
    stockout_duration = int(number(rows, "S11"))
    stockout_value_multiplier = number(rows, "S12")
    rain_period_count = int(number(rows, "S13"))
    rain_duration = int(number(rows, "S14"))
    rain_delay_probability = number(rows, "S15")
    normal_delivery_minutes = number(rows, "S16")
    rain_extra_minutes = number(rows, "S17")
    order_value_cv = number(rows, "S18")
    delivery_noise = number(rows, "S19")
    stockout_order_probability = number(rows, "S20")
    store_share_cv = number(rows, "S21")
    cancel_share = number(rows, "S28")
    return_share = number(rows, "S29")
    min_order_value = number(rows, "S30")
    open_hour = int(number(rows, "S31"))
    close_hour = int(number(rows, "S32"))
    segment_weight = {"new": number(rows, "S33"), "regular": number(rows, "S34"), "high_frequency": number(rows, "S35")}
    naov = number(rows, "I01")

    if total_orders <= 0 or store_count < 1 or days < 1 or customer_count < 1:
        raise ValueError("Order, store, day, and customer counts must be positive")
    if not 0 <= rain_delay_probability <= 1 or not 0 <= stockout_order_probability <= 1:
        raise ValueError("Probabilities must be between 0 and 1")
    if naov <= 0 or order_value_cv < 0:
        raise ValueError("NAOV must be positive and order value CV cannot be negative")

    rng = random.Random(seed)
    end_date = start_date + timedelta(days=days - 1)
    date_list = [start_date + timedelta(days=i) for i in range(days)]

    # Generate disruption windows, each fully inside the simulation date range.
    def windows(count, duration):
        if count <= 0 or duration <= 0 or duration > days:
            return []
        starts = sorted(rng.sample(range(days - duration + 1), k=min(count, days - duration + 1)))
        return [(date_list[s], date_list[s + duration - 1]) for s in starts]
    stockout_windows = windows(stockout_period_count, stockout_duration)
    rain_windows = windows(rain_period_count, rain_duration)

    def in_windows(d, win):
        return any(a <= d <= b for a, b in win)
    def format_windows(win):
        return ";".join(f"{a.isoformat()}..{b.isoformat()}" for a,b in win) or "none"

    # Store allocation factors and master table.
    store_ids = [f"STORE_{i:03d}" for i in range(1, store_count + 1)]
    store_factors = [max(0.1, rng.gauss(1.0, store_share_cv)) for _ in store_ids]
    total_factor = sum(store_factors)
    stores = []
    for i, sid in enumerate(store_ids):
        stores.append({
            "store_id": sid,
            "store_name": f"Synthetic Dark Store {i+1:02d}",
            "city": f"Synthetic_City_{i % 4 + 1}",
            "opened_date": (start_date - timedelta(days=rng.randint(30, 900))).isoformat(),
            "store_size_sqft": rng.randint(1800, 3500),
            "daily_fixed_cost_inr": rng.random(),  # placeholder: keeps the random stream unchanged; the real value is set in Step 5
            "synthetic_data_flag": "YES"
        })

    # Customer master; IDs are stable and may repeat in orders.
    customers = []
    for i in range(1, customer_count + 1):
        reg_offset = rng.randint(0, 365)
        home_store = rng.choices(store_ids, weights=store_factors, k=1)[0]
        customers.append({
            "customer_id": f"CUST_{i:06d}",
            "signup_date": (start_date - timedelta(days=reg_offset)).isoformat(),
            "home_store_id": home_store,
            "home_city": next(s["city"] for s in stores if s["store_id"] == home_store),
            "customer_segment": rng.choices(["new", "regular", "high_frequency"], weights=[0.45, 0.45, 0.10], k=1)[0],
            "synthetic_data_flag": "YES"
        })
    customer_ids = [c["customer_id"] for c in customers]
    pool_ids = {sid: [] for sid in store_ids}
    pool_weights = {sid: [] for sid in store_ids}
    for c in customers:
        pool_ids[c["home_store_id"]].append(c["customer_id"])
        pool_weights[c["home_store_id"]].append(segment_weight[c["customer_segment"]])
    pool_cum = {sid: list(accumulate(w)) for sid, w in pool_weights.items()}
    # Distribute exactly total_orders across dates, weighted for weekday/weekend demand.
    day_weights = []
    for d in date_list:
        base = weekend_multiplier if d.weekday() >= 5 else weekday_multiplier
        day_weights.append(max(0.01, base * rng.lognormvariate(0, 0.12)))
    day_counts = rng.choices(range(days), weights=day_weights, k=total_orders)
    order_day_indices = sorted(day_counts)

    # Pre-create order IDs and allocate them to stores according to store factor.
    orders = []
    order_items = []
    delivery_logs = []
    products = [
        ("PROD_001", "Fresh produce"), ("PROD_002", "Dairy"), ("PROD_003", "Bakery"),
        ("PROD_004", "Snacks"), ("PROD_005", "Beverages"), ("PROD_006", "Household"),
        ("PROD_007", "Personal care"), ("PROD_008", "Staples"), ("PROD_009", "Frozen"),
        ("PROD_010", "Packaged food")
    ]
    # Store orders by date for reporting and a randomized hourly timestamp.
    for i, day_idx in enumerate(order_day_indices, start=1):
        d = date_list[day_idx]
        store_idx = rng.choices(range(store_count), weights=store_factors, k=1)[0]
        store_id = store_ids[store_idx]
        customer_id = rng.choices(pool_ids[store_id], cum_weights=pool_cum[store_id], k=1)[0]
        hour = pick_hour(rng, peak_hour_weight, open_hour, close_hour)
        minute = rng.randrange(60)
        second = rng.randrange(60)
        order_dt = datetime.combine(d, time(hour, minute, second))
        stockout_day = in_windows(d, stockout_windows)
        rain_day = in_windows(d, rain_windows)
        stockout_affected = bool(stockout_day and rng.random() < stockout_order_probability)
        rain_delayed = bool(rain_day and rng.random() < rain_delay_probability)

        # Lognormal multiplier has mean approximately one; apply stockout impact only to affected orders.
        sigma = math.sqrt(math.log(1 + order_value_cv**2))
        value_multiplier = rng.lognormvariate(-0.5 * sigma * sigma, sigma)
        basket_value = max(min_order_value, naov * value_multiplier)
        if stockout_affected:
            basket_value *= stockout_value_multiplier
        basket_value = round(basket_value, 2)

        n_items = rng.choices([1,2,3,4,5], weights=[0.12,0.28,0.30,0.20,0.10], k=1)[0]
        # Split basket value into positive line totals; ensure exact sum to order value.
        if n_items == 1:
            line_values = [basket_value]
        else:
            weights = [rng.uniform(0.4, 1.6) for _ in range(n_items)]
            total_w = sum(weights)
            line_values = [round(basket_value * w / total_w, 2) for w in weights[:-1]]
            line_values.append(round(basket_value - sum(line_values), 2))
        for j, line_value in enumerate(line_values, start=1):
            product_id, category = rng.choice(products)
            qty = rng.choices([1, 2, 3], weights=[0.82, 0.15, 0.03], k=1)[0]
            # Four decimal places preserve the line total to the nearest paise after rounding.
            unit_price = round(line_value / qty, 4)
            order_items.append({
                "order_item_id": f"ITEM_{i:07d}_{j:02d}",
                "order_id": f"ORD_{i:07d}",
                "product_id": product_id,
                "product_category": category,
                "quantity": qty,
                "unit_price_inr": unit_price,
                "line_total_inr": round(line_value, 2),
                "stockout_affected": "YES" if stockout_affected else "NO",
                "synthetic_data_flag": "YES"
            })
        delivery_minutes = max(8, round(rng.gauss(normal_delivery_minutes + (rain_extra_minutes if rain_delayed else 0), delivery_noise)))
        dispatch_dt = order_dt + timedelta(minutes=rng.randint(2, 8))
        delivered_dt = dispatch_dt + timedelta(minutes=delivery_minutes)
        status = rng.choices(["delivered", "cancelled", "returned"], weights=[1 - cancel_share - return_share, cancel_share, return_share], k=1)[0]
        orders.append({
            "order_id": f"ORD_{i:07d}",
            "customer_id": customer_id,
            "store_id": store_id,
            "order_ts": order_dt.isoformat(sep=" "),
            "order_date": d.isoformat(),
            "order_hour": hour,
            "day_of_week": d.strftime("%A"),
            "day_type": "weekend" if d.weekday() >= 5 else "weekday",
            "order_value_inr": basket_value,
            "order_status": status,
            "stockout_period": "YES" if stockout_day else "NO",
            "stockout_affected": "YES" if stockout_affected else "NO",
            "rain_delay_period": "YES" if rain_day else "NO",
            "rain_delayed": "YES" if rain_delayed else "NO",
            "synthetic_data_flag": "YES"
        })
        delivery_logs.append({
            "delivery_log_id": f"DLV_{i:07d}",
            "order_id": f"ORD_{i:07d}",
            "store_id": store_id,
            "order_ts": order_dt.isoformat(sep=" "),
            "dispatch_ts": "" if status == "cancelled" else dispatch_dt.isoformat(sep=" "),
            "delivered_ts": "" if status == "cancelled" else delivered_dt.isoformat(sep=" "),
            "delivery_duration_minutes": "" if status == "cancelled" else delivery_minutes,
            "rain_delay_period": "YES" if rain_day else "NO",
            "rain_delayed": "YES" if rain_delayed else "NO",
            "delivery_status": "delivered" if status == "delivered" else status,
            "synthetic_data_flag": "YES"
        })

    # Order_items are constructed to sum to order_value; unit price * quantity may have rounding differences.
    # Build the dark-store master with the synthetic disruption windows in an explicit field.
    for s in stores:
        s["stockout_windows"] = format_windows(stockout_windows)
        s["rain_delay_windows"] = format_windows(rain_windows)

    # ---- Step 4: revenue and cost columns, scaled per delivered order to company-anchored targets ----
    adj_po = number(rows, "I17") * 1e7 / (number(rows, "I02") * 1e6)
    gov_po = number(rows, "I03") * 1e7 / (number(rows, "I02") * 1e6)
    cost_po = adj_po - number(rows, "I07") / 100 * gov_po
    targets = {
        "product_margin_inr": number(rows, "S22") * adj_po,
        "ad_income_inr": number(rows, "S23") * adj_po,
        "customer_fee_inr": (1 - number(rows, "S22") - number(rows, "S23")) * adj_po,
        "platform_discount_inr": number(rows, "S24") * cost_po,
        "rider_payout_inr": number(rows, "S25") * cost_po,
        "picking_packing_cost_inr": number(rows, "S26") * cost_po,
        "payment_cost_inr": number(rows, "S27") * cost_po,
    }
    coupon_share = number(rows, "S36")
    noise = number(rows, "S37")
    time_sens = number(rows, "S38")
    rng2 = random.Random(seed + 1)
    lines_per_order = Counter(it["order_id"] for it in order_items)
    raw = {name: [0.0] * len(orders) for name in targets}
    for k, o in enumerate(orders):
        if o["order_status"] != "delivered":
            continue
        raw["product_margin_inr"][k] = o["order_value_inr"] * rng2.lognormvariate(0, noise / 2)
        raw["ad_income_inr"][k] = rng2.lognormvariate(0, noise)
        raw["customer_fee_inr"][k] = rng2.lognormvariate(0, noise / 2)
        raw["platform_discount_inr"][k] = rng2.lognormvariate(0, noise) if rng2.random() < coupon_share else 0.0
        raw["picking_packing_cost_inr"][k] = lines_per_order[o["order_id"]]
        raw["payment_cost_inr"][k] = o["order_value_inr"]
        raw["rider_payout_inr"][k] = (1 - time_sens) + time_sens * delivery_logs[k]["delivery_duration_minutes"] / normal_delivery_minutes
    delivered_idx = [k for k, o in enumerate(orders) if o["order_status"] == "delivered"]
    calibration_lines = []
    for name, target in targets.items():
        factor = target / (sum(raw[name][k] for k in delivered_idx) / len(delivered_idx))
        for k in delivered_idx:
            value = round(raw[name][k] * factor, 2)
            if name == "rider_payout_inr":
                delivery_logs[k][name] = value
            else:
                orders[k][name] = value
        calibration_lines.append(f"{name}: target {target:.2f} per delivered order")
    for k, o in enumerate(orders):
        if o["order_status"] != "delivered":
            delivery_logs[k]["rider_payout_inr"] = 0.0
            for name in targets:
                if name != "rider_payout_inr":
                    o[name] = 0.0


    # ---- Step 5: store fixed cost scaled to the generated order volume ----
    fixed_per_order = (1 - number(rows, "S24") - number(rows, "S25") - number(rows, "S26") - number(rows, "S27")) * cost_po
    mean_daily_fixed = fixed_per_order * len(delivered_idx) / (days * store_count)
    mean_size = sum(s["store_size_sqft"] for s in stores) / len(stores)
    for s in stores:
        s["daily_fixed_cost_inr"] = round(mean_daily_fixed * s["store_size_sqft"] / mean_size, 2)
    volume_scale = len(delivered_idx) / (days * store_count) / number(rows, "I11")
    calibration_lines.append(f"store_fixed_cost_inr: target {fixed_per_order:.2f} per delivered order; volume scale vs a real store {volume_scale:.4f}")

    write_csv(outdir / "customers.csv",
              ["customer_id","signup_date","home_store_id","home_city","customer_segment","synthetic_data_flag"], customers)
    write_csv(outdir / "orders.csv",
              ["order_id","customer_id","store_id","order_ts","order_date","order_hour","day_of_week","day_type","order_value_inr","order_status","stockout_period","stockout_affected","rain_delay_period","rain_delayed","product_margin_inr","ad_income_inr","customer_fee_inr","platform_discount_inr","picking_packing_cost_inr","payment_cost_inr","synthetic_data_flag"], orders)
    write_csv(outdir / "order_items.csv",
              ["order_item_id","order_id","product_id","product_category","quantity","unit_price_inr","line_total_inr","stockout_affected","synthetic_data_flag"], order_items)
    write_csv(outdir / "dark_stores.csv",
              ["store_id","store_name","city","opened_date","store_size_sqft","daily_fixed_cost_inr","stockout_windows","rain_delay_windows","synthetic_data_flag"], stores)
    write_csv(outdir / "delivery_logs.csv",
              ["delivery_log_id","order_id","store_id","order_ts","dispatch_ts","delivered_ts","delivery_duration_minutes","rain_delay_period","rain_delayed","delivery_status","rider_payout_inr","synthetic_data_flag"], delivery_logs)

    # Basic data quality checks, also written for project evidence.
    assert len(orders) == total_orders
    assert len({o["order_id"] for o in orders}) == total_orders
    customer_id_set = set(customer_ids)
    store_id_set = set(store_ids)
    assert all(o["customer_id"] in customer_id_set for o in orders)
    assert all(o["store_id"] in store_id_set for o in orders)
    assert len(delivery_logs) == total_orders
    with (outdir / "generation_summary.txt").open("w", encoding="utf-8") as f:
        f.write(f"random_seed={seed}\n")
        f.write(f"date_range={start_date.isoformat()}..{end_date.isoformat()} ({days} days)\n")
        f.write(f"customers={len(customers)}\norders={len(orders)}\norder_items={len(order_items)}\ndark_stores={len(stores)}\ndelivery_logs={len(delivery_logs)}\n")
        f.write(f"stockout_windows={format_windows(stockout_windows)}\n")
        f.write(f"rain_delay_windows={format_windows(rain_windows)}\n")
        f.write("checks=PASS: unique order IDs; all order customer/store references valid; one delivery log per order\n")
        f.write("note=All generated rows are synthetic and are not company-reported daily data.\n")
        f.write("".join(line + "\n" for line in calibration_lines))
    print(f"Generated {len(customers):,} customers, {len(orders):,} orders, {len(order_items):,} order_items, {len(stores)} dark_stores, and {len(delivery_logs):,} delivery_logs.")
    print(f"Date range: {start_date.isoformat()} to {end_date.isoformat()} ({days} days); seed={seed}.")
    print(f"Stockout windows: {format_windows(stockout_windows)}")
    print(f"Rain-delay windows: {format_windows(rain_windows)}")
    print(f"Output directory: {outdir}")

if __name__ == "__main__":
    main()
