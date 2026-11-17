-- 09_break_even.sql
-- Run from the repository root after 01_schema.sql, 02_load.sql and 04_views.sql:
--     psql -v ON_ERROR_STOP=1 -d quick_commerce -f sql/09_break_even.sql
--
-- QUESTION: How many orders per store per day are needed to break even, and which
--           single lever closes the gap with the smallest move?
-- APPROACH: Rebuild the Excel model's building blocks from data/assumptions.csv:
--           adjusted revenue and GOV per delivered order, the reported contribution
--           margin, and the synthetic cost shares (S22 to S27). The synthetic stores
--           handle about 54 orders a day, so fixed cost is also scaled by I11
--           (1,192) to show the corresponding real-store figures.
-- FINDING:  Synthetic break-even is 72.8 orders/store/day. Scaled to a real store it
--           is 1,619.2 (+35.8%); the equivalent single-lever moves are AOV +13.7%,
--           delivery cost -16.5%, ad income +35.3%, and volume +35.8%. For a 10%
--           favourable change the impact ranking is AOV, delivery, ads, volume.
-- CAUTION:  These are modeled scenarios. The cost split is a synthetic assumption
--           (see docs/data_note.md), not a company disclosure.

DROP VIEW IF EXISTS v_lever_sensitivity;
DROP VIEW IF EXISTS v_break_even;
DROP VIEW IF EXISTS v_break_even_base;

-- Unrounded building blocks, shared by the two presentation views.
CREATE VIEW v_break_even_base AS
WITH base AS (
    SELECT
        (SELECT CAST(value AS NUMERIC) FROM assumptions WHERE id = 'I03') * 10000000
            / ((SELECT CAST(value AS NUMERIC) FROM assumptions WHERE id = 'I02') * 1000000) AS gov_per_order,
        (SELECT CAST(value AS NUMERIC) FROM assumptions WHERE id = 'I17') * 10000000
            / ((SELECT CAST(value AS NUMERIC) FROM assumptions WHERE id = 'I02') * 1000000) AS adjusted_revenue_per_order,
        (SELECT CAST(value AS NUMERIC) FROM assumptions WHERE id = 'I01') AS aov_inr,
        (SELECT CAST(value AS NUMERIC) FROM assumptions WHERE id = 'I07') AS contribution_margin_pct_gov,
        (SELECT CAST(value AS NUMERIC) FROM assumptions WHERE id = 'I11') AS base_orders_per_store_day,
        (SELECT CAST(value AS NUMERIC) FROM assumptions WHERE id = 'S22') AS product_margin_share,
        (SELECT CAST(value AS NUMERIC) FROM assumptions WHERE id = 'S23') AS ad_share,
        (SELECT CAST(value AS NUMERIC) FROM assumptions WHERE id = 'S24') AS discount_share,
        (SELECT CAST(value AS NUMERIC) FROM assumptions WHERE id = 'S25') AS delivery_share,
        (SELECT CAST(value AS NUMERIC) FROM assumptions WHERE id = 'S26') AS picking_share,
        (SELECT CAST(value AS NUMERIC) FROM assumptions WHERE id = 'S27') AS payment_share
),
lines AS (
    SELECT base.*,
           contribution_margin_pct_gov / 100 * gov_per_order AS reported_contribution_per_order,
           adjusted_revenue_per_order
               - contribution_margin_pct_gov / 100 * gov_per_order AS all_in_cost_per_order
    FROM base
),
costs AS (
    SELECT lines.*,
           product_margin_share * adjusted_revenue_per_order AS product_margin_inr,
           ad_share * adjusted_revenue_per_order AS ad_income_inr,
           (1 - product_margin_share - ad_share) * adjusted_revenue_per_order AS customer_fee_inr,
           discount_share * all_in_cost_per_order AS platform_discount_inr,
           delivery_share * all_in_cost_per_order AS delivery_cost_inr,
           picking_share * all_in_cost_per_order AS picking_cost_inr,
           payment_share * all_in_cost_per_order AS payment_cost_inr,
           (1 - discount_share - delivery_share - picking_share - payment_share)
               * all_in_cost_per_order AS fixed_cost_per_order
    FROM lines
),
metrics AS (
    SELECT costs.*,
           product_margin_inr + ad_income_inr + customer_fee_inr
               - platform_discount_inr - picking_cost_inr - delivery_cost_inr
               - payment_cost_inr AS cm2_per_order,
           (product_margin_inr - payment_cost_inr)
               / NULLIF(aov_inr, 0) AS cm2_per_aov_inr
    FROM costs
)
SELECT metrics.*,
       fixed_cost_per_order * base_orders_per_store_day AS fixed_cost_per_store_day,
       (cm2_per_order - fixed_cost_per_order) * base_orders_per_store_day
           AS contribution_per_store_day,
       fixed_cost_per_order * base_orders_per_store_day / NULLIF(cm2_per_order, 0)
           AS break_even_orders_per_store_day,
       fixed_cost_per_order - cm2_per_order AS gap_per_order
FROM metrics;

