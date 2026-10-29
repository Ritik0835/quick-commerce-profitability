# Quick Commerce Profitability: From Loss to Profit

> **Data disclaimer:** This project uses synthetic data created for analytical and educational purposes. The data does not represent actual operating results from any quick-commerce company. All findings are modeled scenarios based on explicitly documented assumptions, not measured company performance.

## Problem Statement

Quick-commerce companies operate dark stores that fulfill customer orders within a short delivery window. Each order generates revenue through product sales and potentially advertising income, but also incurs costs such as product procurement, packaging, delivery, and dark-store operations.

When the contribution generated per order is insufficient to cover fixed operating costs, a dark store can remain unprofitable even when order demand is strong.

This project investigates how a hypothetical quick-commerce dark store could move from operating losses to break-even by evaluating four business levers:

- **Average order value (AOV):** Increasing the value of each customer order.
- **Order volume:** Increasing the number of orders processed to spread fixed costs across more orders.
- **Delivery cost:** Reducing the delivery cost incurred per order.
- **Advertising income:** Generating additional revenue from advertising placements and brand promotions.

Using synthetic data and assumptions anchored to published company figures, the analysis will model individual and combined scenarios to estimate the changes required to reach break-even.

The objective is to identify which levers offer the most promising modeled path to profitability and quantify the magnitude of change required under the stated assumptions.

All results will be presented as scenario estimates, not actual company measurements or guaranteed outcomes. Customer lifetime value (LTV) and customer acquisition cost (CAC) analysis is excluded because reliable public data on marketing spend per customer is unavailable.

## Key Business Questions

1. **What is driving the dark store's losses?**  
   How do order-level contribution, delivery costs, product margins, advertising income, and fixed operating costs affect overall profitability?

2. **How much must each profitability lever change to reach break-even?**  
   What increase in average order value or order volume, reduction in delivery cost per order, or increase in advertising income would be required individually?

3. **Which combination of levers provides the most practical modeled path to break-even?**  
   How do combined scenarios compare in terms of required changes, projected operating profit, and the assumptions and trade-offs involved?

## Scope and Limitations

## Scope and Limitations

- All generated operational records are synthetic and do not represent actual company transactions.
- Company-reported metrics are reference benchmarks, not evidence that the synthetic dataset represents actual company operations.
- The generator uses programmed assumptions for demand patterns, peak hours, weekday/weekend differences, stockout periods, and rain delays.
- **Important methodological limitation:** SQL analysis may rediscover patterns deliberately built into the generator. For example, longer delivery times during simulated rain-delay windows are a consequence of the generation rules, not independent evidence that rain causes a specific real-world delay.
- Structural validation checks record counts, relationships, and arithmetic consistency. It does not establish that simulated behaviour matches real-world operations.
- Findings are modeled scenarios under documented assumptions, not measured company performance, causal proof, forecasts, or guaranteed outcomes.
- Customer lifetime value (LTV) and customer acquisition cost (CAC) analysis is excluded because reliable public marketing-spend-per-customer data is unavailable.

## Dataset Documentation

- [`docs/data_dictionary.md`](docs/data_dictionary.md) — table schemas, column meanings, and relationships.
- [`docs/data_note.md`](docs/data_note.md) — generation rules, reproducibility, intended uses, and limitations.
- [`docs/company_assumptions.md`](docs/company_assumptions.md) — company-disclosed benchmarks and their definitions.
