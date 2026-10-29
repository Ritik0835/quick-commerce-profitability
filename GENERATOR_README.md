# Quick Commerce Profitability — Synthetic Data Generator

## What this creates
A reproducible, fully synthetic six-month quick-commerce dataset with five related CSV tables:
- `customers.csv` — customer dimension
- `orders.csv` — 100,000 order records, dates, order-hour/day pattern, value, and disruption flags
- `order_items.csv` — item-level lines for each order
- `dark_stores.csv` — 10 synthetic dark stores and disruption-window metadata
- `delivery_logs.csv` — one delivery-log record per order, including rain-delay effects

The generator also writes `generation_summary.txt` with the seed, date range, disruption windows, and basic validation results.

## Run it
From this project directory, with Python 3.10+:

```bash
python generate_synthetic_data.py
```

Defaults:
- Assumptions: `data/assumptions.csv`
- Output folder: `data/`
- Seed: read from `S04` in `data/assumptions.csv`

Optional paths:

```bash
python generate_synthetic_data.py --assumptions data/assumptions.csv --output-dir data
```

## Model structure
- `assumptions.csv` retains company benchmark rows and adds rows `S01`–`S21` for synthetic-only generator settings.
- The model uses Blinkit NAOV (`B01`) as a benchmark anchor for synthetic basket values, but the generated order-level data is **not company data**.
- The generated order volume is capped at the project target of 100,000 orders. It is not intended to represent all orders implied by company-reported store/day metrics.
- Weekdays/weekends use different demand weights; lunch/evening hours have higher order probability.
- Four stockout windows and five rain-delay windows are generated from the fixed seed. Windows and affected orders are flagged in the tables.
- The dataset covers 180 days from the configured start date. All cities, customers, stores, order activity, costs, disruptions, and delivery times are synthetic.
- The generator is deterministic for unchanged assumptions and Python random behavior.

## Tables and keys
- `customers.customer_id` is the customer primary key.
- `dark_stores.store_id` is the store primary key.
- `orders.order_id` is the order primary key and references `customers.customer_id` and `dark_stores.store_id`.
- `order_items.order_item_id` is the item primary key and `order_id` references `orders.order_id`.
- `delivery_logs.delivery_log_id` is the log primary key; `order_id` references `orders.order_id`.

## Important limitations
This is synthetic portfolio data, not a measurement or reconstruction of Blinkit/Instamart transaction data. Company-reported figures in `assumptions.csv` are benchmark references only. Synthetic settings are labeled `synthetic assumption` and should be adjusted for scenario analysis, not presented as factual company costs or daily order counts.
