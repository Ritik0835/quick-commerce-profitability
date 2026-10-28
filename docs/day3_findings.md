# Day 3: break-even and sensitivity (modeled scenarios, not measurements)

All figures come from `excel/quick_commerce_model.xlsx` (sheets: Break-even, Sensitivity, Lever ranking). The store is synthetic and calibrated to Swiggy Instamart's Q2 FY27 totals. How costs split across individual lines is an assumption (Assumptions sheet, section 3), so treat every number below as a scenario estimate.

## Base case
Store contribution is about -INR 7.08 per order, or about -INR 8,444 per store per day at 1,192 orders per day. Each order contributes INR 19.76 at CM2, and fixed dark store cost is about INR 32,000 per day.

## Break-even orders per store per day
About 1,619 orders per day, which is 427 more than base (+35.8%). Blinkit's derived figure is about 1,718, so this volume is within range of what a Blinkit store already reports.

## What one lever alone would need to do (all else at base)

| Lever | Base | Break-even | Change |
|---|---:|---:|---:|
| Order value (NOV per order) | INR 506 | INR 575 | +13.7% |
| Orders per day | 1,192 | 1,619 | +35.8% |
| Delivery cost per order | INR 42.96 | INR 35.87 | -16.5% |
| Ad income per order | INR 20.06 | INR 27.15 | +35.3% |

## Ranking of levers for a 10% favourable change in each

| Rank | Lever | Change in store contribution per day | Share of base daily loss closed |
|---|---|---:|---:|
| 1 | Order value +10% | +INR 6,150 | 72.8% |
| 2 | Delivery cost -10% | +INR 5,120 | 60.6% |
| 3 | Ad income +10% | +INR 2,391 | 28.3% |
| 4 | Orders per day +10% | +INR 2,356 | 27.9% |

## Combinations from the sensitivity tables
- Order value +10% together with orders per day +10% gives about +INR 680 per day.
- Order value +10% together with delivery cost -10% gives about +INR 2,800 per day.

## Caveats
- The ranking depends on the synthetic cost split. Delivery's rank depends on delivery being 40% of all-in cost, and order value's rank depends on the 60% product margin share. The Day 3 settings and shares can be changed on the Assumptions sheet.
- Ranking measures profit impact only. It does not say how easy a 10% change is to achieve.
- Store-level break-even is not company break-even. Swiggy's guidance of about INR 30 contribution per order is for adjusted EBITDA break-even, which also covers central costs.
