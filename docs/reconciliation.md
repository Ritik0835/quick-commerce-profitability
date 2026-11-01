# Reconciliation: SQL versus the Excel model (Day 9)

**Result: 25 of 27 comparisons match within tolerance. The two gaps are both order value and have one explained cause.**

## What was compared
`sql/07_reconcile.sql` loads `data/excel_reference.csv` (Excel values with their sheet and cell address) and compares them with the SQL views.

- **Per-order lines** come from `v_order_cm` (fixed cost and contribution from `v_store_day_pnl`). Excel source: sheet "Per-order P&L", cells B6 to B19.
- **Store-day lines** are SQL store-day totals scaled up to Excel's 1,192 orders per day, because the synthetic stores average about 54 orders a day, about 4.5% of a real store. Excel source: sheet "Store daily P&L", cells B6 to B19.
- **Tolerances** are assumptions S41 (0.02 INR per order, scaled by orders per day for store-day lines) and S42 (0.10 INR per order for order value after adding back the stockout cut). Costs carry a minus sign, as in Excel.

## Results (INR per order)

| Line | SQL | Excel | Difference | Status |
|---|---:|---:|---:|---|
| Net order value | 505.19 | 506.00 | -0.81 | GAP (explained below) |
| Net order value, stockout cut added back | 505.92 | 506.00 | -0.08 | OK |
| Product margin | 60.18 | 60.18 | 0.00 | OK |
| Ad income | 20.06 | 20.06 | 0.00 | OK |
| Customer fees | 20.06 | 20.06 | 0.00 | OK |
| Platform discount | -12.89 | -12.89 | 0.00 | OK |
| CM1 | 87.42 | 87.42 | 0.00 | OK |
| Picking and packing | -16.11 | -16.11 | 0.00 | OK |
| Rider payout | -42.96 | -42.96 | 0.00 | OK |
| Payment cost | -8.59 | -8.59 | 0.00 | OK |
| CM2 | 19.76 | 19.76 | 0.00 | OK |
| Fixed cost | -26.85 | -26.85 | 0.00 | OK |
| Store contribution | -7.08 | -7.08 | 0.00 | OK |

Store-day totals scaled to 1,192 orders a day: every line is within 1.4 INR of Excel on values between 10,000 and 600,000, except net order value, which has the same cause as below. Store contribution is -8,445 against -8,444 per store-day.

## The gap and its cause
Average order value in the data is 505.19 INR against 506.00 in Excel (-0.16%). The generator cuts the value of stockout-affected orders by 12% (assumption S12). That affects 1.2% of delivered orders and removes about 0.73 INR per order on average. Adding it back gives 505.92, within 0.08 INR of Excel.

**Decision:** explained, no regeneration. The gap does not affect CM1, CM2, fixed cost or contribution, which all match, so changing the generator would cost a data rebuild for no change in any profit figure.

## What this does and does not show
- It shows the pipeline (generator, CSV, PostgreSQL, views) keeps the model's economics, and that CM1 and CM2 are computed exactly as defined in `metric_definitions.md`.
- It does **not** validate the economics. The generator was calibrated to the same assumptions as the Excel model, so agreement is expected. The assumptions themselves (the cost split especially) are synthetic.

## How to reproduce
```
psql -d quick_commerce -f sql/01_schema.sql -f sql/02_load.sql -f sql/04_views.sql
psql -d quick_commerce -f sql/07_reconcile.sql
```
