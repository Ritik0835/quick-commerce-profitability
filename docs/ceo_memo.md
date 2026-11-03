# Memo: Closing the per-order loss in a modeled quick-commerce dark store

**To:** CEO  |  **From:** [your name]  |  **Date:** [date]
**Basis:** an Excel model of one dark store with synthetic data, calibrated to Swiggy Instamart's Q2 FY27 totals. These are modeled scenarios, not measured results.

## Headline

In the model, each order earns ₹19.76 after variable costs but carries ₹26.85 of store fixed cost, a loss of ₹7.08 per order; three fixes together reach about break-even in the central case.

## Where the store stands

The modeled store handles 1,192 orders a day and loses about ₹2.5 lakh a month. Break-even needs about 1,619 orders a day, 36% more. Moved one at a time, order value would need to rise 13.7%, delivery cost fall 16.5%, or ad income rise 35%.

## Three fixes, as ranges (impact on one store, per month)

| Fix | Low | Central | High | Main assumption |
|---|---|---|---|---|
| 1. Bundling raises order value | +2% → ₹0.4 lakh | +4.3% → ₹0.8 lakh | +8% → ₹1.5 lakh | Central matches the reported 4.3% year-on-year rise in order value |
| 2. More orders per store | +5% → ₹0.4 lakh | +9.5% → ₹0.7 lakh | +20% → ₹1.4 lakh | Central matches the reported 9.5% quarterly rise; fixed cost stays flat |
| 3. Lower delivery cost per order | −3% → ₹0.5 lakh | −6% → ₹0.9 lakh | −10% → ₹1.5 lakh | A judgement; no company figure exists |
| **All three together** | **₹1.2 lakh** | **₹2.5 lakh** | **₹5.0 lakh** | Fixes multiply, so the total is not the sum |

Against a loss of ₹2.5 lakh a month, the low case still loses about ₹4,400 a day, the central case reaches about break-even, and the high case earns about ₹8,300 a day. Across Instamart's 1,240 stores, if every store adopted all three fixes at once, the gain would be ₹15 to ₹62 crore a month (central ₹32 crore).

## Risks

- **The cost split is an assumption.** Companies do not publish how cost divides into delivery, picking and fixed lines. The ranking of fixes depends on that split.
- **Gradual rollout.** The ranges assume steady state in every store at once; a real rollout would deliver less early.
- **Store level only.** Central costs are excluded. Swiggy states that company break-even needs about ₹30 contribution per order, and the model's store is at −₹7.08.
- **Untested side effects.** Bundling, delivery-cost cuts and volume growth might each affect margin, on-time delivery or capacity. The model does not test this.

## What real data would be needed to confirm

1. Cost per order by line (rider cost by distance and hour, picking labour), not the split assumed here
2. Store-level rent and staffing costs
3. Results of a bundling test against a control group
4. Delivery cost by zone, to test whether a cut is possible
5. True first-order dates, to measure repeat behaviour properly

Supporting files: `excel/quick_commerce_model.xlsx`, `docs/day3_findings.md`, `docs/day4_scenarios.md`.
