# Metric definitions (Project day 1)

Every figure in `data/assumptions.csv` is checked against the company's own Q2 FY27 shareholder letter (page numbers are in the CSV) unless `primary_doc_verified` says `no`. The two companies do not define metrics the same way, so read this before comparing them.

## How each company defines the key terms (from the letters' glossaries)

| Term | Blinkit (Eternal) | Swiggy Instamart |
|---|---|---|
| Orders | All orders placed, **including cancelled orders** | **Completed orders only** |
| GOV | Order value at MRP, before any discounts, plus delivery, handling, packaging fees and taxes | Same idea: MRP-based, before discounts, plus delivery, packaging, user fees and taxes |
| NOV | GOV less all discounts (brand, seller, platform, bank) | GOV less all discounts (platform or partner funded) |
| Headline order value | Net AOV (NAOV) = NOV / orders | Net AOV (nAOV) = NOV / orders, and AOV on GOV basis is also shown |
| Contribution margin denominator | % of **NOV** | % of **GOV** |
| Contribution built as | Adjusted Revenue less COGS on owned inventory, dark store operations (including actual rent), last mile, warehouses, middle mile, customer acquisition subsidies, wastage, refunds, packaging, payment gateway, support, onboarding, cash handling, misc | Adjusted Revenue less delivery, platform-funded discounts, fulfilment services, other variable costs |
| Revenue model | Inventory-led (1P) for much of sales since Q1 FY26, so revenue includes full goods value | Marketplace today. Inventory model starts mid-Q3 FY27 (about +80 bps contribution) |
| Orders per store per day | Not disclosed. NOV per store per day is (simple average per day over stores operational each day) | Disclosed: orders per dark store per day, on active store-days |

## What this means for the model

1. **Convert denominators before comparing.** Instamart NOV is 71% of GOV, so -1.0% of GOV is about -1.4% of NOV. Blinkit's +5.3% is already on NOV.
2. **Cancellations.** Blinkit counts cancelled orders in its order count and Instamart counts only completed ones, so order counts and average order values are not strictly like-for-like. The effect size is not disclosed.
3. **Marketplace vs inventory.** Blinkit's contribution sits after COGS on owned inventory, while Instamart's is a marketplace take-rate view. Instamart's own margin will shift when it moves to inventory, so do not extrapolate from old quarters.
4. **Derived figures.** Orders per store per day for Blinkit (1,718) and contribution per order for both companies are my calculations, labelled `derived`.

## Project definitions (use these in the Excel model)

- **Order value (OV):** net order value per order (NOV / orders), in INR. GOV-based figures are converted using the NOV/GOV ratio.
- **Orders per store per day (OPD):** orders divided by store-days. For Blinkit, derived as NOV per store per day / NAOV.
- **Contribution margin (CM):** order-level profit after variable costs and store running costs, before central costs and brand marketing. Always shown as % of NOV in this project.
- **Contribution per order:** CM% x NOV per order, in INR.
- **Break-even:** contribution per order covers store fixed cost per order at a given OPD. Reference point: Swiggy states break-even needs about INR 30 contribution per order.
- **Labels:** every figure is `reported` or `derived`. Scenarios built on them are scenarios, not measurements.

## CM1 and CM2 (Day 2 model)

CM1 is what an order earns after the product and the discounts, meaning net order value less product cost (the seller's or supplier's share), plus the ad income and customer fees the platform collects, less platform-funded discounts. CM2 is CM1 less the variable cost of fulfilling the order: picking, packing, last-mile delivery, and payment and other per-order costs. Dark store fixed costs (rent, fixed staff, utilities) sit below CM2 and are spread over the day's orders; CM2 less that charge is the store contribution per order, which matches the way the companies report contribution. Central costs such as technology, brand marketing and corporate overhead are excluded.

The model's totals are anchored to Swiggy Instamart's Q2 FY27 letter (adjusted revenue per order about INR 100, contribution about -INR 7 per order). How those totals split across individual cost lines is not disclosed by any company, so the split is a labelled synthetic allocation on the Assumptions sheet (section 3).





## KPI definitions (used identically in SQL, Excel and Power BI)

All KPIs use delivered orders only unless stated. Cancelled and returned orders carry no revenue and no cost in this dataset.

| KPI | Definition |
|---|---|
| CM1 per order | product margin + ad income + customer fee - platform discount |
| CM2 per order | CM1 - picking and packing cost - rider payout - payment cost |
| Store contribution (store-day) | Sum of CM2 over the day's delivered orders - the store's daily fixed cost, charged once per store-day |
| AOV | Average net order value (`order_value_inr`) per delivered order |
| Orders per store per day | Delivered orders / store-days |
| On-time % | Delivered orders with `delivery_duration_minutes` <= S39 (15) / delivered orders |
| 30-day repeat rate | Among customers whose first delivered order in the data is at least S40 (30) days before the data ends, the share who placed another delivered order within 30 days of that first order. The first order in the data is not the customer's true first order |
| Stockout loss | For delivered orders with `stockout_affected`, order value x (1 / S12 - 1): the value lost against an unaffected basket. This only recovers the built-in rule S12 |
