-- 07_reconcile.sql
-- Run from the repo root:  psql -d quick_commerce -f sql/07_reconcile.sql
--
-- QUESTION: Do the per-order and store-day numbers in SQL match the Excel model?
-- APPROACH: data/excel_reference.csv holds the Excel values with their sheet and cell address.
--           This script loads it, rebuilds the same lines from the SQL views, and compares.
--           Per-order lines come from v_order_cm (fixed cost and contribution from
--           v_store_day_pnl). Store-day lines are SQL store-day totals scaled up to Excel's
--           orders per day, because the synthetic stores are about 4.5% of a real store's size.
--           Tolerances are S41 (per-order lines) and S42 (order value after adding back the
--           stockout cut), both in INR per order. Costs carry a minus sign, as in Excel.
-- FINDING:  25 of 27 comparisons match within tolerance. Both gaps are order value (per order 505.19
--           vs 506.00; store-day 602,186 vs 603,152) and have one cause: stockouts cut the value of
--           1.2% of orders by 12% (S12), worth 0.73 INR per order. Adding it back gives 505.92,
--           within 0.08 of Excel. CM1, CM2, fixed cost and store contribution all match
--           (contribution -7.08 per order, -8,445 vs -8,444 per scaled store-day).
--           CAUTION: the generator was calibrated to the same assumptions, so agreement is
--           expected. This shows the data pipeline and the views preserve the model's economics
--           and compute CM1 and CM2 as defined. It does not validate the economics themselves.

DROP TABLE IF EXISTS excel_reference;
CREATE TABLE excel_reference (
    id TEXT PRIMARY KEY,
    level TEXT NOT NULL,
    line TEXT NOT NULL,
    sheet TEXT,
    cell TEXT,
    excel_value NUMERIC NOT NULL
);
\copy excel_reference FROM 'data/excel_reference.csv' WITH (FORMAT csv, HEADER true)

