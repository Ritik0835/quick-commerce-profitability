
-- File: sql/06_strategy_comparison.sql
-- Purpose: Compare profitability scenarios for the synthetic
-- quick-commerce dark-store simulation.
--
-- IMPORTANT:
-- The 5.3% contribution margin is a reported Blinkit benchmark
-- used as a scenario proxy, NOT a measured margin for our stores.
-- All modeled outcomes are illustrative, not actual company results.

WITH order_metrics AS (
    SELECT
        SUM(order_value_inr) FILTER (
            WHERE order_status = 'delivered'
        ) AS delivered_value
    FROM orders
),
fixed_cost_metrics AS (
    SELECT
        SUM(daily_fixed_cost_inr) * 180 AS fixed_cost
    FROM dark_stores
),
baseline AS (
    SELECT
        o.delivered_value,
        f.fixed_cost
    FROM order_metrics o
    CROSS JOIN fixed_cost_metrics f
),
scenarios AS (
    SELECT *
    FROM (VALUES
        ('Baseline: 5.3% margin', 1.00, 0.053, 1.00),
        ('Margin improves to 10%', 1.00, 0.10, 1.00),
        ('Margin improves to 15%', 1.00, 0.15, 1.00),
        ('Order value +10%', 1.10, 0.053, 1.00),
        ('Fixed costs -10%', 1.00, 0.053, 0.90),
        ('Combined improvement', 1.10, 0.10, 0.90)
    ) AS v(
        scenario,
        order_value_multiplier,
        contribution_margin,
        fixed_cost_multiplier
    )
)
SELECT
    s.scenario,
    ROUND(
        b.delivered_value * s.order_value_multiplier,
        2
    ) AS modeled_order_value_inr,
    ROUND(
        b.delivered_value
        * s.order_value_multiplier
        * s.contribution_margin,
        2
    ) AS modeled_contribution_inr,
    ROUND(
        b.fixed_cost * s.fixed_cost_multiplier,
        2
    ) AS modeled_fixed_cost_inr,
    ROUND(
        b.delivered_value
        * s.order_value_multiplier
        * s.contribution_margin
        - b.fixed_cost * s.fixed_cost_multiplier,
        2
    ) AS modeled_surplus_or_shortfall_inr
FROM baseline b
CROSS JOIN scenarios s
ORDER BY modeled_surplus_or_shortfall_inr DESC;
