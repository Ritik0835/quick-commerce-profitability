# Power BI measures and model (quick_commerce_profitability.pbix)

The dashboard reads the CSV files in `data/` directly. It is not connected to PostgreSQL, so every measure below recomputes the SQL definitions from the raw columns. The expected values come from the PostgreSQL views (`v_order_cm`, `v_store_day_pnl`) and the KPI queries; each measure must match its expected value before any visual is built.

All data is synthetic. Constants typed into a measure are marked with the assumption they come from.

## 1. Model

| Table | Source | Notes |
|---|---|---|
| customers | data/customers.csv | |
| dark_stores | data/dark_stores.csv | |
| orders | data/orders.csv | order_date as Date, order_ts as Date/Time, money columns as Decimal, order_hour as Whole number |
| order_items | data/order_items.csv | Not used by any measure |
| delivery_logs | data/delivery_logs.csv | delivery_duration_minutes and rider_payout_inr as Decimal |
| DateTable | DAX calendar | Marked as the date table |
| Measures | Empty table | Holds every measure |

### Relationships (Model view)

| From (many) | To (one) | Direction |
|---|---|---|
| orders[store_id] | dark_stores[store_id] | Single (stores filter orders) |
| orders[customer_id] | customers[customer_id] | Single |
| orders[order_date] | DateTable[Date] | Single |
| order_items[order_id] | orders[order_id] | Single |
| delivery_logs[order_id] | orders[order_id] | One-to-one, cross-filter direction **Both** |

Do not add a second path from delivery_logs[store_id] to dark_stores. Two paths make the model ambiguous.

## 2. Measures

### Orders and value
```
Total Orders = COUNTROWS ( orders )

Delivered Orders =
CALCULATE ( COUNTROWS ( orders ), orders[order_status] = "delivered" )

Delivered Net Order Value =
CALCULATE ( SUM ( orders[order_value_inr] ), orders[order_status] = "delivered" )

AOV = DIVIDE ( [Delivered Net Order Value], [Delivered Orders] )

Store Days = DISTINCTCOUNT ( dark_stores[store_id] ) * DISTINCTCOUNT ( orders[order_date] )

Orders per Store per Day = DIVIDE ( [Delivered Orders], [Store Days] )
```

### CM1, CM2 and store contribution
Revenue and cost columns are 0 on cancelled and returned orders, so plain sums already cover delivered orders only.
```
Product Margin = SUM ( orders[product_margin_inr] )
Ad Income = SUM ( orders[ad_income_inr] )
Customer Fees = SUM ( orders[customer_fee_inr] )
Platform Discounts = SUM ( orders[platform_discount_inr] )
CM1 = [Product Margin] + [Ad Income] + [Customer Fees] - [Platform Discounts]

Picking and Packing Cost = SUM ( orders[picking_packing_cost_inr] )
Payment Cost = SUM ( orders[payment_cost_inr] )
Rider Payout = SUM ( delivery_logs[rider_payout_inr] )
CM2 = [CM1] - [Picking and Packing Cost] - [Rider Payout] - [Payment Cost]

CM1 per Order = DIVIDE ( [CM1], [Delivered Orders] )
CM2 per Order = DIVIDE ( [CM2], [Delivered Orders] )

Fixed Cost = SUM ( dark_stores[daily_fixed_cost_inr] ) * DISTINCTCOUNT ( orders[order_date] )
Store Contribution = [CM2] - [Fixed Cost]
Contribution per Order = DIVIDE ( [Store Contribution], [Delivered Orders] )
```
Do not use [Fixed Cost] or [Store Contribution] on a visual split by hour: fixed cost is a daily figure.

### Break-even
```
Break-even Orders per Store per Day =
DIVIDE ( DIVIDE ( [Fixed Cost], [Store Days] ), [CM2 per Order] )

Break-even Gap = [Break-even Orders per Store per Day] - [Orders per Store per Day]

Break-even Gap % = DIVIDE ( [Break-even Gap], [Orders per Store per Day] )
```

