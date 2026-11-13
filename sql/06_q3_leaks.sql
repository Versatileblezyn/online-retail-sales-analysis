-- =====================================================================
-- Project 1: Online Store Sales Analysis
-- File:      06_q3_leaks.sql
-- Question:  Q3. Where is money leaking? How much revenue is lost to
--            cancellations, and which products get cancelled most?
-- Tables:    sales_clean, cancellations_clean, retail_labelled
-- =====================================================================


-- ---------------------------------------------------------------------
-- Q3a. The overall picture
-- ---------------------------------------------------------------------
SELECT
    (SELECT ROUND(SUM(revenue), 2) FROM sales_clean)                 AS gross_revenue,
    (SELECT ROUND(-SUM(cancelled_value), 2) FROM cancellations_clean) AS cancelled_value,
    (SELECT ROUND(SUM(revenue), 2) FROM sales_clean)
  + (SELECT ROUND(SUM(cancelled_value), 2) FROM cancellations_clean) AS net_revenue,
    ROUND((SELECT -SUM(cancelled_value) FROM cancellations_clean)
        / (SELECT SUM(revenue) FROM sales_clean) * 100, 2)          AS cancelled_pct_of_revenue,
    (SELECT COUNT(DISTINCT invoice) FROM cancellations_clean)        AS cancellation_invoices,
    (SELECT COUNT(DISTINCT invoice) FROM sales_clean)                AS sales_invoices;
-- Expected: £19,398,208.42 | £470,809.37 | £18,927,399.05 | 2.43% | 7,404 | 39,514


-- ---------------------------------------------------------------------
-- Q3b. Is it getting better or worse? (full 12-month periods)
-- ---------------------------------------------------------------------
WITH s AS (
    SELECT CASE WHEN invoice_date < '2010-12-01' THEN 'Year 1 (Dec 09 - Nov 10)'
                ELSE 'Year 2 (Dec 10 - Nov 11)' END AS period,
           SUM(revenue) AS revenue
    FROM sales_clean
    WHERE invoice_date < '2011-12-01'
    GROUP BY 1
),
c AS (
    SELECT CASE WHEN invoice_date < '2010-12-01' THEN 'Year 1 (Dec 09 - Nov 10)'
                ELSE 'Year 2 (Dec 10 - Nov 11)' END AS period,
           -SUM(cancelled_value)    AS cancelled,
           COUNT(DISTINCT invoice)  AS cancellation_invoices
    FROM cancellations_clean
    WHERE invoice_date < '2011-12-01'
    GROUP BY 1
)
SELECT s.period,
       ROUND(c.cancelled, 2)                     AS cancelled_value,
       c.cancellation_invoices,
       ROUND(c.cancelled / s.revenue * 100, 2)   AS cancelled_pct_of_revenue
FROM s JOIN c USING (period)
ORDER BY s.period;
-- Expected: Year 1 £240,561.41 | 3,984 | 2.56%
--           Year 2 £224,626.20 | 3,284 | 2.35%


-- ---------------------------------------------------------------------
-- Q3c. Top 10 products by value cancelled, with their cancellation rate
-- (cancelled value as a % of that product's sales)
-- ---------------------------------------------------------------------
WITH cancelled AS (
    SELECT stock_code,
           MODE() WITHIN GROUP (ORDER BY description) AS product,
           -SUM(cancelled_value)                      AS cancelled_value
    FROM cancellations_clean
    GROUP BY stock_code
),
sold AS (
    SELECT stock_code, SUM(revenue) AS sold_value
    FROM sales_clean
    GROUP BY stock_code
)
SELECT c.stock_code,
       c.product,
       ROUND(c.cancelled_value, 2)                          AS cancelled_value,
       ROUND(s.sold_value, 2)                               AS sold_value,
       ROUND(c.cancelled_value / NULLIF(s.sold_value, 0) * 100, 1) AS cancellation_rate_pct
FROM cancelled c
JOIN sold s USING (stock_code)
ORDER BY c.cancelled_value DESC
LIMIT 10;
-- Expected #1: Regency Cakestand 3 Tier, £16,545.30 cancelled (5.0%)
-- Stand-outs: White Cherry Lights 35.6%, Pantry Chopping Board 81.8%


-- ---------------------------------------------------------------------
-- Q3d. The other leak: fees
-- ---------------------------------------------------------------------
SELECT stock_code,
       COUNT(*)                          AS lines,
       ROUND(-SUM(quantity * price), 2)  AS cost_gbp
FROM retail_labelled
WHERE line_type = 'fee'
GROUP BY stock_code
ORDER BY cost_gbp DESC;
-- Expected: AMAZONFEE £221,520.50 | BANK CHARGES £35,482.25 | CRUK £7,933.43
-- Total £264,936.18
