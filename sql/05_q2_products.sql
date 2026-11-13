-- =====================================================================
-- Project 1: Online Store Sales Analysis
-- File:      05_q2_products.sql
-- Question:  Q2. What actually makes the money? Which products bring
--            in the most revenue, and how concentrated is it?
-- Table:     sales_clean
-- =====================================================================
-- Note: some stock codes have slightly different descriptions over
-- time, so products are grouped by stock_code and labelled with their
-- most common description.
-- =====================================================================


-- ---------------------------------------------------------------------
-- Q2a. Top 10 products by revenue
-- ---------------------------------------------------------------------
SELECT
    stock_code,
    MODE() WITHIN GROUP (ORDER BY description)              AS product,
    ROUND(SUM(revenue), 2)                                  AS revenue,
    SUM(quantity)                                           AS units_sold,
    COUNT(DISTINCT invoice)                                 AS orders,
    ROUND(SUM(revenue) * 100 / SUM(SUM(revenue)) OVER (), 2) AS pct_of_total_revenue
FROM sales_clean
GROUP BY stock_code
ORDER BY revenue DESC
LIMIT 10;
-- Expected #1: Regency Cakestand 3 Tier, £330,590.32 (1.70%)
-- Top 10 together = 7.6% of revenue


-- ---------------------------------------------------------------------
-- Q2b. How concentrated is revenue?
-- Products ranked by revenue and split into 5 equal groups (20% each).
-- ---------------------------------------------------------------------
WITH product_revenue AS (
    SELECT stock_code, SUM(revenue) AS revenue
    FROM sales_clean
    GROUP BY stock_code
),
ranked AS (
    SELECT stock_code, revenue,
           NTILE(5) OVER (ORDER BY revenue DESC) AS product_group
    FROM product_revenue
)
SELECT
    CASE product_group
        WHEN 1 THEN 'Top 20%'
        WHEN 2 THEN '20-40%'
        WHEN 3 THEN '40-60%'
        WHEN 4 THEN '60-80%'
        WHEN 5 THEN 'Bottom 20%'
    END                                                       AS product_group,
    COUNT(*)                                                  AS products,
    ROUND(SUM(revenue), 2)                                    AS revenue,
    ROUND(SUM(revenue) * 100 / SUM(SUM(revenue)) OVER (), 1)  AS pct_of_revenue
FROM ranked
GROUP BY product_group
ORDER BY product_group;
-- Expected: 4,894 products; top 20% (979 products) = 78.4% of revenue;
-- bottom 20% = 0.3%


-- ---------------------------------------------------------------------
-- Q2c. How many products make up half of all revenue?
-- ---------------------------------------------------------------------
WITH product_revenue AS (
    SELECT stock_code, SUM(revenue) AS revenue
    FROM sales_clean
    GROUP BY stock_code
),
running AS (
    SELECT stock_code,
           SUM(revenue) OVER (ORDER BY revenue DESC
                              ROWS UNBOUNDED PRECEDING)
           / SUM(revenue) OVER ()                         AS cumulative_share
    FROM product_revenue
)
SELECT
    COUNT(*) FILTER (WHERE cumulative_share < 0.5) + 1   AS products_for_50pct,
    COUNT(*) FILTER (WHERE cumulative_share < 0.8) + 1   AS products_for_80pct,
    COUNT(*)                                             AS total_products
FROM running;
-- Expected: 292 | 1,051 | 4,894
