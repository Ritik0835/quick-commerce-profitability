-- Loads the CSV files into the tables created by 01_schema.sql.
-- Run from the repo root so the relative paths below resolve:
--   psql -d quick_commerce -f sql/01_schema.sql -f sql/02_load.sql
-- Parents are loaded before children because of the foreign keys.
\set ON_ERROR_STOP on
\copy assumptions FROM 'data/assumptions.csv' WITH (FORMAT csv, HEADER true)
\copy dark_stores FROM 'data/dark_stores.csv' WITH (FORMAT csv, HEADER true)
\copy customers FROM 'data/customers.csv' WITH (FORMAT csv, HEADER true)
\copy orders FROM 'data/orders.csv' WITH (FORMAT csv, HEADER true)
\copy order_items FROM 'data/order_items.csv' WITH (FORMAT csv, HEADER true)
\copy delivery_logs FROM 'data/delivery_logs.csv' WITH (FORMAT csv, HEADER true)

SELECT 'assumptions' AS table_name, COUNT(*) AS rows FROM assumptions
UNION ALL SELECT 'dark_stores', COUNT(*) FROM dark_stores
UNION ALL SELECT 'customers', COUNT(*) FROM customers
UNION ALL SELECT 'orders', COUNT(*) FROM orders
UNION ALL SELECT 'order_items', COUNT(*) FROM order_items
UNION ALL SELECT 'delivery_logs', COUNT(*) FROM delivery_logs;