### Operations
```
On-time Threshold Minutes = 15            // assumption S39

On-time Orders =
VAR threshold = [On-time Threshold Minutes]
RETURN
    CALCULATE (
        COUNTROWS ( delivery_logs ),
        delivery_logs[delivery_status] = "delivered",
        delivery_logs[delivery_duration_minutes] <= threshold
    )

On-time % = DIVIDE ( [On-time Orders], [Delivered Orders] )

Stockout Keep Share = 0.88                // assumption S12

Stockout Affected Orders =
CALCULATE ( COUNTROWS ( orders ), orders[order_status] = "delivered", orders[stockout_affected] = "YES" )

Stockout Loss =
VAR keep = [Stockout Keep Share]
RETURN
    SUMX (
        FILTER ( orders, orders[order_status] = "delivered" && orders[stockout_affected] = "YES" ),
        orders[order_value_inr] * ( 1 / keep - 1 )
    )

Store Rank = RANKX ( ALL ( dark_stores[store_id] ), [Contribution per Order], , DESC, DENSE )
```

### 30-day repeat rate
First add four **calculated columns** to the `customers` table (Table view, New column):
```
First Delivered Date =
CALCULATE ( MIN ( orders[order_date] ), orders[order_status] = "delivered" )

First Delivered TS =
CALCULATE ( MIN ( orders[order_ts] ), orders[order_status] = "delivered" )

Eligible 30d =
VAR windowDays = 30                       // assumption S40
VAR lastDate = CALCULATE ( MAX ( orders[order_date] ), ALL ( orders ) )
RETURN
    IF (
        NOT ISBLANK ( customers[First Delivered Date] )
            && customers[First Delivered Date] + windowDays <= lastDate,
        1,
        0
    )

Repeat 30d =
VAR windowDays = 30                       // assumption S40
VAR firstTs = customers[First Delivered TS]
VAR firstDate = customers[First Delivered Date]
RETURN
    IF (
        customers[Eligible 30d] = 1,
        IF (
            COUNTROWS (
                FILTER (
                    RELATEDTABLE ( orders ),
                    orders[order_status] = "delivered"
                        && orders[order_ts] > firstTs
                        && orders[order_date] - firstDate <= windowDays
                )
            ) > 0,
            1,
            0
        ),
        0
    )
```
Then the measures:
```
Eligible Customers = CALCULATE ( COUNTROWS ( customers ), customers[Eligible 30d] = 1 )
Repeat Customers = CALCULATE ( COUNTROWS ( customers ), customers[Repeat 30d] = 1 )
Repeat Rate 30d = DIVIDE ( [Repeat Customers], [Eligible Customers] )
```

## 3. Expected values (whole dataset, no filters)

| Measure | Expected |
|---|---:|
| Total Orders | 100,000 |
| Delivered Orders | 96,474 |
| Delivered Net Order Value | 48,737,669 |
| AOV | 505.19 |
| Store Days | 1,800 |
| Orders per Store per Day | 53.60 |
| Product Margin | 5,806,209 |
| Ad Income | 1,935,403 |
| Customer Fees | 1,935,404 |
| Platform Discounts | 1,243,249 |
| CM1 | 8,433,767 |
| Picking and Packing Cost | 1,554,155 |
| Rider Payout | 4,144,173 |
| Payment Cost | 828,833 |
| CM2 | 1,906,606 |
| CM1 per Order | 87.42 |
| CM2 per Order | 19.76 |
| Fixed Cost | 2,590,099 |
| Store Contribution | -683,493 |
| Contribution per Order | -7.08 |
| Break-even Orders per Store per Day | 72.8 |
| Break-even Gap | 19.2 |
| Break-even Gap % | 35.8% |
| On-time Orders | 81,957 |
| On-time % | 85.0% |
| Stockout Affected Orders | 1,166 |
| Stockout Loss | 70,895 |
| Eligible Customers | 24,930 |
| Repeat Customers | 9,650 |
| Repeat Rate 30d | 38.7% |

### By store: Contribution per Order, Store Contribution and Store Rank

| Rank | Store | Contribution per Order | Store Contribution |
|---:|---|---:|---:|
| 1 | STORE_009 | -1.00 | -9,813 |
| 2 | STORE_008 | -1.01 | -9,049 |
| 3 | STORE_001 | -2.12 | -21,874 |
| 4 | STORE_006 | -3.35 | -36,665 |
| 5 | STORE_010 | -4.83 | -38,661 |
| 6 | STORE_004 | -5.12 | -51,448 |
| 7 | STORE_007 | -8.14 | -72,221 |
| 8 | STORE_005 | -10.54 | -118,458 |
| 9 | STORE_003 | -14.61 | -145,730 |
| 10 | STORE_002 | -21.58 | -179,576 |

The break-even gap percentage (35.8%) is the same as the Excel model's required rise in orders per day (+35.8%).
