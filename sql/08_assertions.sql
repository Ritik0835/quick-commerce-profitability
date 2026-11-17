-- 08_assertions.sql
-- Fail loudly if the loaded data or any headline metric drifts from the values
-- documented in README.md, docs/data_note.md and docs/day3_findings.md.
-- Run from the repository root after the load, views, quality checks and
-- break-even scripts:
--     psql -v ON_ERROR_STOP=1 -d quick_commerce -f sql/08_assertions.sql
--
-- Every check raises an exception, so psql exits non-zero on a failure.

DO $$
DECLARE
    n BIGINT;
    v NUMERIC;
    t TEXT;
BEGIN
    -- Source tables -----------------------------------------------------------------
    SELECT count(*) INTO n FROM assumptions;
    IF n <> 78 THEN
        RAISE EXCEPTION 'assumptions: expected 78 rows, found %', n;
    END IF;

    SELECT count(*) INTO n FROM dark_stores;
    IF n <> 10 THEN
        RAISE EXCEPTION 'dark stores: expected 10, found %', n;
    END IF;

    SELECT count(*) INTO n FROM customers;
    IF n <> 30000 THEN
        RAISE EXCEPTION 'customers: expected 30000, found %', n;
    END IF;

    SELECT count(*) INTO n FROM orders;
    IF n <> 100000 THEN
        RAISE EXCEPTION 'orders: expected 100000, found %', n;
    END IF;

    SELECT count(*) INTO n FROM orders WHERE order_status = 'delivered';
    IF n <> 96474 THEN
        RAISE EXCEPTION 'delivered orders: expected 96474, found %', n;
    END IF;

    SELECT count(*) INTO n FROM orders WHERE order_status = 'cancelled';
    IF n <> 2513 THEN
        RAISE EXCEPTION 'cancelled orders: expected 2513, found %', n;
    END IF;

    SELECT count(*) INTO n FROM orders WHERE order_status = 'returned';
    IF n <> 1013 THEN
        RAISE EXCEPTION 'returned orders: expected 1013, found %', n;
    END IF;

    SELECT count(*) INTO n FROM order_items;
    IF n <> 287810 THEN
        RAISE EXCEPTION 'order items: expected 287810, found %', n;
    END IF;

    SELECT count(*) INTO n FROM delivery_logs;
    IF n <> 100000 THEN
        RAISE EXCEPTION 'delivery logs: expected 100000, found %', n;
    END IF;

    SELECT count(DISTINCT order_date) INTO n FROM orders;
    IF n <> 180 THEN
        RAISE EXCEPTION 'order dates: expected 180, found %', n;
    END IF;

    -- Data-quality checks ------------------------------------------------------------
    SELECT count(*) INTO n FROM v_quality_checks;
    IF n <> 21 THEN
        RAISE EXCEPTION 'quality checks: expected 21, found %', n;
    END IF;

    SELECT count(*) INTO n FROM v_quality_checks WHERE violations <> 0;
    IF n <> 0 THEN
        RAISE EXCEPTION 'data-quality violations: expected 0, found % checks', n;
    END IF;

    -- Order-level and store-day metrics ----------------------------------------------
    SELECT count(*) INTO n FROM v_order_cm;
    IF n <> 96474 THEN
        RAISE EXCEPTION 'v_order_cm: expected 96474 rows, found %', n;
    END IF;

    SELECT round(avg(order_value_inr), 2) INTO v FROM v_order_cm;
    IF v <> 505.19 THEN
        RAISE EXCEPTION 'AOV: expected 505.19, found %', v;
    END IF;

    SELECT round(avg(cm1_inr), 2) INTO v FROM v_order_cm;
    IF v <> 87.42 THEN
        RAISE EXCEPTION 'CM1 per order: expected 87.42, found %', v;
    END IF;

    SELECT round(avg(cm2_inr), 2) INTO v FROM v_order_cm;
    IF v <> 19.76 THEN
        RAISE EXCEPTION 'CM2 per order: expected 19.76, found %', v;
    END IF;

    SELECT count(*) INTO n FROM v_store_day_pnl;
    IF n <> 1800 THEN
        RAISE EXCEPTION 'v_store_day_pnl: expected 1800 rows, found %', n;
    END IF;

    SELECT round(sum(fixed_cost_inr) / sum(delivered_orders), 2) INTO v
    FROM v_store_day_pnl;
    IF v <> 26.85 THEN
        RAISE EXCEPTION 'fixed cost per order: expected 26.85, found %', v;
    END IF;

    SELECT round(sum(store_contribution_inr) / sum(delivered_orders), 2) INTO v
    FROM v_store_day_pnl;
    IF v <> -7.08 THEN
        RAISE EXCEPTION 'contribution per order: expected -7.08, found %', v;
    END IF;

    SELECT round(sum(store_contribution_inr), 0) INTO v FROM v_store_day_pnl;
    IF v <> -683493 THEN
        RAISE EXCEPTION 'network contribution: expected -683493, found %', v;
    END IF;

    -- Break-even and lever sensitivity ------------------------------------------------
    SELECT break_even_orders_per_store_day INTO v FROM v_break_even;
    IF v <> 1619.23 THEN
        RAISE EXCEPTION 'break-even orders: expected 1619.23, found %', v;
    END IF;

    SELECT required_volume_change_pct INTO v FROM v_break_even;
    IF v <> 0.3584 THEN
        RAISE EXCEPTION 'volume change: expected 0.3584, found %', v;
    END IF;

    SELECT required_aov_change_pct INTO v FROM v_break_even;
    IF v <> 0.1373 THEN
        RAISE EXCEPTION 'AOV change: expected 0.1373, found %', v;
    END IF;

    SELECT required_delivery_change_pct INTO v FROM v_break_even;
    IF v <> -0.1649 THEN
        RAISE EXCEPTION 'delivery change: expected -0.1649, found %', v;
    END IF;

    SELECT required_ad_change_pct INTO v FROM v_break_even;
    IF v <> 0.3531 THEN
        RAISE EXCEPTION 'ad change: expected 0.3531, found %', v;
    END IF;

    SELECT STRING_AGG(lever, '|' ORDER BY impact_rank) INTO t
    FROM v_lever_sensitivity;
    IF t <> 'order value +10%|delivery cost -10%|ad income +10%|orders per day +10%' THEN
        RAISE EXCEPTION 'unexpected lever ranking: %', t;
    END IF;

    RAISE NOTICE 'All headline assertions passed.';
END $$;
