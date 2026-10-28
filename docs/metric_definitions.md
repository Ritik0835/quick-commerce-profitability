# Metric definitions (Project day 1)

Companies do not define these the same way. Every figure in `data/assumptions.csv` is the company's own number, so read this file before comparing Blinkit and Instamart.

## What each company reports

| Term | Blinkit (Eternal) | Swiggy Instamart |
|---|---|---|
| Order value basis | NOV (net order value) is the headline | GOV (gross) and NOV both reported |
| Average order value | Net average order value (NAOV), after discounts | Net AOV (NOV / orders). GOV per order is higher (~INR 708 vs 506) |
| Contribution margin denominator | % of NOV in the Q1/Q2 FY27 letters | % of GOV |
| Contribution includes | Delivery, warehousing, wastage, packaging, customer acquisition, payment charges (per IndMoney summary of the letter) | Adjusted revenue minus order-level costs: delivery, fulfilment, dark store (per Inc42) |
| Store count | Active dark stores, end of period | Dark stores, end of period |
| Revenue model | Moved from marketplace to inventory-led (1P) from Q1 FY26, so revenue growth is not like-for-like (78% reported vs 58% like-for-like) | Marketplace today, pivot to inventory model planned from mid-Q3 FY27 |

## Why this matters

1. **NOV vs GOV.** Blinkit contribution of 5.3% of NOV and Instamart contribution of -1.0% of GOV are not the same scale. Instamart's NOV is about 71% of GOV (6,594 / 9,230), so -1.0% of GOV is roughly -1.4% of NOV. Convert before comparing.
2. **1P vs marketplace.** Under an inventory model the company books product margin as its own, so gross margin and contribution look higher without the customer paying more. Instamart's own pivot will make its future numbers non-comparable with its past.
3. **Cancellations.** Swiggy adjusts food delivery GOV for cancellations in some disclosures. I did not find a clear statement of treatment for Blinkit or Instamart orders. Open item: check the letters.
4. **Store counts and productivity.** Neither company publishes orders per store per day in the headline tables, so the figures in this project are derived (orders / average stores / 92 days). Average stores smooth over openings during the quarter.

## Project definitions (use these in the Excel model)

- **Order value (OV):** net order value per order, after discounts, excluding delivery and handling fees, in INR. Gross figures are only used when a source gives nothing else, and are labelled.
- **Orders per store per day (OPD):** quarterly orders / average of opening and closing store count / days in quarter.
- **Contribution margin (CM):** revenue after all order-level costs (delivery, dark store running cost, packaging, wastage, payment), before central costs, marketing brand spend and technology. Always stated as % of NOV in this project. Swiggy's GOV-based figures are converted using the NOV/GOV ratio.
- **Contribution per order:** CM% x NOV per order, in INR.
- **Break-even:** the point where contribution per order covers store fixed cost per order at a given OPD.
- **Labels:** every figure is `reported` (company disclosed) or `derived` (my calculation). Scenarios built on them are scenarios, not measurements.
