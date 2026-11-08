# Quick Commerce Profitability: From Loss to Profit

> **Data disclaimer:** This project uses synthetic data created for analytical and educational purposes. The data does not represent actual operating results from any quick-commerce company. All findings are modeled scenarios based on explicitly documented assumptions, not measured company performance.

## Problem

A quick-commerce dark store can lose money on every order even when demand is strong, because the contribution an order earns does not cover the store's fixed cost. This project asks which of four levers could take a modeled store to break-even, and by how much:

- **Average order value (AOV)**
- **Order volume** (orders per store per day)
- **Delivery cost per order**
- **Ad income per order**

The store is synthetic and calibrated to Swiggy Instamart's Q2 FY27 shareholder-letter totals. Customer lifetime value and acquisition cost are out of scope because reliable public marketing-spend data does not exist.

## Key questions

1. What drives the store's loss?
2. How far must each lever move, alone, to reach break-even?
3. Which combination is the most practical modeled path?

## What is in this repo

| Folder or file | What it holds |
|---|---|
| `data/assumptions.csv` | Company-reported figures with source, page and URL, plus synthetic generator settings |
| `excel/quick_commerce_model.xlsx` | Per-order and store-daily P&L, break-even, sensitivity tables, lever ranking and scenarios |
| `generate_synthetic_data.py`, `validate_data.py` | Seeded data generator and a 19-check validator |
| `data/*.csv` | Five synthetic tables (customers, dark stores, orders, order items, delivery logs) |
| `sql/` | PostgreSQL schema, load script, quality checks, views, window-function queries, KPIs, reconciliation |
| `docs/` | Data dictionary, data note, metric definitions, findings, reconciliation, CEO memo |
| `powerbi/` | Power BI report (in progress) and the documented DAX measures with expected values |

## How to run it

```bash
# 1. Generate and validate the data (Python 3.10+, standard library only)
python3 generate_synthetic_data.py
python3 validate_data.py

# 2. Load it into PostgreSQL, from the repo root
createdb quick_commerce
psql -d quick_commerce -f sql/01_schema.sql -f sql/02_load.sql -f sql/04_views.sql
psql -d quick_commerce -f sql/03_quality_checks.sql
psql -d quick_commerce -f sql/05_queries.sql
psql -d quick_commerce -f sql/06_kpis.sql
psql -d quick_commerce -f sql/07_reconcile.sql
```

## Definitions used everywhere (SQL, Excel)

- **CM1** = product margin + ad income + customer fee - platform discount
- **CM2** = CM1 - picking and packing - rider payout - payment cost
- **Store contribution** = CM2 - the store's daily fixed cost

Full KPI definitions are in `docs/metric_definitions.md`.

## Modeled findings (scenarios, not measurements)

These come from the Excel model and the synthetic store.

- **Base case:** each order earns about 19.76 INR after variable costs (CM2) but carries about 26.85 INR of fixed cost, so the store loses about 7.08 INR per order.
- **Break-even:** about 1,619 orders per store per day against 1,192 today, a rise of about 36%.
- **One lever alone, to break even:** order value +13.7%, delivery cost -16.5%, ad income +35.3%, or orders per day +35.8%.
- **Ranking for a 10% favourable change:** order value, then delivery cost, then ad income, then orders per day.
- **Three fixes combined:** the range runs from a continued loss (low case) through about break-even (central case) to a profit (high case). See `docs/day4_scenarios.md`.

The cost split across lines is a synthetic assumption. The ranking depends on it, so treat it as an illustration of the method and not a finding about real stores.

## Important: the answer is partly built into the generator

If you build the answer into the generator, the SQL will only rediscover it. That applies here. The generator deliberately contains rules for peak hours, weekend demand, stockouts, rain delays, customer segments and cost shares. So when SQL shows that rain-delayed orders are slower, that weekends lose less per order, or that high-frequency customers repeat more, it is rediscovering those rules. It is not independent evidence about real stores.

The data also agrees with the Excel model on per-order averages because it was calibrated to the same assumptions. `docs/reconciliation.md` shows the match (25 of 27 comparisons; the two gaps are one explained difference in order value). The match shows the pipeline works. It does not prove the economics. `docs/data_note.md` lists every built-in rule, what SQL will find, and what the data cannot prove.

## Limitations

- All operational records are synthetic. Company figures are reference benchmarks only.
- The synthetic stores are about 4.5% of a real store's volume; fixed cost is scaled to match.
- Cancelled and returned orders carry no revenue or cost.
- Stockout and rain windows hit all stores on the same days.
- Product prices are not tied to products, and no customer signs up inside the window.
- Findings are modeled scenarios under documented assumptions, not forecasts or causal evidence.

## Weaknesses and what I would do next

1. **The cost split is a synthetic assumption.** Companies do not publish how cost divides into delivery, picking, payment and fixed lines, so I chose the shares. The ranking of levers depends on them. *Fix:* with real data, take cost per order by line; without it, show how the ranking changes across a range of splits.
2. **The data agrees with the model by construction.** The generator was calibrated to the same assumptions as the Excel model, and some patterns are built in, so SQL partly rediscovers them. *Fix:* test the analysis against data produced by a different mechanism, and add a negative-control test (change a generator rule and confirm the SQL notices).
3. **The model is a single store and ignores demand response.** The fixes are applied independently and multiply, central costs are excluded, and a higher order value does not change volume. *Fix:* add price and volume elasticity, a store ramp-up curve, and an allocation of central costs.

## Documentation

- [`docs/data_dictionary.md`](docs/data_dictionary.md) — every table and column
- [`docs/data_note.md`](docs/data_note.md) — what is generated, the rules used, what it cannot prove
- [`docs/metric_definitions.md`](docs/metric_definitions.md) — CM1, CM2 and KPI definitions
- [`docs/reconciliation.md`](docs/reconciliation.md) — SQL against Excel
- [`docs/ceo_memo.md`](docs/ceo_memo.md) — one-page memo with scenario ranges and assumptions
- [`powerbi/measures.md`](powerbi/measures.md) — Power BI model, DAX measures and expected values
- [`docs/day3_findings.md`](docs/day3_findings.md) and [`docs/day4_scenarios.md`](docs/day4_scenarios.md) — break-even, sensitivity and scenarios
- [`docs/company_assumptions.md`](docs/company_assumptions.md) — company-disclosed benchmarks
- [`GENERATOR_README.md`](GENERATOR_README.md) — generator details

## Status

The CEO memo is done. The two-tab Power BI dashboard and the final screenshots are still in progress.
