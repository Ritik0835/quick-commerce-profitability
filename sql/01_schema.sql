-- Schema for the synthetic quick-commerce dark store project.
-- Run from the repo root:  psql -d quick_commerce -f sql/01_schema.sql
-- Column order matches the CSV files in data/ exactly, so \copy can load them directly.
-- All data is synthetic (synthetic_data_flag = TRUE on every row).

DROP TABLE IF EXISTS delivery_logs CASCADE;
DROP TABLE IF EXISTS order_items CASCADE;
DROP TABLE IF EXISTS orders CASCADE;
DROP TABLE IF EXISTS customers CASCADE;
DROP TABLE IF EXISTS dark_stores CASCADE;
DROP TABLE IF EXISTS assumptions CASCADE;

-- Same 14 columns as data/assumptions.csv. Views read parameters from here so that
-- SQL, Excel and Power BI use the same assumptions.
CREATE TABLE assumptions (
    id TEXT PRIMARY KEY,
    company TEXT,
    metric TEXT NOT NULL,
    value TEXT,
    unit TEXT,
    period TEXT,
    type TEXT,
    source_name TEXT,
    source_file TEXT,
    page TEXT,
    source_url TEXT,
    source_date TEXT,
    primary_doc_verified TEXT,
    notes TEXT
);

CREATE TABLE dark_stores (
    store_id TEXT PRIMARY KEY,
    store_name TEXT NOT NULL,
    city TEXT NOT NULL,
    opened_date DATE,
    store_size_sqft INTEGER CHECK (store_size_sqft > 0),
    daily_fixed_cost_inr NUMERIC(12, 2) NOT NULL CHECK (daily_fixed_cost_inr >= 0),
    stockout_windows TEXT,
    rain_delay_windows TEXT,
    synthetic_data_flag BOOLEAN NOT NULL
);

CREATE TABLE customers (
    customer_id TEXT PRIMARY KEY,
    signup_date DATE,
    home_store_id TEXT NOT NULL REFERENCES dark_stores (store_id),
    home_city TEXT,
    customer_segment TEXT CHECK (customer_segment IN ('new', 'regular', 'high_frequency')),
    synthetic_data_flag BOOLEAN NOT NULL
);

CREATE TABLE orders (
    order_id TEXT PRIMARY KEY,
    customer_id TEXT NOT NULL REFERENCES customers (customer_id),
    store_id TEXT NOT NULL REFERENCES dark_stores (store_id),
    order_ts TIMESTAMP NOT NULL,
    order_date DATE NOT NULL,
    order_hour SMALLINT CHECK (order_hour BETWEEN 0 AND 23),
    day_of_week TEXT,
    day_type TEXT CHECK (day_type IN ('weekday', 'weekend')),
    order_value_inr NUMERIC(12, 2) CHECK (order_value_inr >= 0),
    order_status TEXT NOT NULL CHECK (order_status IN ('delivered', 'cancelled', 'returned')),
    stockout_period TEXT,
    stockout_affected BOOLEAN,
    rain_delay_period TEXT,
    rain_delayed BOOLEAN,
    product_margin_inr NUMERIC(12, 2) CHECK (product_margin_inr >= 0),
    ad_income_inr NUMERIC(12, 2) CHECK (ad_income_inr >= 0),
    customer_fee_inr NUMERIC(12, 2) CHECK (customer_fee_inr >= 0),
    platform_discount_inr NUMERIC(12, 2) CHECK (platform_discount_inr >= 0),
    picking_packing_cost_inr NUMERIC(12, 2) CHECK (picking_packing_cost_inr >= 0),
    payment_cost_inr NUMERIC(12, 2) CHECK (payment_cost_inr >= 0),
    synthetic_data_flag BOOLEAN NOT NULL
);

CREATE TABLE order_items (
    order_item_id TEXT PRIMARY KEY,
    order_id TEXT NOT NULL REFERENCES orders (order_id),
    product_id TEXT,
    product_category TEXT,
    quantity INTEGER CHECK (quantity > 0),
    unit_price_inr NUMERIC(12, 2),
    line_total_inr NUMERIC(12, 2),
    stockout_affected BOOLEAN,
    synthetic_data_flag BOOLEAN NOT NULL
);

-- Cancelled orders have no dispatch or delivery time, so those columns can be NULL.
CREATE TABLE delivery_logs (
    delivery_log_id TEXT PRIMARY KEY,
    order_id TEXT NOT NULL UNIQUE REFERENCES orders (order_id),
    store_id TEXT NOT NULL REFERENCES dark_stores (store_id),
    order_ts TIMESTAMP,
    dispatch_ts TIMESTAMP,
    delivered_ts TIMESTAMP,
    delivery_duration_minutes NUMERIC(10, 2) CHECK (delivery_duration_minutes >= 0),
    rain_delay_period TEXT,
    rain_delayed BOOLEAN,
    delivery_status TEXT,
    rider_payout_inr NUMERIC(12, 2) CHECK (rider_payout_inr >= 0),
    synthetic_data_flag BOOLEAN NOT NULL
);

CREATE INDEX idx_orders_store_date ON orders (store_id, order_date);
CREATE INDEX idx_orders_customer ON orders (customer_id, order_ts);
CREATE INDEX idx_items_order ON order_items (order_id);
