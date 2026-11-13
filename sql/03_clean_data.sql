-- =====================================================================
-- Project 1: Online Store Sales Analysis
-- File:      03_clean_data.sql
-- Purpose:   Turn the combined raw data into analysis-ready tables.
--            Each stage is a new table, so every step can be checked.
-- Database:  PostgreSQL
-- Input:     retail_combined (from 02_combine_sheets.sql), 1,044,848 rows
-- Output:    sales_clean (valid product sales)
--            cancellations_clean (product cancellations, for leak analysis)
-- =====================================================================


-- ---------------------------------------------------------------------
-- 1. Proper data types
-- Text -> integer / numeric / timestamp; blanks -> NULL; spaces trimmed.
-- Dates were saved by Excel as M/D/YYYY.
-- ---------------------------------------------------------------------
DROP TABLE IF EXISTS retail_typed;

CREATE TABLE retail_typed AS
SELECT
    TRIM(invoice)                                               AS invoice,
    TRIM(stock_code)                                            AS stock_code,
    NULLIF(TRIM(description), '')                               AS description,
    quantity::INTEGER                                           AS quantity,
    TO_TIMESTAMP(invoice_date, 'MM/DD/YYYY HH24:MI')::timestamp AS invoice_date,
    price::NUMERIC(10,3)                                        AS price,
    NULLIF(TRIM(customer_id), '')::INTEGER                      AS customer_id,
    TRIM(country)                                               AS country,
    source_sheet
FROM retail_combined;
-- Result: 1,044,848 rows | 235,287 missing customer IDs


-- ---------------------------------------------------------------------
-- 2. Remove exact duplicate rows (treated as double entries)
-- ---------------------------------------------------------------------
DROP TABLE IF EXISTS retail_dedup;

CREATE TABLE retail_dedup AS
SELECT DISTINCT * FROM retail_typed;
-- Result: 1,033,036 rows (11,812 duplicates removed)


-- ---------------------------------------------------------------------
-- 3. Label cancellations (invoice starts with 'C'). Kept, not deleted.
-- ---------------------------------------------------------------------
DROP TABLE IF EXISTS retail_flagged;

CREATE TABLE retail_flagged AS
SELECT *,
       (invoice LIKE 'C%') AS is_cancellation
FROM retail_dedup;
-- Result: 19,104 cancelled lines | 8,292 invoices | -£1,462,050.61


-- ---------------------------------------------------------------------
-- 4. Label each line: product or non-product
-- DCGS* codes look odd but are real products (checked descriptions),
-- so they stay as 'product'.
-- ---------------------------------------------------------------------
DROP TABLE IF EXISTS retail_labelled;

CREATE TABLE retail_labelled AS
SELECT *,
    CASE
        WHEN UPPER(stock_code) IN ('POST', 'DOT', 'C2', 'C3')              THEN 'shipping'
        WHEN UPPER(stock_code) IN ('BANK CHARGES', 'AMAZONFEE', 'CRUK')     THEN 'fee'
        WHEN UPPER(stock_code) IN ('M', 'ADJUST', 'ADJUST2', 'B', 'D', 'S') THEN 'adjustment'
        WHEN UPPER(stock_code) LIKE 'TEST%'                                 THEN 'test'
        WHEN UPPER(stock_code) LIKE 'GIFT%'                                 THEN 'gift_voucher'
        ELSE 'product'
    END AS line_type
FROM retail_flagged;
-- Product cancellations: 17,915 lines | 7,406 invoices | -£716,462.57
-- The other ~£745K of 'C' lines are adjustments, fees and postage refunds.


-- ---------------------------------------------------------------------
-- 5. Final tables
-- A valid sale = a product line, not cancelled, quantity > 0, price > 0.
-- Rows with price = 0 are stock notes ('damages', 'check', 'missing'),
-- not sales. Blank customer IDs are KEPT here (they are real revenue)
-- and filtered out only in the customer analysis.
-- ---------------------------------------------------------------------
DROP TABLE IF EXISTS sales_clean;

CREATE TABLE sales_clean AS
SELECT invoice, stock_code, description, quantity, invoice_date,
       price, customer_id, country,
       ROUND(quantity * price, 2) AS revenue
FROM retail_labelled
WHERE line_type = 'product'
  AND NOT is_cancellation
  AND quantity > 0
  AND price > 0;
-- Result: 1,003,357 rows | 39,516 invoices | £19,643,861.64

DROP TABLE IF EXISTS cancellations_clean;

CREATE TABLE cancellations_clean AS
SELECT invoice, stock_code, description, quantity, invoice_date,
       price, customer_id, country,
       ROUND(quantity * price, 2) AS cancelled_value
FROM retail_labelled
WHERE line_type = 'product'
  AND is_cancellation;
-- Result: 17,915 rows | -£716,462.57


-- ---------------------------------------------------------------------
-- 5b. Remove two data-entry errors (found while ranking products)
-- Two huge orders were reversed minutes later by the same customer:
--   581483 / C581484: 80,995 x Paper Craft Little Birdie  = £168,469.60
--   541431 / C541433: 74,215 x Medium Ceramic Storage Jar = £77,183.60
-- These are typing mistakes, not real demand or real cancellations,
-- so both the order and its reversal are removed (£245,653.20).
-- Smaller cancellations stay: they are real customer behaviour.
-- ---------------------------------------------------------------------
DELETE FROM sales_clean
WHERE invoice IN ('581483', '541431');

DELETE FROM cancellations_clean
WHERE invoice IN ('C581484', 'C541433');
-- Result: sales_clean 1,003,355 rows | cancellations_clean 17,913 rows


-- ---------------------------------------------------------------------
-- 5c. Hour of day, for the Timing page in Power BI
-- ---------------------------------------------------------------------
ALTER TABLE sales_clean ADD COLUMN order_hour INTEGER;

UPDATE sales_clean
SET order_hour = EXTRACT(HOUR FROM invoice_date);


-- ---------------------------------------------------------------------
-- 6. Final check
-- ---------------------------------------------------------------------
SELECT
    COUNT(*)                                             AS sales_lines,
    COUNT(DISTINCT invoice)                              AS invoices,
    COUNT(DISTINCT customer_id)                          AS customers,
    ROUND(SUM(revenue), 2)                               AS total_revenue,
    ROUND(SUM(revenue) FILTER (WHERE customer_id IS NULL)
          / SUM(revenue) * 100, 1)                       AS pct_revenue_no_customer
FROM sales_clean;
-- Expected: 1,003,355 | 39,514 | 5,852 | 19,398,208.42 | 13.3
