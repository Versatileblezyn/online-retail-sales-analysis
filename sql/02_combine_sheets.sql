-- =====================================================================
-- Project 1: Online Store Sales Analysis
-- File:      02_combine_sheets.sql
-- Purpose:   Combine the two yearly sheets into one table WITHOUT
--            double-counting the 9 days (1-9 Dec 2010) that appear in both.
-- Database:  PostgreSQL
-- =====================================================================
-- Note on dates: Excel saved the CSVs with US-style dates (M/D/YYYY),
-- e.g. '12/1/2009 7:45' = 1 December 2009, 07:45.
-- =====================================================================


-- ---------------------------------------------------------------------
-- 1. Check the dates are read correctly
-- Expected: sheet 1 runs 2009-12-01 07:45 to 2010-12-09 20:01
--           sheet 2 runs 2010-12-01 08:26 to 2011-12-09 12:50
-- ---------------------------------------------------------------------
SELECT 'raw_2009_2010' AS sheet,
       MIN(TO_TIMESTAMP(invoice_date, 'MM/DD/YYYY HH24:MI')::timestamp) AS first_sale,
       MAX(TO_TIMESTAMP(invoice_date, 'MM/DD/YYYY HH24:MI')::timestamp) AS last_sale
FROM raw_2009_2010
UNION ALL
SELECT 'raw_2010_2011',
       MIN(TO_TIMESTAMP(invoice_date, 'MM/DD/YYYY HH24:MI')::timestamp),
       MAX(TO_TIMESTAMP(invoice_date, 'MM/DD/YYYY HH24:MI')::timestamp)
FROM raw_2010_2011;


-- ---------------------------------------------------------------------
-- 2. Prove the overlap
-- Count the rows dated 1-9 Dec 2010 in each sheet, then check whether
-- any of sheet 2's rows are missing from sheet 1.
-- Expected: 22,523 | 22,523 | 0  (identical rows in both sheets)
-- ---------------------------------------------------------------------
WITH sheet1_dec AS (
    SELECT invoice, stock_code, description, quantity,
           invoice_date, price, customer_id, country
    FROM raw_2009_2010
    WHERE TO_TIMESTAMP(invoice_date, 'MM/DD/YYYY HH24:MI')::timestamp
          >= '2010-12-01'
),
sheet2_dec AS (
    SELECT invoice, stock_code, description, quantity,
           invoice_date, price, customer_id, country
    FROM raw_2010_2011
    WHERE TO_TIMESTAMP(invoice_date, 'MM/DD/YYYY HH24:MI')::timestamp
          < '2010-12-10'
)
SELECT
    (SELECT COUNT(*) FROM sheet1_dec) AS sheet1_rows_1_to_9_dec,
    (SELECT COUNT(*) FROM sheet2_dec) AS sheet2_rows_1_to_9_dec,
    (SELECT COUNT(*) FROM (
        SELECT * FROM sheet2_dec
        EXCEPT ALL
        SELECT * FROM sheet1_dec
    ) AS diff)                         AS sheet2_rows_not_in_sheet1;


-- ---------------------------------------------------------------------
-- 3. Combine the sheets: all of sheet 1 + sheet 2 from 10 Dec 2010 on
-- A source_sheet column records where each row came from.
-- ---------------------------------------------------------------------
DROP TABLE IF EXISTS retail_combined;

CREATE TABLE retail_combined AS
SELECT invoice, stock_code, description, quantity,
       invoice_date, price, customer_id, country,
       '2009-2010' AS source_sheet
FROM raw_2009_2010
UNION ALL
SELECT invoice, stock_code, description, quantity,
       invoice_date, price, customer_id, country,
       '2010-2011' AS source_sheet
FROM raw_2010_2011
WHERE TO_TIMESTAMP(invoice_date, 'MM/DD/YYYY HH24:MI')::timestamp
      >= '2010-12-10';


-- ---------------------------------------------------------------------
-- 4. Check the result
-- Expected: 1,067,371 raw rows - 22,523 overlap = 1,044,848
-- ---------------------------------------------------------------------
SELECT
    (SELECT COUNT(*) FROM raw_2009_2010)
  + (SELECT COUNT(*) FROM raw_2010_2011)  AS raw_rows,
    (SELECT COUNT(*) FROM retail_combined) AS combined_rows,
    (SELECT COUNT(*) FROM raw_2009_2010)
  + (SELECT COUNT(*) FROM raw_2010_2011)
  - (SELECT COUNT(*) FROM retail_combined) AS overlap_removed;
