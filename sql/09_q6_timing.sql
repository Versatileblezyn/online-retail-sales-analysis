-- =====================================================================
-- Project 1: Online Store Sales Analysis
-- File:      09_q6_timing.sql
-- Question:  Q6. When should the owner prepare? When do sales peak by
--            month, weekday and hour?
-- Table:     sales_clean
-- =====================================================================


-- ---------------------------------------------------------------------
-- Q6a. Sales by month (two full years, Dec 2009 - Nov 2011, so every
-- month appears exactly twice)
-- ---------------------------------------------------------------------
SELECT
    EXTRACT(MONTH FROM invoice_date)                              AS month_no,
    TO_CHAR(MIN(invoice_date), 'Month')                           AS month,
    ROUND(SUM(revenue) / 2, 2)                                    AS avg_revenue_per_year,
    ROUND(SUM(revenue) * 100 / SUM(SUM(revenue)) OVER (), 1)      AS pct_of_year
FROM sales_clean
WHERE invoice_date < '2011-12-01'
GROUP BY EXTRACT(MONTH FROM invoice_date)
ORDER BY month_no;
-- Expected: November 15.2% (avg £1.44M), October 11.6%, September 10.0%
--           Sep-Nov together = 36.8% of the year; February lowest at 5.5%


-- ---------------------------------------------------------------------
-- Q6b. Sales by weekday (revenue per trading day, so days with more
-- or fewer occurrences are compared fairly)
-- ---------------------------------------------------------------------
SELECT
    EXTRACT(ISODOW FROM invoice_date)                          AS day_no,
    TO_CHAR(MIN(invoice_date), 'Day')                          AS weekday,
    COUNT(DISTINCT invoice_date::date)                         AS trading_days,
    COUNT(DISTINCT invoice)                                    AS orders,
    ROUND(SUM(revenue), 2)                                     AS revenue,
    ROUND(SUM(revenue) * 100 / SUM(SUM(revenue)) OVER (), 1)   AS pct_of_revenue,
    ROUND(SUM(revenue) / COUNT(DISTINCT invoice_date::date), 2) AS revenue_per_trading_day
FROM sales_clean
GROUP BY EXTRACT(ISODOW FROM invoice_date)
ORDER BY day_no;
-- Expected: Thursday highest (20.7%, ~£38.9K per day)
--           Sunday lowest regular day (9.2%, ~£18.0K per day)
--           Saturday: only 1 trading day in two years (shop closed)


-- ---------------------------------------------------------------------
-- Q6c. Sales by hour of the day
-- ---------------------------------------------------------------------
SELECT
    EXTRACT(HOUR FROM invoice_date)                             AS hour,
    COUNT(DISTINCT invoice)                                     AS orders,
    ROUND(SUM(revenue), 2)                                      AS revenue,
    ROUND(SUM(revenue) * 100 / SUM(SUM(revenue)) OVER (), 1)    AS pct_of_revenue
FROM sales_clean
GROUP BY EXTRACT(HOUR FROM invoice_date)
ORDER BY hour;
-- Expected: peak at 12:00 (14.4%); 10:00-15:59 = 75.1% of revenue
