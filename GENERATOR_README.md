# Quick Commerce Profitability — Synthetic Data Generator

## What it creates
A reproducible, fully synthetic six-month quick-commerce dataset with five related CSV tables in `data/`:
- `customers.csv` — 30,000 customers, each tied to a home store
- `dark_stores.csv` — 10 stores, with a daily fixed cost scaled to the generated volume
- `orders.csv` — 100,000 orders with status, flags, and revenue and cost columns for delivered orders
- `order_items.csv` — item lines for each order
- `delivery_logs.csv` — one log per order, with the rider payout for delivered orders

It also writes `generation_summary.txt` (seed, date range, windows, calibration targets).

## Run it
From the repo root, with Python 3.10 or later (standard library only):

```bash
python3 generate_synthetic_data.py
python3 validate_data.py
```

Options:

```bash
python3 generate_synthetic_data.py --assumptions data/assumptions.csv --output-dir data
python3 validate_data.py --data-dir data --assumptions data/assumptions.csv
```

`validate_data.py` runs 19 checks. All should print PASS.

## Where the parameters come from
- Company-reported anchors in `data/assumptions.csv` (IDs starting B and I): net order value (`I01`), orders (`I02`), gross order value (`I03`), contribution margin (`I07`), orders per store per day (`I11`), adjusted revenue (`I17`) and growth (`I19`).
- Synthetic settings in the same file (IDs `S01` to `S42`): seed, volumes, demand and disruption rules, cancellation mix, customer behaviour, revenue and cost shares, and the thresholds used by SQL.
- A few rules are still typed in the code, not in the CSV. They are listed in `docs/data_note.md`, section 6.

## How the revenue and cost columns are built
For each delivered order the generator draws a noisy value, then scales every column by one global factor so that its average per delivered order equals its target. The targets are the same per-order numbers as in the Excel model, so the data agrees with the model **by construction**. The store fixed cost is scaled to the generated volume (about 54 orders per store per day against Instamart's 1,192).

## Tables and keys
- `customers.customer_id` is the primary key; `home_store_id` references `dark_stores.store_id`.
- `orders.order_id` is the primary key; it references `customers` and `dark_stores`.
- `order_items.order_item_id` is the primary key; `order_id` references `orders`.
- `delivery_logs.delivery_log_id` is the primary key; `order_id` references `orders` and is unique.

## Important limitations
This is synthetic portfolio data. It is not a reconstruction of Blinkit or Instamart transactions. Company figures are benchmark references only, and the split of costs across lines is a synthetic assumption. Because some patterns are built into the generator, SQL can only rediscover them. `docs/data_note.md` lists each built-in rule and what SQL will find.
