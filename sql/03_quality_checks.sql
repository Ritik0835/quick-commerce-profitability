-- 03_quality_checks.sql
-- Run from the repo root:  psql -d quick_commerce -f sql/03_quality_checks.sql
--
-- QUESTION: Is the loaded data internally consistent enough to analyse?
-- APPROACH: Each check counts the rows that break one rule. 0 violations = PASS.
--           Expected counts and hours are read from the assumptions table, not typed in.
-- FINDING:  see the comment at the bottom of this file (filled in after the run).

SELECT check_name,
       violations,
       CASE WHEN violations = 0 THEN 'PASS' ELSE 'FAIL' END AS status
FROM (

    -- Volume and coverage ---------------------------------------------------------
    SELECT '01 order count equals S01' AS check_name,
           CASE WHEN (SELECT COUNT(*) FROM orders)
                   = (SELECT CAST(value AS NUMERIC) FROM assumptions WHERE id = 'S01')
                THEN 0 ELSE 1 END AS violations
    UNION ALL
    SELECT '02 distinct order dates equal S03',
           CASE WHEN (SELECT COUNT(DISTINCT order_date) FROM orders)
                   = (SELECT CAST(value AS NUMERIC) FROM assumptions WHERE id = 'S03')
                THEN 0 ELSE 1 END
    UNION ALL
    SELECT '03 every store has orders on every date',
           (SELECT COUNT(*) FROM dark_stores) * (SELECT COUNT(DISTINCT order_date) FROM orders)
           - (SELECT COUNT(*) FROM (SELECT DISTINCT store_id, order_date FROM orders) AS store_days)

    -- Links between tables --------------------------------------------------------
    UNION ALL
    SELECT '04 orders without a delivery log',
           COUNT(*) FROM orders o LEFT JOIN delivery_logs d ON d.order_id = o.order_id
           WHERE d.order_id IS NULL
    UNION ALL
    SELECT '05 delivery log store differs from order store',
           COUNT(*) FROM orders o JOIN delivery_logs d ON d.order_id = o.order_id
           WHERE d.store_id <> o.store_id
    UNION ALL
    SELECT '06 delivery log time differs from order time',
           COUNT(*) FROM orders o JOIN delivery_logs d ON d.order_id = o.order_id
           WHERE d.order_ts <> o.order_ts
    UNION ALL
    SELECT '07 delivery log rain flag differs from order rain flag',
           COUNT(*) FROM orders o JOIN delivery_logs d ON d.order_id = o.order_id
           WHERE d.rain_delayed <> o.rain_delayed
    UNION ALL
    SELECT '08 customers ordering from a store other than their home store',
           COUNT(*) FROM orders o JOIN customers c ON c.customer_id = o.customer_id
           WHERE c.home_store_id <> o.store_id
    UNION ALL
    SELECT '09 customers ordering from a store outside their home city',
           COUNT(*) FROM orders o
           JOIN customers c ON c.customer_id = o.customer_id
           JOIN dark_stores s ON s.store_id = o.store_id
           WHERE c.home_city <> s.city
    UNION ALL
    SELECT '10 order value differs from the sum of its item lines (over 0.01)',
           COUNT(*) FROM orders o
           JOIN (SELECT order_id, SUM(line_total_inr) AS items_total FROM order_items GROUP BY order_id) i
             ON i.order_id = o.order_id
           WHERE ABS(o.order_value_inr - i.items_total) > 0.01

    -- Dates, hours and times ------------------------------------------------------
    UNION ALL
    SELECT '11 order_date differs from the date in order_ts',
           COUNT(*) FROM orders WHERE order_date <> DATE(order_ts)
    UNION ALL
    SELECT '12 orders outside opening hours (S31 to S32)',
           COUNT(*) FROM orders
           WHERE order_hour < (SELECT CAST(value AS NUMERIC) FROM assumptions WHERE id = 'S31')
              OR order_hour > (SELECT CAST(value AS NUMERIC) FROM assumptions WHERE id = 'S32')
    UNION ALL
    SELECT '13 cancelled orders with a dispatch or delivery time',
           COUNT(*) FROM orders o JOIN delivery_logs d ON d.order_id = o.order_id
           WHERE o.order_status = 'cancelled'
             AND (d.dispatch_ts IS NOT NULL OR d.delivered_ts IS NOT NULL)
    UNION ALL
    SELECT '14 delivered orders missing a dispatch or delivery time',
           COUNT(*) FROM orders o JOIN delivery_logs d ON d.order_id = o.order_id
           WHERE o.order_status = 'delivered'
             AND (d.dispatch_ts IS NULL OR d.delivered_ts IS NULL)
    UNION ALL
    SELECT '15 deliveries where times run backwards',
           COUNT(*) FROM delivery_logs
           WHERE dispatch_ts < order_ts OR delivered_ts < dispatch_ts

    -- Money -----------------------------------------------------------------------
    UNION ALL
    SELECT '16 delivered orders with a missing revenue or cost value',
           COUNT(*) FROM orders o JOIN delivery_logs d ON d.order_id = o.order_id
           WHERE o.order_status = 'delivered'
             AND (o.product_margin_inr IS NULL OR o.ad_income_inr IS NULL
                  OR o.customer_fee_inr IS NULL OR o.platform_discount_inr IS NULL
                  OR o.picking_packing_cost_inr IS NULL OR o.payment_cost_inr IS NULL
                  OR d.rider_payout_inr IS NULL)
    UNION ALL
    SELECT '17 cancelled or returned orders carrying revenue or cost',
           COUNT(*) FROM orders o JOIN delivery_logs d ON d.order_id = o.order_id
           WHERE o.order_status <> 'delivered'
             AND (o.product_margin_inr <> 0 OR o.ad_income_inr <> 0 OR o.customer_fee_inr <> 0
                  OR o.platform_discount_inr <> 0 OR o.picking_packing_cost_inr <> 0
                  OR o.payment_cost_inr <> 0 OR d.rider_payout_inr <> 0)
    UNION ALL
    SELECT '18 delivered orders with a rider payout of zero',
           COUNT(*) FROM orders o JOIN delivery_logs d ON d.order_id = o.order_id
           WHERE o.order_status = 'delivered' AND d.rider_payout_inr <= 0
    UNION ALL
    SELECT '19 mean delivered order value more than 2 INR from anchor I01',
           CASE WHEN ABS((SELECT AVG(order_value_inr) FROM orders WHERE order_status = 'delivered')
                       - (SELECT CAST(value AS NUMERIC) FROM assumptions WHERE id = 'I01')) > 2
                THEN 1 ELSE 0 END

    -- Event flags -----------------------------------------------------------------
    UNION ALL
    SELECT '20 stockout-affected orders outside a stockout period',
           COUNT(*) FROM orders WHERE stockout_affected = TRUE AND stockout_period <> 'YES'
    UNION ALL
    SELECT '21 rain-delayed orders outside a rain-delay period',
           COUNT(*) FROM orders WHERE rain_delayed = TRUE AND rain_delay_period <> 'YES'

) AS checks
ORDER BY check_name;

-- FINDING (run on the regenerated dataset): all 21 checks PASS.
-- Checks 20 and 21 only confirm that the flags agree with each other. They do not prove
-- stockouts or rain happened in the real world: the generator wrote both flags.
