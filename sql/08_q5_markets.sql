-- =====================================================================
-- Project 1: Online Store Sales Analysis
-- File:      08_q5_markets.sql
-- Question:  Q5. Where should the business grow next? Outside the UK,
--            which countries bring the most value per customer?
-- Table:     sales_clean
-- =====================================================================
-- Growth compares two full 12-month periods (Dec-Nov), as in Q1.
-- Revenue per customer uses only rows with a customer ID.
-- =====================================================================


-- ---------------------------------------------------------------------
-- Q5a. UK vs international: share and growth
-- ---------------------------------------------------------------------
WITH base AS (
    SELECT CASE WHEN country = 'United Kingdom' THEN 'UK'
                ELSE 'International' END                          AS market,
           revenue,
           CASE WHEN invoice_date < '2010-12-01' THEN 'Y1'
                WHEN invoice_date < '2011-12-01' THEN 'Y2' END     AS period
    FROM sales_clean
)
SELECT market,
       ROUND(SUM(revenue), 2)                                       AS revenue,
       ROUND(SUM(revenue) * 100 / SUM(SUM(revenue)) OVER (), 1)     AS pct_of_revenue,
       ROUND(SUM(revenue) FILTER (WHERE period = 'Y1'), 2)          AS year1_revenue,
       ROUND(SUM(revenue) FILTER (WHERE period = 'Y2'), 2)          AS year2_revenue,
       ROUND((SUM(revenue) FILTER (WHERE period = 'Y2')
            / SUM(revenue) FILTER (WHERE period = 'Y1') - 1) * 100, 1) AS growth_pct
FROM base
GROUP BY market
ORDER BY revenue DESC;
-- Expected: UK 85.3% of revenue, growth 0.0%
--           International 14.7% (£2.84M), growth +12.1%


-- ---------------------------------------------------------------------
-- Q5b. Top 10 international markets
-- ---------------------------------------------------------------------
SELECT
    country,
    ROUND(SUM(revenue), 2)                                            AS revenue,
    COUNT(DISTINCT customer_id)                                       AS customers,
    COUNT(DISTINCT invoice)                                           AS orders,
    ROUND(SUM(revenue) FILTER (WHERE customer_id IS NOT NULL)
          / NULLIF(COUNT(DISTINCT customer_id), 0), 2)                AS revenue_per_customer,
    ROUND(SUM(revenue) FILTER (WHERE invoice_date < '2010-12-01'), 2) AS year1_revenue,
    ROUND(SUM(revenue) FILTER (WHERE invoice_date >= '2010-12-01'
                                 AND invoice_date <  '2011-12-01'), 2) AS year2_revenue,
    ROUND((SUM(revenue) FILTER (WHERE invoice_date >= '2010-12-01'
                                  AND invoice_date <  '2011-12-01')
         / NULLIF(SUM(revenue) FILTER (WHERE invoice_date < '2010-12-01'), 0)
         - 1) * 100, 1)                                               AS growth_pct
FROM sales_clean
WHERE country <> 'United Kingdom'
GROUP BY country
ORDER BY revenue DESC
LIMIT 10;
-- Expected top 5:
-- EIRE        £623,414 |   3 customers | growth -25.2%
-- Netherlands £549,773 |  22 customers | growth  +2.4%
-- Germany     £383,289 | 107 customers | growth +11.5%
-- France      £311,090 |  93 customers | growth +40.6%
-- Australia   £167,800 |  15 customers | growth +365.1%