WITH o AS (
    SELECT COUNT(*) AS n,
           SUM(order_value_inr) AS nov,
           SUM(product_margin_inr) AS pm,
           SUM(ad_income_inr) AS ad,
           SUM(customer_fee_inr) AS fee,
           SUM(platform_discount_inr) AS disc,
           SUM(cm1_inr) AS cm1,
           SUM(picking_packing_cost_inr) AS pick,
           SUM(rider_payout_inr) AS rider,
           SUM(payment_cost_inr) AS pay,
           SUM(cm2_inr) AS cm2,
           SUM(CASE WHEN stockout_affected_flag = 1 THEN order_value_inr ELSE 0 END) AS affected_value
    FROM v_order_cm
),
d AS (
    SELECT SUM(delivered_orders) AS n,
           SUM(order_value_inr) AS nov,
           SUM(product_margin_inr) AS pm,
           SUM(ad_income_inr) AS ad,
           SUM(customer_fee_inr) AS fee,
           SUM(platform_discount_inr) AS disc,
           SUM(cm1_inr) AS cm1,
           SUM(picking_packing_cost_inr) AS pick,
           SUM(rider_payout_inr) AS rider,
           SUM(payment_cost_inr) AS pay,
           SUM(cm2_inr) AS cm2,
           SUM(fixed_cost_inr) AS fixed,
           SUM(store_contribution_inr) AS contribution
    FROM v_store_day_pnl
),
cut AS (SELECT CAST(value AS NUMERIC) AS keep_share FROM assumptions WHERE id = 'S12'),
tol AS (
    SELECT (SELECT CAST(value AS NUMERIC) FROM assumptions WHERE id = 'S41') AS per_order,
           (SELECT CAST(value AS NUMERIC) FROM assumptions WHERE id = 'S42') AS aov,
           (SELECT excel_value FROM excel_reference WHERE id = 'SD00') AS excel_orders_per_day
),
sql_lines AS (
    SELECT 'per_order' AS level, 'nov' AS line, nov / n AS sql_value FROM o
    UNION ALL SELECT 'per_order', 'nov_before_stockout_cut',
           nov / n + affected_value * (1 / (SELECT keep_share FROM cut) - 1) / n FROM o
    UNION ALL SELECT 'per_order', 'product_margin', pm / n FROM o
    UNION ALL SELECT 'per_order', 'ad_income', ad / n FROM o
    UNION ALL SELECT 'per_order', 'customer_fee', fee / n FROM o
    UNION ALL SELECT 'per_order', 'revenue_after_product_cost', (pm + ad + fee) / n FROM o
    UNION ALL SELECT 'per_order', 'platform_discount', -disc / n FROM o
    UNION ALL SELECT 'per_order', 'cm1', cm1 / n FROM o
    UNION ALL SELECT 'per_order', 'picking_packing', -pick / n FROM o
    UNION ALL SELECT 'per_order', 'rider_payout', -rider / n FROM o
    UNION ALL SELECT 'per_order', 'payment_cost', -pay / n FROM o
    UNION ALL SELECT 'per_order', 'cm2', cm2 / n FROM o
    UNION ALL SELECT 'per_order', 'fixed_cost', -fixed / n FROM d
    UNION ALL SELECT 'per_order', 'store_contribution', contribution / n FROM d
    UNION ALL SELECT 'store_day', 'nov', nov * t.excel_orders_per_day / n FROM d CROSS JOIN tol t
    UNION ALL SELECT 'store_day', 'product_margin', pm * t.excel_orders_per_day / n FROM d CROSS JOIN tol t
    UNION ALL SELECT 'store_day', 'ad_income', ad * t.excel_orders_per_day / n FROM d CROSS JOIN tol t
    UNION ALL SELECT 'store_day', 'customer_fee', fee * t.excel_orders_per_day / n FROM d CROSS JOIN tol t
    UNION ALL SELECT 'store_day', 'revenue_after_product_cost', (pm + ad + fee) * t.excel_orders_per_day / n FROM d CROSS JOIN tol t
    UNION ALL SELECT 'store_day', 'platform_discount', -disc * t.excel_orders_per_day / n FROM d CROSS JOIN tol t
    UNION ALL SELECT 'store_day', 'cm1', cm1 * t.excel_orders_per_day / n FROM d CROSS JOIN tol t
    UNION ALL SELECT 'store_day', 'picking_packing', -pick * t.excel_orders_per_day / n FROM d CROSS JOIN tol t
    UNION ALL SELECT 'store_day', 'rider_payout', -rider * t.excel_orders_per_day / n FROM d CROSS JOIN tol t
    UNION ALL SELECT 'store_day', 'payment_cost', -pay * t.excel_orders_per_day / n FROM d CROSS JOIN tol t
    UNION ALL SELECT 'store_day', 'cm2', cm2 * t.excel_orders_per_day / n FROM d CROSS JOIN tol t
    UNION ALL SELECT 'store_day', 'fixed_cost', -fixed * t.excel_orders_per_day / n FROM d CROSS JOIN tol t
    UNION ALL SELECT 'store_day', 'store_contribution', contribution * t.excel_orders_per_day / n FROM d CROSS JOIN tol t
)
SELECT r.id,
       r.level,
       r.line,
       r.sheet || '!' || r.cell AS excel_cell,
       ROUND(s.sql_value, 2) AS sql_value,
       ROUND(r.excel_value, 2) AS excel_value,
       ROUND(s.sql_value - r.excel_value, 2) AS difference,
       CASE
           WHEN ABS(s.sql_value - r.excel_value) <=
                CASE WHEN r.line = 'nov_before_stockout_cut' THEN t.aov
                     WHEN r.level = 'per_order' THEN t.per_order
                     ELSE t.per_order * t.excel_orders_per_day END
           THEN 'OK' ELSE 'GAP' END AS status
FROM excel_reference r
JOIN sql_lines s ON s.level = r.level AND s.line = r.line
CROSS JOIN tol t
ORDER BY r.id;
