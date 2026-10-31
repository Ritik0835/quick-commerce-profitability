-- 04_views.sql
-- Run from the repo root:  psql -d quick_commerce -f sql/04_views.sql
-- Definitions follow docs/metric_definitions.md (the same CM1 / CM2 as the Excel model).
--
-- v_order_cm : one row per DELIVERED order, with CM1 and CM2.
-- v_store_day_pnl : one row per store per date, with the store's daily fixed cost charged once.

DROP VIEW IF EXISTS v_store_day_pnl;
DROP VIEW IF EXISTS v_order_cm;

-- v_order_cm
-- QUESTION: How much does each delivered order earn after product cost and discounts (CM1),
--           and after the cost of fulfilling it (CM2)?
-- APPROACH: CM1 = product margin + ad income + customer fee - platform discount.
--           CM2 = CM1 - picking and packing - rider payout - payment cost.
--           Cancelled and returned orders are excluded: they carry no revenue or cost here.
--           on_time uses the S39 threshold from the assumptions table.
-- FINDING:  average CM1 is about 87.42 and average CM2 about 19.76 INR per delivered order,
--           matching the Excel model's CM1 and CM2 by construction.
CREATE VIEW v_order_cm AS
SELECT t.*,
       t.cm1_inr - t.picking_packing_cost_inr - t.rider_payout_inr - t.payment_cost_inr AS cm2_inr
FROM (
    SELECT o.order_id,
           o.customer_id,
           o.store_id,
           o.order_ts,
           o.order_date,
           o.order_hour,
           o.day_type,
           o.order_value_inr,
           o.product_margin_inr,
           o.ad_income_inr,
           o.customer_fee_inr,
           o.platform_discount_inr,
           o.product_margin_inr + o.ad_income_inr + o.customer_fee_inr
               - o.platform_discount_inr AS cm1_inr,
           o.picking_packing_cost_inr,
           d.rider_payout_inr,
           o.payment_cost_inr,
           d.delivery_duration_minutes,
           CASE WHEN d.delivery_duration_minutes
                     <= (SELECT CAST(value AS NUMERIC) FROM assumptions WHERE id = 'S39')
                THEN 1 ELSE 0 END AS on_time,
           CASE WHEN o.rain_delayed THEN 1 ELSE 0 END AS rain_delayed_flag,
           CASE WHEN o.stockout_affected THEN 1 ELSE 0 END AS stockout_affected_flag
    FROM orders o
    JOIN delivery_logs d ON d.order_id = o.order_id
    WHERE o.order_status = 'delivered'
) AS t;

-- v_store_day_pnl
-- QUESTION: What does each store earn or lose on each day?
-- APPROACH: Start from every store x every date, so a day with no delivered orders still
--           carries the store's fixed cost. Add up the order-level view per store-day,
--           then store contribution = CM2 - the store's daily fixed cost (charged once).
-- FINDING:  see the check queries after this file; contribution per delivered order is
--           about -7.08 INR, the same as the Excel model.
CREATE VIEW v_store_day_pnl AS
SELECT s.store_id,
       s.store_name,
       s.city,
       cal.order_date,
       cal.day_type,
       COALESCE(a.delivered_orders, 0) AS delivered_orders,
       COALESCE(a.order_value_inr, 0) AS order_value_inr,
       COALESCE(a.product_margin_inr, 0) AS product_margin_inr,
       COALESCE(a.ad_income_inr, 0) AS ad_income_inr,
       COALESCE(a.customer_fee_inr, 0) AS customer_fee_inr,
       COALESCE(a.platform_discount_inr, 0) AS platform_discount_inr,
       COALESCE(a.cm1_inr, 0) AS cm1_inr,
       COALESCE(a.picking_packing_cost_inr, 0) AS picking_packing_cost_inr,
       COALESCE(a.rider_payout_inr, 0) AS rider_payout_inr,
       COALESCE(a.payment_cost_inr, 0) AS payment_cost_inr,
       COALESCE(a.cm2_inr, 0) AS cm2_inr,
       s.daily_fixed_cost_inr AS fixed_cost_inr,
       COALESCE(a.cm2_inr, 0) - s.daily_fixed_cost_inr AS store_contribution_inr,
       COALESCE(a.on_time_orders, 0) AS on_time_orders,
       COALESCE(a.rain_delayed_orders, 0) AS rain_delayed_orders,
       COALESCE(a.stockout_affected_orders, 0) AS stockout_affected_orders
FROM dark_stores s
CROSS JOIN (SELECT DISTINCT order_date, day_type FROM orders) AS cal
LEFT JOIN (
    SELECT store_id,
           order_date,
           COUNT(*) AS delivered_orders,
           SUM(order_value_inr) AS order_value_inr,
           SUM(product_margin_inr) AS product_margin_inr,
           SUM(ad_income_inr) AS ad_income_inr,
           SUM(customer_fee_inr) AS customer_fee_inr,
           SUM(platform_discount_inr) AS platform_discount_inr,
           SUM(cm1_inr) AS cm1_inr,
           SUM(picking_packing_cost_inr) AS picking_packing_cost_inr,
           SUM(rider_payout_inr) AS rider_payout_inr,
           SUM(payment_cost_inr) AS payment_cost_inr,
           SUM(cm2_inr) AS cm2_inr,
           SUM(on_time) AS on_time_orders,
           SUM(rain_delayed_flag) AS rain_delayed_orders,
           SUM(stockout_affected_flag) AS stockout_affected_orders
    FROM v_order_cm
    GROUP BY store_id, order_date
) AS a ON a.store_id = s.store_id AND a.order_date = cal.order_date;
