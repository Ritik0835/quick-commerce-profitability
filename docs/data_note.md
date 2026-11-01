# Data Note — Synthetic Quick-Commerce Dataset

## 1. Purpose

This dataset supports a hypothetical quick-commerce dark-store profitability analysis. It provides linked customer, order, order-item, store and delivery records for testing SQL analysis and evaluating modeled business scenarios.

**All generated operational records are synthetic.** They are not transactions from Blinkit, Swiggy Instamart or any other company.

## 2. What is generated

| Table | Rows | Notes |
|---|---:|---|
| customers | 30,000 | Each customer has one home store |
| dark_stores | 10 | Four synthetic city labels |
| orders | 100,000 | 96,474 delivered, 2,513 cancelled, 1,013 returned |
| order_items | 287,810 | About 2.9 lines per order |
| delivery_logs | 100,000 | One per order; cancelled orders have no delivery times |

The window is 180 days, 1 April to 27 September 2026. The generator uses seed 42 and reads its settings from `data/assumptions.csv` (IDs starting with S).

## 3. How the numbers are anchored

Company figures from Swiggy's Q2 FY27 shareholder letter fix the **averages per delivered order**: net order value (I01), adjusted revenue and orders (I17, I02), gross order value (I03), contribution margin (I07), orders per store per day (I11) and the growth rate (I19). The generator scales each revenue and cost column by one global factor so that its average matches the target. Relative differences (by hour, store, weather) are untouched.

How a total divides into lines (product margin 60%, ads 20%, fees 20% of revenue; discounts 12%, delivery 40%, picking 15%, payment 8%, fixed 25% of cost) is **not disclosed by any company**. These are synthetic shares (S22 to S27) and are the same ones used in the Excel model.

**Consequence:** the data agrees with the Excel model on per-order averages by construction. `docs/reconciliation.md` shows the match, but the match is expected and is not an independent check of the economics.

## 4. Scale

The data has about 54 delivered orders per store per day. Instamart reports 1,192. So each synthetic store is about 4.5% of a real store, and `daily_fixed_cost_inr` is scaled by the same ratio so that fixed cost per order stays at about 26.85 INR. Compare per-order values with Excel directly. To compare store-day totals, scale them by orders per day, as `sql/07_reconcile.sql` does.

## 5. Rules built into the generator, and what SQL will "discover"

If the answer is built into the generator, SQL will only rediscover it. These are the rules built in. Any SQL finding that matches one of them is not independent evidence.

| Built-in rule | Parameters | What SQL will find |
|---|---|---|
| Order demand peaks at hours 12, 13, 18, 19, 20 (weight 2.5) and is higher in the shoulder hours | S09, plus shoulder weights typed in the code | About 51% of orders fall in five hours |
| Weekends have more orders | S07, S08 | Weekend days carry about 1.35 times the orders; because fixed cost is per day, weekends lose less per order |
| Stores differ in demand | S21 | Unequal order counts per store |
| Fixed cost follows store size, not volume | store size typed in the code; scaling in Step 5 | Big stores with few orders lose the most per order |
| Stockouts: 4 windows of 2 days, 30% of orders in them affected, value cut 12% | S10, S11, S20, S12 | About 1.2% of orders flagged; a small "stockout loss" |
| Rain: 5 windows of 2 days, 75% of orders in them delayed, +6 minutes | S13, S14, S15, S17 | Rain-delayed orders are slower, less often on time, and cost more |
| Rider payout grows with delivery minutes | S38 | Rain-delayed orders cost about 8 INR more |
| High-frequency customers are picked 8 times more often than new ones | S33 to S35 | Repeat rate differs hugely by customer segment |
| Cancellations 2.5% and returns 1.0%, at random | S28, S29 | A cancellation rate of about 2.5% with no real driver |
| Delivery time and margins do not depend on the hour | (no rule) | Hour-by-hour profit differences are noise |

## 6. Rules typed in the generator, not in assumptions.csv

These are not yet adjustable from `assumptions.csv`: the shoulder-hour weights, the 45/45/10 segment mix, the 1,800 to 3,500 sq ft store size range, the four-city rotation, the 1 to 5 items per order weights, the ten-product list, the random split of a basket across lines, the daily noise on demand, and customer signup dates up to 365 days before the window.

## 7. Known simplifications

- Cancelled and returned orders carry no revenue and no cost. A real returned order costs money.
- All customers exist before the window; none sign up during it.
- Product prices are not tied to products; line values are a random split of the basket.
- Stockout and rain windows are whole days and hit all stores on the same days.
- Order value does not depend on hour or weekday.
- Customer lifetime value and acquisition cost are out of scope: reliable public marketing-spend data is not available.

## 8. Reproducibility

`python3 generate_synthetic_data.py` with seed 42 and the same Python version regenerates the committed files exactly. `python3 validate_data.py` runs 19 checks (structure, links, cost columns, customer rules, calibration to the targets). `sql/03_quality_checks.sql` runs 21 checks inside the database. Both check that the data matches the rules above, not that the rules match reality.

## 9. What this dataset can support

- Practice with SQL joins, window functions and data-quality checks
- Building and testing KPI definitions (CM1, CM2, on-time %, repeat rate, stockout loss)
- Modeled profitability scenarios under documented assumptions

## 10. What it cannot prove

- Real demand, customer behaviour or repeat rates
- Real delivery performance, or that rain causes the delay it shows here
- Real stockout frequency or its effect on revenue
- Real operating costs or the real split of costs across lines
- That any modeled fix would work in a real store
- That a pattern found in this data validates the assumption that produced it

With real data, the first things to check would be the cost split by line, delivery cost by distance and hour, and customer repeat behaviour from true first orders.

## 11. Responsible interpretation

Describe outputs as **synthetic-data findings** or **modeled scenarios under stated assumptions**. Do not describe them as measured company performance, causal evidence or forecasts.
