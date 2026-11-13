-- =====================================================================
-- Project 1: Online Store Sales Analysis
-- File:      10_customer_segments.sql
-- Purpose:   Group customers into segments the owner can act on,
--            using RFM: Recency, Frequency, Monetary value.
-- Table:     sales_clean (rows with a customer ID only)
-- Output:    customer_segments (one row per customer, also used in Power BI)
-- =====================================================================
-- Why fixed rules instead of score quintiles:
-- Rules like "ordered in the last 90 days AND 10+ orders" can be
-- explained to a business owner in one sentence and give the same
-- result every time the query runs.
--
-- Reference date = 10 Dec 2011, the day after the last sale.
--
-- Segment rules:
--   Champions        last order <= 90 days ago   AND 10+ orders
--   Loyal            last order <= 180 days ago  AND 4+ orders (not Champions)
--   New / Promising  last order <= 90 days ago   AND 1-3 orders
--   At Risk          last order 181-365 days ago AND 4+ orders
--   Needs Attention  last order 91-365 days ago  AND 1-3 orders
--   Lost             last order more than 365 days ago
-- =====================================================================


-- ---------------------------------------------------------------------
-- 1. Build the customer table
-- ---------------------------------------------------------------------
DROP TABLE IF EXISTS customer_segments;

CREATE TABLE customer_segments AS
WITH rfm AS (
    SELECT
        customer_id,
        MODE() WITHIN GROUP (ORDER BY country)        AS country,
        MAX(invoice_date)                             AS last_order_date,
        DATE '2011-12-10' - MAX(invoice_date)::date   AS days_since_last_order,
        COUNT(DISTINCT invoice)                       AS orders,
        ROUND(SUM(revenue), 2)                        AS total_spend
    FROM sales_clean
    WHERE customer_id IS NOT NULL
    GROUP BY customer_id
)
SELECT *,
    CASE
        WHEN days_since_last_order <= 90  AND orders >= 10 THEN 'Champions'
        WHEN days_since_last_order <= 180 AND orders >= 4  THEN 'Loyal'
        WHEN days_since_last_order <= 90                   THEN 'New / Promising'
        WHEN days_since_last_order <= 365 AND orders >= 4  THEN 'At Risk'
        WHEN days_since_last_order <= 365                  THEN 'Needs Attention'
        ELSE 'Lost'
    END AS segment
FROM rfm;
-- Result: 5,852 customers


-- ---------------------------------------------------------------------
-- 2. Segment summary
-- ---------------------------------------------------------------------
SELECT
    segment,
    COUNT(*)                                                     AS customers,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 1)           AS pct_of_customers,
    ROUND(SUM(total_spend), 2)                                   AS revenue,
    ROUND(SUM(total_spend) * 100 / SUM(SUM(total_spend)) OVER (), 1) AS pct_of_revenue,
    ROUND(AVG(days_since_last_order))                            AS avg_days_since_order,
    ROUND(AVG(orders), 1)                                        AS avg_orders,
    ROUND(AVG(total_spend), 2)                                   AS avg_spend
FROM customer_segments
GROUP BY segment
ORDER BY revenue DESC;
-- Expected:
-- Champions        837 (14.3%) | £10.52M (62.5%) | 22 days  | 23.1 orders
-- Loyal          1,318 (22.5%) | £3.17M  (18.9%) | 56 days  |  6.4 orders
-- Lost           1,592 (27.2%) | £1.23M  (7.3%)  | 501 days |  2.2 orders
-- New/Promising  1,027 (17.5%) | £0.71M  (4.2%)  | 39 days  |  2.0 orders
-- At Risk          255 (4.4%)  | £0.62M  (3.7%)  | 256 days |  6.8 orders
-- Needs Attention  823 (14.1%) | £0.57M  (3.4%)  | 218 days |  1.8 orders


-- ---------------------------------------------------------------------
-- 3. The call list: top 10 At Risk customers by past spend
-- These used to buy often and have gone quiet for 6-12 months.
-- ---------------------------------------------------------------------
SELECT customer_id, country,
       last_order_date::date AS last_order,
       days_since_last_order,
       orders,
       total_spend
FROM customer_segments
WHERE segment = 'At Risk'
ORDER BY total_spend DESC
LIMIT 10;
-- Expected #1: customer 13093, 55 orders, £54,144.25, silent for 276 days
-- All 255 At Risk customers together: £618,264.49 of past spend
