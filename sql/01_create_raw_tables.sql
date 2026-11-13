-- =====================================================================
-- Project 1: Online Store Sales Analysis
-- File:      01_create_raw_tables.sql
-- Purpose:   Create two staging tables that hold the raw data exactly
--            as it comes from the Excel file (one table per sheet).
-- Database:  PostgreSQL
-- =====================================================================
-- Why every column is TEXT:
-- The raw data is messy (blank IDs, invoice codes like 'C489449' and
-- 'A506401', dates in a local format). Loading everything as text means
-- nothing gets rejected or silently changed on import. Data types are
-- fixed later, in the cleaning step, where every change is visible.
-- =====================================================================

DROP TABLE IF EXISTS raw_2009_2010;
DROP TABLE IF EXISTS raw_2010_2011;

-- Sheet 1: Year 2009-2010 (expected rows: 525,461)
CREATE TABLE raw_2009_2010 (
    invoice       TEXT,
    stock_code    TEXT,
    description   TEXT,
    quantity      TEXT,
    invoice_date  TEXT,
    price         TEXT,
    customer_id   TEXT,
    country       TEXT
);

-- Sheet 2: Year 2010-2011 (expected rows: 541,910)
CREATE TABLE raw_2010_2011 (
    invoice       TEXT,
    stock_code    TEXT,
    description   TEXT,
    quantity      TEXT,
    invoice_date  TEXT,
    price         TEXT,
    customer_id   TEXT,
    country       TEXT
);

-- ---------------------------------------------------------------------
-- Load the CSVs (each Excel sheet saved as CSV from Excel).
-- Files are placed in C:\Users\Public\ so PostgreSQL can read them.
-- ENCODING 'WIN1252': Excel saved the files in Windows encoding, and
-- the load failed on the first £ sign (byte 0xa3) without it.
-- TRUNCATE first, so re-running never loads the data twice.
-- ---------------------------------------------------------------------
TRUNCATE raw_2009_2010, raw_2010_2011;

COPY raw_2009_2010
FROM 'C:\Users\Public\raw_2009_2010.csv'
WITH (FORMAT csv, HEADER true, ENCODING 'WIN1252');

COPY raw_2010_2011
FROM 'C:\Users\Public\raw_2010_2011.csv'
WITH (FORMAT csv, HEADER true, ENCODING 'WIN1252');

-- ---------------------------------------------------------------------
-- Check nothing was lost:
-- ---------------------------------------------------------------------
SELECT 'raw_2009_2010' AS table_name, COUNT(*) AS row_count FROM raw_2009_2010
UNION ALL
SELECT 'raw_2010_2011', COUNT(*) FROM raw_2010_2011;
-- Expected: 525,461 and 541,910

-- Quick look at the first rows of each table
SELECT * FROM raw_2009_2010 LIMIT 10;
SELECT * FROM raw_2010_2011 LIMIT 10;
