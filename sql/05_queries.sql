-- 05_queries.sql
-- Run from the repo root:  psql -d quick_commerce -f sql/05_queries.sql
-- Window-function queries on the views from 04_views.sql. All figures are INR.
-- Contribution after fixed cost uses the store's daily fixed cost spread equally over that
-- store-day's delivered orders. Every query keeps its question, approach and finding together.

-- ======================================================================================
-- Q1  Store ranking
-- QUESTION: Which stores lose the least per order, and why do they differ?
-- APPROACH: Sum each store's store-days, divide by delivered orders, then RANK() the stores
--           by contribution per order. Orders per day and fixed cost per order are shown
--           because they explain most of the spread.
-- FINDING:  No store breaks even. Contribution per order runs from -1.00 (STORE_009) to -21.58 (STORE_002).
--           CM2 per order is almost the same everywhere (19.27 to 20.13) and on-time % is flat
--           (84.5 to 85.4), so the whole spread comes from fixed cost per order (20.95 to 41.37).
--           Big stores with few orders lose most: STORE_002 has 3,457 sq ft and 46 orders a day.
--           CAUTION: the generator sets fixed cost by store size and draws demand separately,
--           so this recovers a built-in rule. It is not evidence about real stores.
-- ======================================================================================
SELECT RANK() OVER (ORDER BY SUM(store_contribution_inr) / SUM(delivered_orders) DESC) AS rank,
       store_id,
       city,
       SUM(delivered_orders) AS delivered_orders,
       ROUND(1.0 * SUM(delivered_orders) / COUNT(*), 1) AS orders_per_day,
       ROUND(SUM(cm2_inr) / SUM(delivered_orders), 2) AS cm2_per_order,
       ROUND(SUM(fixed_cost_inr) / SUM(delivered_orders), 2) AS fixed_cost_per_order,
       ROUND(SUM(store_contribution_inr) / SUM(delivered_orders), 2) AS contribution_per_order,
       ROUND(SUM(store_contribution_inr), 0) AS total_contribution,
       ROUND(100.0 * SUM(on_time_orders) / SUM(delivered_orders), 1) AS on_time_pct
FROM v_store_day_pnl
GROUP BY store_id, city
ORDER BY rank;

-- ======================================================================================
-- Q2  Profitability by hour of day (all stores)
-- QUESTION: Do some hours earn more per order than others?
-- APPROACH: Join each delivered order to its store-day, spread the store's daily fixed cost
--           equally over that day's orders, then average by hour. A window function adds
--           each hour's share of all orders and its rank.
-- FINDING:  Five hours (12, 13, 18, 19, 20) carry about 51% of all orders, but contribution per
--           order does not follow them: it ranges only from -7.64 (15:00) to -6.62 (18:00), and the
--           peak hours rank 1, 9, 11, 12 and 13 of 15. On-time % is flat (83.7 to 86.1).
--           The gaps are about 1 INR and look like noise. The generator makes order VOLUME
--           peak at those hours but does not change margins or delivery time by hour.
-- ======================================================================================
WITH order_alloc AS (
    SELECT o.*, p.fixed_cost_inr / p.delivered_orders AS fixed_alloc_inr
    FROM v_order_cm o
    JOIN v_store_day_pnl p ON p.store_id = o.store_id AND p.order_date = o.order_date
)
SELECT order_hour,
       COUNT(*) AS delivered_orders,
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1) AS share_of_orders_pct,
       ROUND(AVG(cm2_inr), 2) AS cm2_per_order,
       ROUND(AVG(fixed_alloc_inr), 2) AS fixed_cost_per_order,
       ROUND(AVG(cm2_inr - fixed_alloc_inr), 2) AS contribution_per_order,
       ROUND(100.0 * AVG(on_time), 1) AS on_time_pct,
       RANK() OVER (ORDER BY AVG(cm2_inr - fixed_alloc_inr) DESC) AS rank
FROM order_alloc
GROUP BY order_hour
ORDER BY order_hour;

-- ======================================================================================
-- Q3  Best and worst hour for each store
-- QUESTION: Within each store, which hour earns most per order and which earns least?
-- APPROACH: Contribution per order by store and hour, ranked twice inside each store
--           (best first and worst first). Only rank 1 of each is kept.
-- FINDING:  Best and worst hours differ from store to store with no pattern, and within a store the
--           gap is 2 to 5 INR per order on only 300 to 1,100 orders per hour. Only two store-hours
--           are above zero (STORE_008 at 09:00 and STORE_009 at 10:00, both under +1 INR).
--           With no hour effect in the generator, treat these as sampling noise.
-- ======================================================================================
WITH order_alloc AS (
    SELECT o.*, p.fixed_cost_inr / p.delivered_orders AS fixed_alloc_inr
    FROM v_order_cm o
    JOIN v_store_day_pnl p ON p.store_id = o.store_id AND p.order_date = o.order_date
),
store_hour AS (
    SELECT store_id,
           order_hour,
           COUNT(*) AS delivered_orders,
           AVG(cm2_inr - fixed_alloc_inr) AS contribution_per_order
    FROM order_alloc
    GROUP BY store_id, order_hour
),
ranked AS (
    SELECT *,
           RANK() OVER (PARTITION BY store_id ORDER BY contribution_per_order DESC) AS best_rank,
           RANK() OVER (PARTITION BY store_id ORDER BY contribution_per_order ASC) AS worst_rank
    FROM store_hour
)
SELECT store_id,
       CASE WHEN best_rank = 1 THEN 'best hour' ELSE 'worst hour' END AS which_hour,
       order_hour,
       delivered_orders,
       ROUND(contribution_per_order, 2) AS contribution_per_order
FROM ranked
WHERE best_rank = 1 OR worst_rank = 1
ORDER BY store_id, which_hour;

-- ======================================================================================
-- Q4  Running total and 7-day average (whole network)
-- QUESTION: How do losses build up over time, and is the loss per order improving?
-- APPROACH: Add up all stores per date, then a window function gives the running total
--           of contribution and a 7-day moving average of the daily contribution per order.
-- FINDING:  The network loses 683,493 INR over 180 days, and the loss grows steadily. Only 17 of
--           180 days are profitable overall, and 19.4% of store-days are. Weekends lose far less
--           per order (-1.71) than weekdays (-10.04) because they carry 658 orders a day against
--           486, which spreads the same fixed cost further. The loss per order improves slowly,
--           from -7.40 in the first 28 days to -6.96 in the last 28, as orders grow.
--           CAUTION: the weekend uplift and the order growth are built into the generator.
-- ======================================================================================
WITH daily AS (
    SELECT order_date,
           day_type,
           SUM(delivered_orders) AS delivered_orders,
           SUM(store_contribution_inr) AS contribution_inr
    FROM v_store_day_pnl
    GROUP BY order_date, day_type
)
SELECT order_date,
       day_type,
       delivered_orders,
       ROUND(contribution_inr, 0) AS contribution_inr,
       ROUND(SUM(contribution_inr) OVER (ORDER BY order_date), 0) AS running_total_inr,
       ROUND(AVG(contribution_inr / delivered_orders)
             OVER (ORDER BY order_date ROWS BETWEEN 6 PRECEDING AND CURRENT ROW), 2) AS contribution_per_order_7d_avg
FROM daily
ORDER BY order_date;
