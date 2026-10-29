# Data Note — Synthetic Quick-Commerce Dataset

## 1. Purpose

This dataset supports a hypothetical quick-commerce dark-store profitability analysis. It provides linked customer, order, order-item, store and delivery records for testing SQL analysis and evaluating modeled business scenarios.

**All generated operational records are synthetic.** They are not actual transactions from Blinkit, Swiggy Instamart or any other company.

## 2. Dataset scope

The generator produces:

- 30,000 synthetic customers
- 100,000 synthetic orders
- Approximately 100,000 delivery logs, one per order
- Multiple item lines per order
- 10 synthetic dark stores
- A 180-day simulated period, from 1 April 2026 to 27 September 2026

The generator uses random seed `42` and reads simulation parameters from `data/assumptions.csv`.

## 3. Rules used to generate the data

### Demand patterns

- Order demand varies by hour.
- Peak-hour weights increase the likelihood of orders during configured busy hours.
- Weekday and weekend demand use separate multipliers.

### Stockouts

- The generator creates a configured number of stockout windows.
- Each window lasts for a configured duration.
- Orders falling within these windows may be marked as affected.
- Affected orders may have a reduced simulated order value.

### Rain delays

- The generator creates configured rain-delay windows.
- Orders during these windows may be marked as rain-delayed according to the configured probability.
- Rain delays can add simulated delivery time.

### Other generated attributes

Customer segments, product categories, order values, quantities, order statuses and delivery durations are simulated according to the generator's implementation and configuration.

These rules create plausible analytical test data; they do not establish that real quick-commerce demand or operations follow the same patterns.

## 4. Reproducibility

The fixed random seed is `42`. Re-running the generator with the same code, compatible runtime and unchanged assumptions is intended to reproduce the same output.

If the assumptions or generator code change, the generated dataset may change. The generation summary records key run details.

## 5. What this dataset can support

It can support practice and demonstration of:

- SQL joins, aggregations and data-quality checks
- Hourly and weekday/weekend order-pattern analysis
- Comparisons between simulated stockout and non-stockout periods
- Delivery-duration analysis during simulated rain-delay periods
- Hypothetical profitability scenarios using explicitly documented assumptions

## 6. What this dataset cannot prove

It cannot prove:

- Actual order demand or customer purchasing behaviour
- Actual delivery performance or the real impact of weather
- Actual stockout frequency or its causal impact on revenue
- Actual operating costs, contribution margins or dark-store profitability
- That a modeled business intervention will work in the real world
- That observed patterns in this generated data independently validate the assumptions used to create it

Because some patterns are deliberately programmed into the generator, SQL may simply rediscover those rules. For example, a higher simulated delivery duration during rain-delay windows is an expected consequence of the generation logic, not independent evidence that rain caused a specific real-world delay.

## 7. Relationship to company disclosures

Published company metrics in `data/assumptions.csv` are reference benchmarks used to inform selected modeling assumptions. They are not transaction-level data and do not make the generated records representative of those companies.

Definitions, reporting periods and denominators must be checked before comparing company-reported metrics.

## 8. Responsible interpretation

Present analytical outputs as **synthetic-data findings** or **modeled scenarios under stated assumptions**. Do not describe them as measured company performance, causal evidence or forecasts of actual results.
