-- =====================================================================
-- Project 1: Online Store Sales Analysis
-- File:      04_q1_growth.sql
-- Question:  Q1. Is the business growing? Is growth coming from more
--            orders or bigger orders?
-- Table:     sales_clean
-- =====================================================================
-- Note: the data ends on 9 Dec 2011, so December 2011 is a PARTIAL
-- month. Comparing it to a full month would wrongly show a big drop.
-- The yearly comparison therefore uses two full 12-month periods:
--   Year 1 = Dec 2009 - Nov 2010
--   Year 2 = Dec 2010 - Nov 2011
-- =====================================================================


-- ---------------------------------------------------------------------
-- Q1a. Monthly revenue, orders and average order value (AOV)
-- ---------------------------------------------------------------------
SELECT
    TO_CHAR(DATE_TRUNC('month', invoice_date), 'YYYY-MM')  AS month,
    ROUND(SUM(revenue), 2)                                  AS revenue,
    COUNT(DISTINCT invoice)                                 AS orders,
    ROUND(SUM(revenue) / COUNT(DISTINCT invoice), 2)        AS avg_order_value,
    CASE WHEN DATE_TRUNC('month', invoice_date) = '2011-12-01'
         THEN 'partial (1-9 Dec only)' ELSE '' END          AS note
FROM sales_clean
GROUP BY DATE_TRUNC('month', invoice_date)
ORDER BY DATE_TRUNC('month', invoice_date);


-- ---------------------------------------------------------------------
-- Q1b. Year 1 vs Year 2 (full 12-month periods)
-- ---------------------------------------------------------------------
WITH yearly AS (
    SELECT
        CASE WHEN invoice_date < '2010-12-01' THEN 'Year 1 (Dec 09 - Nov 10)'
             ELSE 'Year 2 (Dec 10 - Nov 11)' END        AS period,
        SUM(revenue)                                     AS revenue,
        COUNT(DISTINCT invoice)                          AS orders,
        COUNT(DISTINCT customer_id)                      AS customers
    FROM sales_clean
    WHERE invoice_date < '2011-12-01'          -- leave out partial Dec 2011
    GROUP BY 1
)
SELECT
    period,
    ROUND(revenue, 2)                                AS revenue,
    orders,
    customers,
    ROUND(revenue / orders, 2)                       AS avg_order_value,
    ROUND((revenue / LAG(revenue) OVER (ORDER BY period) - 1) * 100, 1)
                                                     AS revenue_change_pct,
    ROUND((orders::NUMERIC / LAG(orders) OVER (ORDER BY period) - 1) * 100, 1)
                                                     AS orders_change_pct,
    ROUND(((revenue / orders)
          / LAG(revenue / orders) OVER (ORDER BY period) - 1) * 100, 1)
                                                     AS aov_change_pct
FROM yearly
ORDER BY period;
-- Expected (after removing the two data-entry errors):
-- Year 1: £9,396,642.30 | 19,743 orders | AOV £475.95
-- Year 2: £9,555,544.80 | 18,956 orders | AOV £504.09
--         revenue +1.7% | orders -4.0% | AOV +5.9%
