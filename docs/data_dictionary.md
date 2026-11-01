# Data Dictionary — Quick Commerce Profitability

## Overview

This project uses synthetic data for a hypothetical quick-commerce business over 180 days, from 1 April 2026 to 27 September 2026. The generator uses random seed 42 and reads its parameters from `data/assumptions.csv`. Several parameters are referred to by ID (for example S12); the IDs are rows in that file.

All records are synthetic. They do not represent real customers, transactions or the performance of any real dark store. The money columns are calibrated so that per-order averages agree with the Excel model; see `docs/data_note.md` and `docs/reconciliation.md`.

## Reading the money columns

- Revenue and cost columns exist only for **delivered** orders. Cancelled and returned orders carry 0 in all of them.
- CM1 = product margin + ad income + customer fee - platform discount. CM2 = CM1 - picking and packing - rider payout - payment cost. Store contribution = CM2 - daily fixed cost. Definitions are in `docs/metric_definitions.md`.
- `order_value_inr` is filled for every order, so revenue questions must filter on `order_status = 'delivered'`.

## 1. customers.csv

**Grain:** One row per synthetic customer.

| Column | Description |
|---|---|
| customer_id | Unique synthetic customer identifier |
| signup_date | Simulated signup date. Every customer signs up before the window starts (0 to 365 days before 2026-04-01) |
| home_store_id | The dark store this customer orders from. Customers only order from their home store |
| home_city | City of the home store |
| customer_segment | new, regular or high_frequency. Segment mix is 45% / 45% / 10%. Segment sets how often the customer is picked for an order (S33 to S35) |
| synthetic_data_flag | YES on every row |

## 2. dark_stores.csv

**Grain:** One row per synthetic dark store (10 rows).

| Column | Description |
|---|---|
| store_id | Unique store identifier (STORE_001 to STORE_010) |
| store_name | Synthetic store name |
| city | Synthetic city label (four labels, assigned in rotation) |
| opened_date | Simulated opening date, before the window starts |
| store_size_sqft | Simulated store area, 1,800 to 3,500 sq ft |
| daily_fixed_cost_inr | Daily fixed cost in INR (rent, fixed staff, utilities). SCALED to the generated volume: the average is about 1,439 INR per store per day, about 4.5% of a real store's cost, because these stores handle about 54 orders a day against Instamart's 1,192. Larger stores cost proportionally more |
| stockout_windows | Text list of the stockout periods. The same list appears on every store row |
| rain_delay_windows | Text list of the rain-delay periods. The same list appears on every store row |
| synthetic_data_flag | YES on every row |

## 3. orders.csv

**Grain:** One row per synthetic order, including cancelled and returned orders (100,000 rows).

| Column | Description |
|---|---|
| order_id | Unique order identifier |
| customer_id | Customer who placed the order |
| store_id | Store that fulfilled the order |
| order_ts | Order timestamp (store opens 08:00, last order in the 22:00 hour) |
| order_date | Calendar date of the order |
| order_hour | Hour of the order, 8 to 22 |
| day_of_week | Day name |
| day_type | weekday or weekend |
| order_value_inr | Net order value in INR (after discounts). Filled for every order, including cancelled and returned ones. Use delivered orders only for revenue questions |
| order_status | delivered (about 96.5%), cancelled (about 2.5%) or returned (about 1.0%) |
| stockout_period | YES if the order date falls inside a stockout window |
| stockout_affected | YES if the order was hit by a stockout. Affected orders have their value cut by 12% (S12) |
| rain_delay_period | YES if the order date falls inside a rain-delay window |
| rain_delayed | YES if the order was delayed by rain. Rain adds 6 minutes to delivery (S17) |
| product_margin_inr | Earnings on the order after product cost. Delivered orders only; 0 otherwise |
| ad_income_inr | Ad revenue attributed to the order. Delivered orders only; 0 otherwise |
| customer_fee_inr | Delivery and handling fees the customer paid. Delivered orders only; 0 otherwise |
| platform_discount_inr | Coupon funded by the platform. Delivered orders only; 0 otherwise |
| picking_packing_cost_inr | Warehouse picking and packing cost; grows with item lines. Delivered orders only; 0 otherwise |
| payment_cost_inr | Payment fees; grows with order value. Delivered orders only; 0 otherwise |
| synthetic_data_flag | YES on every row |

## 4. order_items.csv

**Grain:** One row per item line within an order (287,810 rows).

| Column | Description |
|---|---|
| order_item_id | Unique order-item identifier |
| order_id | Parent order |
| product_id | Synthetic product identifier (PROD_001 to PROD_010) |
| product_category | Category tied to the product (for example Dairy, Snacks) |
| quantity | Units in the line |
| unit_price_inr | Unit price in INR. NOT tied to the product: the same product can have very different prices on different lines, because line values are a random split of the basket value |
| line_total_inr | Line value; the lines of an order add up to order_value_inr |
| stockout_affected | Stockout flag copied from the parent order |
| synthetic_data_flag | YES on every row |

## 5. delivery_logs.csv

**Grain:** One row per order (100,000 rows), including cancelled orders.

| Column | Description |
|---|---|
| delivery_log_id | Unique delivery-log identifier |
| order_id | Associated order. One log per order |
| store_id | Store that handled the delivery |
| order_ts | Order timestamp, same as in orders |
| dispatch_ts | Dispatch timestamp. Empty for cancelled orders |
| delivered_ts | Delivery timestamp. Empty for cancelled orders |
| delivery_duration_minutes | Minutes from order to delivery, about 12 on a normal day. Empty for cancelled orders |
| rain_delay_period | YES if the order date falls inside a rain-delay window |
| rain_delayed | YES if the order was delayed by rain |
| delivery_status | delivered, cancelled or returned, same as the order status |
| rider_payout_inr | Delivery cost paid to the rider; grows with delivery minutes. Delivered orders only; 0 otherwise |
| synthetic_data_flag | YES on every row |

## Relationships

- `dark_stores.store_id` → `customers.home_store_id`, `orders.store_id`, `delivery_logs.store_id`
- `customers.customer_id` → `orders.customer_id`
- `orders.order_id` → `order_items.order_id` and `delivery_logs.order_id` (one delivery log per order)

## Other files and SQL objects

| Object | Purpose |
|---|---|
| `data/assumptions.csv` | Company-reported rows (IDs starting B and I, with source and page) and synthetic generator settings (IDs starting S) |
| `data/excel_reference.csv` | Excel model values with sheet and cell address, used by `sql/07_reconcile.sql` |
| `data/generation_summary.txt` | Seed, date range, windows and the calibration targets from the last run |
| `v_order_cm` (view) | One row per delivered order with CM1 and CM2 |
| `v_store_day_pnl` (view) | One row per store per date with the daily fixed cost charged once |

## Known limitations of the columns

- `unit_price_inr` and `product_id` carry no real price information.
- `signup_date` is always before the window, so no customer signs up during it.
- `stockout_windows` and `rain_delay_windows` repeat the same text on every store row, and the windows hit all stores on the same days.
- Flags such as `rain_delayed` and `stockout_affected` were written by the generator. SQL that finds an effect of these flags is rediscovering a built-in rule (see `docs/data_note.md`).
