-- 06_kpis.sql
-- Run from the repo root:  psql -d quick_commerce -f sql/06_kpis.sql
-- KPI definitions: docs/metric_definitions.md. Thresholds come from the assumptions table
-- (S12 stockout value cut, S39 on-time minutes, S40 repeat window days). All figures are INR.

-- ======================================================================================
-- K1  KPI scorecard (whole network)
-- QUESTION: What are the headline numbers for the network?
-- APPROACH: Average the order-level view for AOV, CM1, CM2 and on-time %. Fixed cost per order
--           comes from the store-day view, because fixed cost is charged per store-day.
-- FINDING:  Each delivered order earns 19.76 INR after variable costs (CM2) but carries 26.85 INR of
--           fixed store cost, so the network loses 7.08 INR per order. AOV is 505.19 and on-time
--           % is 85.0. These agree with the Excel model by construction, not by independent check.
-- ======================================================================================
SELECT COUNT(*) AS delivered_orders,
       ROUND(AVG(order_value_inr), 2) AS aov_inr,
       ROUND(AVG(cm1_inr), 2) AS cm1_per_order,
       ROUND(AVG(cm2_inr), 2) AS cm2_per_order,
       (SELECT ROUND(SUM(fixed_cost_inr) / SUM(delivered_orders), 2) FROM v_store_day_pnl) AS fixed_cost_per_order,
       (SELECT ROUND(SUM(store_contribution_inr) / SUM(delivered_orders), 2) FROM v_store_day_pnl) AS contribution_per_order,
       ROUND(100.0 * AVG(on_time), 1) AS on_time_pct
FROM v_order_cm;

-- ======================================================================================
-- K2  KPIs on rain-delay orders versus other orders
-- QUESTION: What do rain-delayed deliveries do to on-time %, delivery time and margin?
-- APPROACH: Split the order-level view by the rain flag and compare averages.
-- FINDING:  Rain-delayed orders are 4.1% of deliveries (3,998 of 96,474) but take 18.0 minutes
--           against 12.1, and only 20.9% arrive on time against 87.7%. They cost 8.26 INR more in
--           rider payout, so CM2 falls from 20.10 to 12.07, about 32,000 INR across the period.
--           CAUTION: the generator adds minutes in rain and makes payout depend on minutes,
--           so this recovers a built-in rule.
-- ======================================================================================
SELECT CASE WHEN rain_delayed_flag = 1 THEN 'rain-delayed' ELSE 'other' END AS orders,
       COUNT(*) AS delivered_orders,
       ROUND(AVG(delivery_duration_minutes), 1) AS avg_delivery_minutes,
       ROUND(100.0 * AVG(on_time), 1) AS on_time_pct,
       ROUND(AVG(rider_payout_inr), 2) AS rider_payout_per_order,
       ROUND(AVG(cm2_inr), 2) AS cm2_per_order
FROM v_order_cm
GROUP BY rain_delayed_flag
ORDER BY rain_delayed_flag DESC;

-- ======================================================================================
-- K3  30-day repeat rate
-- QUESTION: Of customers with a full 30-day window after their first delivered order in the
--           data, what share ordered again within that window?
-- APPROACH: Take each customer's first delivered order. Keep customers whose first order is at
--           least S40 days before the last date in the data. A customer repeats if a later
--           delivered order falls within S40 days of the first. Shown by segment and overall.
--           The first order in the data is not the customer's true first order.
-- FINDING:  38.7% of eligible customers order again within 30 days (9,650 of 24,930). The rate is
--           86.6% for high-frequency customers, 39.6% for regular and 22.2% for new. CAUTION: the
--           generator picks high-frequency customers far more often (S33 to S35), so the segment
--           gap is built in. The first order in the data is also not a customer's true first order.
-- ======================================================================================
WITH params AS (
    SELECT CAST(value AS INTEGER) AS window_days FROM assumptions WHERE id = 'S40'
),
first_order AS (
    SELECT customer_id, MIN(order_ts) AS first_ts, MIN(order_date) AS first_date
    FROM v_order_cm
    GROUP BY customer_id
),
eligible AS (
    SELECT f.customer_id, f.first_ts, f.first_date
    FROM first_order f CROSS JOIN params p
    WHERE f.first_date + p.window_days <= (SELECT MAX(order_date) FROM orders)
),
repeat_flags AS (
    SELECT e.customer_id,
           MAX(CASE WHEN o.order_ts > e.first_ts
                     AND o.order_date - e.first_date <= p.window_days
                    THEN 1 ELSE 0 END) AS repeated
    FROM eligible e
    CROSS JOIN params p
    JOIN v_order_cm o ON o.customer_id = e.customer_id
    GROUP BY e.customer_id
)
SELECT c.customer_segment AS customers,
       COUNT(*) AS eligible_customers,
       SUM(r.repeated) AS repeat_customers,
       ROUND(100.0 * SUM(r.repeated) / COUNT(*), 1) AS repeat_rate_pct
FROM repeat_flags r
JOIN customers c ON c.customer_id = r.customer_id
GROUP BY c.customer_segment
UNION ALL
SELECT 'all customers',
       COUNT(*),
       SUM(repeated),
       ROUND(100.0 * SUM(repeated) / COUNT(*), 1)
FROM repeat_flags
ORDER BY 1;

-- ======================================================================================
-- K4  Stockout loss by store
-- QUESTION: How much order value do stockouts cost, and where?
-- APPROACH: For delivered orders flagged stockout_affected, lost value = order value x
--           (1 / S12 - 1), i.e. what the basket would have been without the cut.
--           A last row gives the network total.
-- FINDING:  Stockouts remove about 70,895 INR of order value over 180 days, 0.15% of delivered
--           value, from 1,166 affected orders (1.2% of deliveries). Stores range from 6,231 to
--           8,559 INR (0.13% to 0.17%), following their order counts. CAUTION: the loss only
--           recovers the built-in 12% cut (S12) applied during four stockout periods.
-- ======================================================================================
WITH cut AS (
    SELECT CAST(value AS NUMERIC) AS keep_share FROM assumptions WHERE id = 'S12'
),
by_store AS (
    SELECT o.store_id,
           COUNT(*) AS delivered_orders,
           SUM(o.stockout_affected_flag) AS affected_orders,
           SUM(o.order_value_inr) AS delivered_value_inr,
           SUM(CASE WHEN o.stockout_affected_flag = 1
                    THEN o.order_value_inr * (1 / c.keep_share - 1) ELSE 0 END) AS lost_value_inr
    FROM v_order_cm o CROSS JOIN cut c
    GROUP BY o.store_id
)
SELECT store_id,
       delivered_orders,
       affected_orders,
       lost_value_inr,
       lost_pct_of_value
FROM (
    SELECT store_id,
           delivered_orders,
           affected_orders,
           ROUND(lost_value_inr, 0) AS lost_value_inr,
           ROUND(100.0 * lost_value_inr / delivered_value_inr, 2) AS lost_pct_of_value,
           0 AS sort_group
    FROM by_store
    UNION ALL
    SELECT 'NETWORK',
           SUM(delivered_orders),
           SUM(affected_orders),
           ROUND(SUM(lost_value_inr), 0),
           ROUND(100.0 * SUM(lost_value_inr) / SUM(delivered_value_inr), 2),
           1
    FROM by_store
) AS t
ORDER BY sort_group, lost_value_inr DESC;
