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