-- Presentation view: break-even, single-lever moves and the scaled real-store view.
CREATE VIEW v_break_even AS
SELECT
    ROUND(gov_per_order, 2) AS gov_per_order_inr,
    ROUND(adjusted_revenue_per_order, 2) AS adjusted_revenue_per_order_inr,
    ROUND(all_in_cost_per_order, 2) AS all_in_cost_per_order_inr,
    ROUND(aov_inr, 2) AS base_aov_inr,
    ROUND(base_orders_per_store_day, 2) AS base_orders_per_store_day,
    ROUND(product_margin_inr, 2) AS product_margin_inr,
    ROUND(ad_income_inr, 2) AS ad_income_inr,
    ROUND(customer_fee_inr, 2) AS customer_fee_inr,
    ROUND(platform_discount_inr, 2) AS platform_discount_inr,
    ROUND(delivery_cost_inr, 2) AS delivery_cost_inr,
    ROUND(picking_cost_inr, 2) AS picking_cost_inr,
    ROUND(payment_cost_inr, 2) AS payment_cost_inr,
    ROUND(fixed_cost_per_order, 2) AS fixed_cost_per_order_inr,
    ROUND(fixed_cost_per_store_day, 2) AS fixed_cost_per_store_day_inr,
    ROUND(cm2_per_order, 2) AS cm2_per_order_inr,
    ROUND(cm2_per_order - fixed_cost_per_order, 2) AS contribution_per_order_inr,
    ROUND(contribution_per_store_day, 2) AS contribution_per_store_day_inr,
    ROUND(break_even_orders_per_store_day, 2) AS break_even_orders_per_store_day,
    ROUND(break_even_orders_per_store_day - base_orders_per_store_day, 2)
        AS extra_orders_per_store_day,
    ROUND(break_even_orders_per_store_day / NULLIF(base_orders_per_store_day, 0) - 1, 4)
        AS required_volume_change_pct,
    ROUND(aov_inr + gap_per_order / NULLIF(cm2_per_aov_inr, 0), 2)
        AS break_even_aov_inr,
    ROUND((aov_inr + gap_per_order / NULLIF(cm2_per_aov_inr, 0))
          / NULLIF(aov_inr, 0) - 1, 4) AS required_aov_change_pct,
    ROUND(delivery_cost_inr - gap_per_order, 2) AS break_even_delivery_cost_inr,
    ROUND((delivery_cost_inr - gap_per_order)
          / NULLIF(delivery_cost_inr, 0) - 1, 4) AS required_delivery_change_pct,
    ROUND(ad_income_inr + gap_per_order, 2) AS break_even_ad_income_inr,
    ROUND((ad_income_inr + gap_per_order)
          / NULLIF(ad_income_inr, 0) - 1, 4) AS required_ad_change_pct
FROM v_break_even_base;

-- Sensitivity view: effect of one favourable 10% move, with the Excel ranking.
CREATE VIEW v_lever_sensitivity AS
WITH impacts AS (
    SELECT 'order value +10%' AS lever,
           base_orders_per_store_day * (product_margin_inr - payment_cost_inr) * 0.10
               AS daily_impact_inr
    FROM v_break_even_base
    UNION ALL
    SELECT 'delivery cost -10%',
           base_orders_per_store_day * delivery_cost_inr * 0.10
    FROM v_break_even_base
    UNION ALL
    SELECT 'ad income +10%',
           base_orders_per_store_day * ad_income_inr * 0.10
    FROM v_break_even_base
    UNION ALL
    SELECT 'orders per day +10%',
           base_orders_per_store_day * cm2_per_order * 0.10
    FROM v_break_even_base
)
SELECT lever,
       ROUND(daily_impact_inr, 2) AS daily_impact_inr,
       ROUND(daily_impact_inr
             / NULLIF(-(SELECT contribution_per_store_day FROM v_break_even_base), 0), 4)
           AS share_of_loss_closed_pct,
       RANK() OVER (ORDER BY daily_impact_inr DESC) AS impact_rank
FROM impacts;

-- Fail loudly if the model drifts from the values documented in docs/day3_findings.md.
DO $$
DECLARE
    v NUMERIC;
    t TEXT;
BEGIN
    SELECT break_even_orders_per_store_day INTO v FROM v_break_even;
    IF ABS(v - 1619.23) > 0.05 THEN
        RAISE EXCEPTION 'break-even orders: expected 1619.23, found %', v;
    END IF;

    SELECT required_volume_change_pct INTO v FROM v_break_even;
    IF ABS(v - 0.3584) > 0.001 THEN
        RAISE EXCEPTION 'volume change: expected 0.3584, found %', v;
    END IF;

    SELECT required_aov_change_pct INTO v FROM v_break_even;
    IF ABS(v - 0.1373) > 0.001 THEN
        RAISE EXCEPTION 'AOV change: expected 0.1373, found %', v;
    END IF;

    SELECT required_delivery_change_pct INTO v FROM v_break_even;
    IF ABS(v - (-0.1649)) > 0.001 THEN
        RAISE EXCEPTION 'delivery change: expected -0.1649, found %', v;
    END IF;

    SELECT required_ad_change_pct INTO v FROM v_break_even;
    IF ABS(v - 0.3531) > 0.001 THEN
        RAISE EXCEPTION 'ad change: expected 0.3531, found %', v;
    END IF;

    SELECT STRING_AGG(lever, '|' ORDER BY impact_rank) INTO t
    FROM v_lever_sensitivity;
    IF t <> 'order value +10%|delivery cost -10%|ad income +10%|orders per day +10%' THEN
        RAISE EXCEPTION 'unexpected lever ranking: %', t;
    END IF;

    RAISE NOTICE 'Break-even and lever assertions passed.';
END $$;
