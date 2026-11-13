-- =====================================================================
-- Project 1: Online Store Sales Analysis
-- File:      07_q4_customers.sql
-- Question:  Q4. Who keeps coming back? How much revenue comes from
--            repeat customers vs one-time buyers?
-- Table:     sales_clean
-- =====================================================================
-- Note: rows without a customer ID (13.3% of revenue) are excluded
-- here, because they can't be linked to a customer. Every figure below
-- is a share of the £16.82M that CAN be linked to 5,852 customers.
-- =====================================================================


-- ---------------------------------------------------------------------
-- Q4a. Repeat vs one-time customers
-- ---------------------------------------------------------------------
WITH customers AS (
    SELECT customer_id,
           COUNT(DISTINCT invoice) AS orders,
           SUM(revenue)            AS revenue
    FROM sales_clean
    WHERE customer_id IS NOT NULL
    GROUP BY customer_id
)
SELECT
    CASE WHEN orders = 1 THEN 'One-time' ELSE 'Repeat' END        AS customer_type,
    COUNT(*)                                                      AS customers,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 1)            AS pct_of_customers,
    ROUND(SUM(revenue), 2)                                        AS revenue,
    ROUND(SUM(revenue) * 100 / SUM(SUM(revenue)) OVER (), 1)      AS pct_of_revenue,
    ROUND(SUM(revenue) / COUNT(*), 2)                             AS revenue_per_customer
FROM customers
GROUP BY 1
ORDER BY 1;
-- Expected: One-time 1,619 (27.7%) | £556,003 (3.3%)  | £343 each
--           Repeat   4,233 (72.3%) | £16,266,927 (96.7%) | £3,843 each


-- ---------------------------------------------------------------------
-- Q4b. How often do customers order? (order-frequency bands)
-- ---------------------------------------------------------------------
WITH customers AS (
    SELECT customer_id,
           COUNT(DISTINCT invoice) AS orders,
           SUM(revenue)            AS revenue
    FROM sales_clean
    WHERE customer_id IS NOT NULL
    GROUP BY customer_id
),
banded AS (
    SELECT *,
           CASE WHEN orders = 1  THEN '1 order'
                WHEN orders = 2  THEN '2 orders'
                WHEN orders <= 4 THEN '3-4 orders'
                WHEN orders <= 9 THEN '5-9 orders'
                WHEN orders <= 19 THEN '10-19 orders'
                ELSE '20+ orders' END AS order_band,
           CASE WHEN orders = 1  THEN 1
                WHEN orders = 2  THEN 2
                WHEN orders <= 4 THEN 3
                WHEN orders <= 9 THEN 4
                WHEN orders <= 19 THEN 5
                ELSE 6 END AS band_order
    FROM customers
)
SELECT order_band,
       COUNT(*)                                                  AS customers,
       ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 1)        AS pct_of_customers,
       ROUND(SUM(revenue), 2)                                    AS revenue,
       ROUND(SUM(revenue) * 100 / SUM(SUM(revenue)) OVER (), 1)  AS pct_of_revenue
FROM banded
GROUP BY order_band, band_order
ORDER BY band_order;
-- Expected headline: 20+ orders = 325 customers (5.6%) but 47.4% of revenue


-- ---------------------------------------------------------------------
-- Q4c. Did Year 1 customers come back in Year 2?
-- ---------------------------------------------------------------------
WITH y1 AS (
    SELECT DISTINCT customer_id FROM sales_clean
    WHERE customer_id IS NOT NULL AND invoice_date < '2010-12-01'
),
y2 AS (
    SELECT DISTINCT customer_id FROM sales_clean
    WHERE customer_id IS NOT NULL
      AND invoice_date >= '2010-12-01' AND invoice_date < '2011-12-01'
),
y2_revenue AS (
    SELECT s.revenue,
           (s.customer_id IN (SELECT customer_id FROM y1)) AS is_returning
    FROM sales_clean s
    WHERE s.customer_id IS NOT NULL
      AND s.invoice_date >= '2010-12-01' AND s.invoice_date < '2011-12-01'
)
SELECT
    (SELECT COUNT(*) FROM y1)                                        AS year1_customers,
    (SELECT COUNT(*) FROM y2)                                        AS year2_customers,
    (SELECT COUNT(*) FROM y1 JOIN y2 USING (customer_id))            AS came_back,
    ROUND((SELECT COUNT(*) FROM y1 JOIN y2 USING (customer_id))
          * 100.0 / (SELECT COUNT(*) FROM y1), 1)                    AS retention_pct,
    (SELECT COUNT(*) FROM y2 WHERE customer_id NOT IN
        (SELECT customer_id FROM y1))                                AS new_in_year2,
    ROUND((SELECT SUM(revenue) FROM y2_revenue WHERE is_returning)
          * 100 / (SELECT SUM(revenue) FROM y2_revenue), 1)          AS year2_revenue_from_returning_pct;
-- Expected: 4,239 | 4,292 | 2,707 | 63.9% | 1,585 | 82.2%


-- ---------------------------------------------------------------------
-- Q4d. How dependent is the shop on its biggest customers?
-- ---------------------------------------------------------------------
WITH customers AS (
    SELECT customer_id, SUM(revenue) AS revenue
    FROM sales_clean
    WHERE customer_id IS NOT NULL
    GROUP BY customer_id
),
ranked AS (
    SELECT revenue,
           ROW_NUMBER() OVER (ORDER BY revenue DESC) AS rnk,
           COUNT(*) OVER ()                          AS total_customers,
           SUM(revenue) OVER ()                      AS total_revenue
    FROM customers
)
SELECT
    ROUND(SUM(revenue) FILTER (WHERE rnk <= 10) * 100
          / MAX(total_revenue), 1)                                   AS top10_customers_pct,
    FLOOR(MAX(total_customers) * 0.01)                               AS top1pct_customer_count,
    ROUND(SUM(revenue) FILTER (WHERE rnk <= FLOOR(total_customers * 0.01)) * 100
          / MAX(total_revenue), 1)                                   AS top1pct_customers_pct
FROM ranked;
-- Expected: top 10 customers = 16.1% | top 1% = 58 customers = 31.3%
