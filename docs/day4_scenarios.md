# Day 4: scenarios (modeled ranges, not measurements)

Source: `excel/quick_commerce_model.xlsx`, sheet **Scenarios**. The store is synthetic and calibrated to Swiggy Instamart's Q2 FY27 totals. Each fix has a low, central and high case. Central cases for fixes 1 and 2 equal movements Instamart actually reported; fix 3 and all low and high cases are judgement ranges on the Assumptions sheet (section 10).

## Base case
Each store loses about INR 2.53 lakh per month (INR 7.08 per order, INR 8,444 per day). Across Instamart's 1,240 stores that is about INR 31.4 crore per month.

## The three fixes (change vs base case)

| Fix | Low | Central | High |
|---|---:|---:|---:|
| 1. Bundling raises order value | +2.0% | +4.3% | +8.0% |
| 2. More orders per store per day | +5.0% | +9.5% | +20.0% |
| 3. Lower delivery cost per order | -3.0% | -6.0% | -10.0% |

## Improvement in contribution, per store per month

| Scenario | Low | Central | High |
|---|---:|---:|---:|
| Fix 1 alone | INR 36,899 | INR 79,333 | INR 147,597 |
| Fix 2 alone | INR 35,338 | INR 67,142 | INR 141,352 |
| Fix 3 alone | INR 46,083 | INR 92,167 | INR 153,612 |
| **All three together** | **INR 122,470** | **INR 254,935** | **INR 502,803** |

## Across 1,240 stores (all stores in the rollout), all three together
INR 15.2 to INR 62.3 crore per month (central INR 31.6 crore), or INR 182 to INR 748 crore per year (central INR 379 crore).

## What the range says
- **Low case:** the store still loses about INR 4,361 per day. The fixes close roughly half the gap.
- **Central case:** the store lands almost exactly at break-even (about +INR 54 per day), which is knife-edge, not a profit.
- **High case:** the store earns about INR 8,316 per day.

## Caveats
- Improvements are steady state and applied to every store in the rollout at once. Real rollouts are gradual, so near-term results would be smaller. The rollout share on the Assumptions sheet (SC8) lets you test a partial rollout.
- Fixed store cost per day does not change when volume rises. Central costs, one-time costs of bundling or automation, and cannibalisation are excluded.
- The fixes multiply together, so the combined result is not the sum of the three single-fix results.
- The size of each fix is judgement except the two anchored central cases. The split of costs across lines is also a synthetic allocation (Assumptions section 3).
