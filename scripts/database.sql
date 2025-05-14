/*
 ISDS 570 Data Transformation for Business - Stock Market Case
 Dr. Kalczynski

 https://www.postgresql.org/docs/current/static/sql-expressions.html
 https://www.w3schools.com/SQL/

*/

-------------------------------------------------------------
-- First, let us check the stock market data we have --------
-------------------------------------------------------------

-- What is the date range?
SELECT min(date),max(date) FROM eod_quotes;

-- Really? How many companies have full data in each year?
SELECT date_part('year',date), COUNT(*)/252 FROM eod_quotes GROUP BY date_part('year',date);

-- Let's decide on some practical time range (e.g. 2016-2021)
SELECT ticker, date, adj_close FROM eod_quotes WHERE date BETWEEN '2015-12-31' AND '2021-03-26';

/*

CREATE OR REPLACE VIEW public.v_eod_quotes_2016_2021 AS
SELECT eod_quotes.ticker AS symbol,
       eod_quotes.date,
       eod_quotes.adj_close
FROM eod_quotes
WHERE eod_quotes.date BETWEEN '2016-01-01'::date AND '2021-03-26'::date;

ALTER TABLE public.v_eod_quotes_2016_2021
    OWNER TO postgres;



*/

-- Check
SELECT min(date),max(date) FROM v_eod_quotes_2016_2021;

-------------------------------------------------------------
-- Next, let's us explore the required packages in R --------
-------------------------------------------------------------

-- Install PerformanceAnalytics and PortfolioAnalytics using RStudio

-- Check help

-------------------------------------------------------------------------
-- We have stock quotes but we could also use daily index data ----------
-------------------------------------------------------------------------

-- Let's download 2015-2020 of SP500TR from Yahoo https://finance.yahoo.com/quote/%5ESP500TR/history?p=^SP500TR

-- An analysis of the CSV indicated that to make it compatible with eod
-- - all unusual formatting has to be removed
-- - a "ticker" column with the value SP500TR need to be added 
-- - the volume column has to be updated (zeros are fine)

-- Import the (modified) CSV to a (new) data table eod_indices which reflects the original file's structure

/*

LIFELINE:

-- DROP TABLE public.eod_indices CASCADE;

CREATE TABLE public.eod_indices
(
    symbol character varying(16) COLLATE pg_catalog."default" NOT NULL,
    Date date NOT NULL,
    Open real,
    High real,
    Low real,
    Close real,
    Adj_close real,
    Volume double precision,
    CONSTRAINT eod_indices_pkey PRIMARY KEY (symbol, date)
)
WITH (
    OIDS = FALSE
)
TABLESPACE pg_default;

ALTER TABLE public.eod_indices
    OWNER to postgres;

*/

-- Check
SELECT * FROM eod_indices LIMIT 10;

-- Create a view analogous to our quotes view: v_eod_indices_2015_2020

/*

CREATE OR REPLACE VIEW public.v_eod_indices_2016_2021 AS
SELECT eod_indices.symbol,
       eod_indices.date,
       eod_indices.adj_close
FROM eod_indices
WHERE eod_indices.date BETWEEN '2016-01-01'::date AND '2021-03-26'::date;

ALTER TABLE public.v_eod_indices_2016_2021
    OWNER TO postgres;

*/

-- CHECK
SELECT MIN(date),MAX(date) FROM v_eod_indices_2016_2021;

-- We can combine the two views using UNION which help us later (this will take a while)
SELECT * FROM v_eod_quotes_2016_2021 
UNION 
SELECT * FROM v_eod_indices_2016_2021;

-------------------------------------------------------------------------
-- Next, let's prepare a custom calendar (using a spreadsheet) --------
-------------------------------------------------------------------------

-- We need a stock market calendar to check our data for completeness
-- https://www.nyse.com/markets/hours-calendars

-- Because it is faster, we will use Excel (we need market holidays to do that)

-- We will use NETWORKDAYS.INTL function

-- date, y,m,d,dow,trading (format date and dow!)

-- Save as custom_calendar.csv and import to a new table

/*
LIFELINE:
-- DROP TABLE public.custom_calendar CASCADE;

CREATE TABLE public.custom_calendar
(
    date date NOT NULL,
    y integer,
    m integer,
    d integer,
    dow char(10) COLLATE pg_catalog."default",
    trading int,
    CONSTRAINT custom_calendar_pkey PRIMARY KEY (date)
)
WITH (
    OIDS = FALSE
)
TABLESPACE pg_default;

ALTER TABLE public.custom_calendar
    OWNER to postgres;

*/
-- CHECK:
SELECT * FROM custom_calendar LIMIT 10;

ALTER TABLE public.custom_calendar
ADD COLUMN eom smallint;

ALTER TABLE public.custom_calendar
ADD COLUMN prev_trading_day date;


SELECT COUNT(*) 
FROM custom_calendar 
WHERE trading = 1 
  AND date BETWEEN '2016-01-01' AND '2021-03-26';



-- Now let's populate these columns

-- Identify trading days
SELECT * FROM custom_calendar WHERE trading=1;
-- Identify previous trading days via a nested query
SELECT date, (SELECT MAX(CC.date) FROM custom_calendar CC 
			  WHERE CC.trading=1 AND CC.date<custom_calendar.date) ptd 
			  FROM custom_calendar;
-- Update the table with new data 
UPDATE custom_calendar
SET prev_trading_day = PTD.ptd
FROM (SELECT date, (SELECT MAX(CC.date) FROM custom_calendar CC WHERE CC.trading=1 AND CC.date<custom_calendar.date) ptd FROM custom_calendar) PTD
WHERE custom_calendar.date = PTD.date;
-- CHECK
SELECT * FROM custom_calendar ORDER BY date;

-- Identify the end of the month
SELECT CC.date,CASE WHEN EOM.y IS NULL THEN 0 ELSE 1 END endofm FROM custom_calendar CC LEFT JOIN
(SELECT y,m,MAX(d) lastd FROM custom_calendar WHERE trading=1 GROUP by y,m) EOM
ON CC.y=EOM.y AND CC.m=EOM.m AND CC.d=EOM.lastd;
-- Update the table with new data
UPDATE custom_calendar
SET eom = EOMI.endofm
FROM (SELECT CC.date,CASE WHEN EOM.y IS NULL THEN 0 ELSE 1 END endofm FROM custom_calendar CC LEFT JOIN
(SELECT y,m,MAX(d) lastd FROM custom_calendar WHERE trading=1 GROUP by y,m) EOM
ON CC.y=EOM.y AND CC.m=EOM.m AND CC.d=EOM.lastd) EOMI
WHERE custom_calendar.date = EOMI.date;
-- CHECK
SELECT * FROM custom_calendar ORDER BY date;
SELECT * FROM custom_calendar WHERE eom=1 ORDER BY date;

--------------------------------
----- End of Part 3a -----------
--------------------------------

/*
******** RESTORE POINT stockmarket3
In order to continue learning, you need to have all the previous steps completed
If you would like to review later (and you need to know how to complete these steps).
However, in the interest of time, I have created a backup of the current progress and 
will now demonstrate how to restore it.

IMPORTANT: remove the current database and recreate it to restore from backup
DO NOT RESTORE THE BACKUP TO THE postgres database!
*/

--------------------------------
----- Begin Part 3b -----------
--------------------------------

------------------------------------------------------------------
-- We can now use the calendar to query prices and indexes -------
------------------------------------------------------------------

-- Calculate stock price (or index value) statistics

-- min, average, max and volatility (st.dev) of prices/index values for each month
-- Check other aggregate functions: https://www.postgresql.org/docs/current/static/functions-aggregate.html
-- YOUR TURN: Change v_eod_indices_2015_2020 TO (SELECT * FROM v_eod_indices_2015_2020 UNION SELECT * FROM v_eod_quotes_2015_2020 WHERE ticker='AAPL')

SELECT merged.symbol, CC.y, CC.m,
       MIN(merged.adj_close) AS min_adj_close,
       AVG(merged.adj_close) AS avg_adj_close,
       MAX(merged.adj_close) AS max_adj_close,
       STDDEV_SAMP(merged.adj_close) AS std_adj_close
FROM custom_calendar CC
INNER JOIN (
    SELECT * FROM v_eod_indices_2016_2021
    UNION
    SELECT * FROM v_eod_quotes_2016_2021
) AS merged
ON CC.date = merged.date
GROUP BY merged.symbol, CC.y, CC.m
ORDER BY merged.symbol, CC.y, CC.m;



-- Identify end-of-month prices/values for stock or index
-- Identify end-of-month prices for both stocks and indices (2016-2020)
SELECT merged.*
FROM custom_calendar CC
INNER JOIN (
    SELECT * FROM v_eod_indices_2016_2021
    UNION
    SELECT * FROM v_eod_quotes_2016_2021
) AS merged
ON CC.date = merged.date
WHERE CC.eom = 1
ORDER BY merged.symbol, merged.date;

-- YOUR TURN: Identify end-of-month prices for v_eod_quotes_2015_2020

------------------------------------------------------------------
-- Determine the completeness of price or index data -------------
------------------------------------------------------------------

-- Incompleteness may be due to when the stock was listed/delisted or due to errors

-- First, let's see how many trading days were there between 2015 and 2020
SELECT COUNT(*) 
FROM custom_calendar 
WHERE trading = 1 
  AND date BETWEEN '2016-01-01' AND '2021-03-26';

-- Now, let us check how many price items we have for each stock in the same date range
SELECT symbol,min(date) as min_date, max(date) as max_date, count(*) as price_count
FROM v_eod_quotes_2016_2021
GROUP BY symbol
ORDER BY price_count DESC;

-- Let's calculate the percentage of complete trading day prices for each stock and identify 99%+ complete
SELECT symbol,
       COUNT(*)::real / (
           SELECT COUNT(*) 
           FROM custom_calendar 
           WHERE trading = 1 
             AND date BETWEEN '2016-01-01' AND '2021-03-26'
       )::real AS complete
FROM v_eod_quotes_2016_2021
GROUP BY symbol
HAVING COUNT(*)::real / (
           SELECT COUNT(*) 
           FROM custom_calendar 
           WHERE trading = 1 
             AND date BETWEEN '2016-01-01' AND '2021-03-26'
       )::real >= 0.99
ORDER BY complete DESC;



-- YOUR TURN: try running the above query without casting (remove ::real) - do you know why it does not work?

-- Let's store the excluded tickers (less than 99% complete in a table)
SELECT symbol, 'More than 1% missing' as reason
INTO exclusions_2016_2021
FROM v_eod_quotes_2016_2021
GROUP BY symbol
HAVING count(*)::real/(SELECT COUNT(*) FROM custom_calendar WHERE trading=1 AND date BETWEEN '2016-01-01' AND '2021-03-26')::real<0.99;

-- Also define the PK constraint for exclusions_2015_2020
/*
-- LIFELINE:
ALTER TABLE public.exclusions_2016_2021
    ADD CONSTRAINT exclusions_2016_2021_pkey PRIMARY KEY (symbol);
*/

-- YOUR TURN: apply the same procedure for the indices and store exclusions (if any) in the same table: exclusions_2015_2020

-- CHECK
SELECT * FROM exclusions_2016_2021;

-- We will be adding rows to exclusions_2015_2020 table (for other reasons) later

-- Let combine everything we have (it will take some time to execute)
SELECT * FROM v_eod_indices_2016_2021 
WHERE symbol NOT IN  (SELECT DISTINCT symbol FROM exclusions_2016_2021)
UNION
SELECT * FROM v_eod_quotes_2016_2021
WHERE symbol NOT IN  (SELECT DISTINCT symbol FROM exclusions_2016_2021);

-- And let's store it as a new view v_eod_2015_2020

/*
-- LIFELINE:
-- DROP VIEW public.v_eod_2016_2020 CASCADE;

-- Create clean merged view for 2016–2020 after exclusions
CREATE OR REPLACE VIEW public.v_eod_2016_2021 AS
 SELECT v_eod_indices_2016_2021.symbol,
        v_eod_indices_2016_2021.date,
        v_eod_indices_2016_2021.adj_close
   FROM v_eod_indices_2016_2021
  WHERE v_eod_indices_2016_2021.symbol NOT IN ( 
      SELECT DISTINCT symbol
      FROM exclusions_2016_2021
    )

UNION

 SELECT v_eod_quotes_2016_2021.symbol,
        v_eod_quotes_2016_2021.date,
        v_eod_quotes_2016_2021.adj_close
   FROM v_eod_quotes_2016_2021
  WHERE v_eod_quotes_2016_2021.symbol NOT IN ( 
      SELECT DISTINCT symbol
      FROM exclusions_2016_2021
    );

ALTER TABLE public.v_eod_2016_2021
    OWNER TO postgres;



*/
SELECT * 
FROM v_eod_quotes_2016_2021
LIMIT 5;

-- CHECK:
SELECT MIN(date) AS start_date, MAX(date) AS end_date FROM v_eod_2016_2021;
SELECT * FROM v_eod_2016_2021; -- slow
SELECT DISTINCT symbol FROM v_eod_2016_2021;

-- Let's create a materialized view mv_eod_2015_2020

/*
--LIFELINE

-- DROP MATERIALIZED VIEW public.mv_eod_2016_2021;
-- DROP MATERIALIZED VIEW IF EXISTS public.mv_eod_2016_2021;
DROP MATERIALIZED VIEW IF EXISTS mv_eod_2016_2021 CASCADE;


CREATE MATERIALIZED VIEW public.mv_eod_2016_2021
TABLESPACE pg_default
AS
 SELECT v_eod_indices_2016_2021.symbol,
        v_eod_indices_2016_2021.date,
        v_eod_indices_2016_2021.adj_close
   FROM v_eod_indices_2016_2021
  WHERE v_eod_indices_2016_2021.symbol NOT IN ( 
      SELECT DISTINCT symbol
      FROM exclusions_2016_2021
    )

UNION

 SELECT v_eod_quotes_2016_2021.symbol,
        v_eod_quotes_2016_2021.date,
        v_eod_quotes_2016_2021.adj_close
   FROM v_eod_quotes_2016_2021
  WHERE v_eod_quotes_2016_2021.symbol NOT IN ( 
      SELECT DISTINCT symbol
      FROM exclusions_2016_2021
    )
WITH NO DATA;

ALTER TABLE public.mv_eod_2016_2021
    OWNER TO postgres;



*/
-- We must refresh it (it will take time but it is one-time or infrequent)
REFRESH MATERIALIZED VIEW mv_eod_2016_2021 WITH DATA;

-- CHECK
SELECT * FROM mv_eod_2016_2021; -- faster
SELECT DISTINCT symbol FROM mv_eod_2016_2021; -- fast
SELECT * FROM mv_eod_2016_2021 WHERE symbol='AAPL' ORDER BY date;
SELECT * FROM mv_eod_2016_2021 WHERE symbol='SP500TR' ORDER BY date;

-- We can even add a couple of indexes to our materialized view if we want to speed up access some more

--------------------------------------------------------
-- Calculate daily returns or changes ------------------
--------------------------------------------------------

-- We will assume the following definition R_1=(P_1-P_0)/P_0=P_1/P_0-1.0 (P:price, i.e., adj_close)

-- First let us join the calendar with the prices (and indices)

SELECT EOD.*, CC.* 
FROM mv_eod_2016_2021 EOD INNER JOIN custom_calendar CC ON EOD.date=CC.date;

-- Next, let us use the prev_trading_day in a join to determine prev_adj_close (this will take some time)
SELECT EOD.symbol,EOD.date,EOD.adj_close,PREV_EOD.date AS prev_date,PREV_EOD.adj_close AS prev_adj_close
FROM mv_eod_2016_2021 EOD INNER JOIN custom_calendar CC ON EOD.date=CC.date
INNER JOIN mv_eod_2016_2021 PREV_EOD ON PREV_EOD.symbol=EOD.symbol AND PREV_EOD.date=CC.prev_trading_day;

-- Change the columns in the select clause to return (ret) and create another materialized view mv_ret_2015_2020
SELECT EOD.symbol,EOD.date,EOD.adj_close/PREV_EOD.adj_close-1.0 AS ret
FROM mv_eod_2016_2021 EOD INNER JOIN custom_calendar CC ON EOD.date=CC.date
INNER JOIN mv_eod_2016_2021 PREV_EOD ON PREV_EOD.symbol=EOD.symbol AND PREV_EOD.date=CC.prev_trading_day;

-- Let's make another materialized view - this time with the returns

/*
-- LIFELINE:

-- DROP MATERIALIZED VIEW public.mv_ret_2015_2020;

CREATE MATERIALIZED VIEW public.mv_ret_2016_2021
TABLESPACE pg_default
AS
 SELECT eod.symbol,
    eod.date,
    (eod.adj_close / prev_eod.adj_close - 1.0)::double precision AS ret
   FROM mv_eod_2016_2021 eod
     JOIN custom_calendar cc ON eod.date = cc.date
     JOIN mv_eod_2016_2021 prev_eod ON prev_eod.symbol::text = eod.symbol::text AND prev_eod.date = cc.prev_trading_day
WITH NO DATA;

ALTER TABLE public.mv_ret_2016_2021
    OWNER TO postgres;
*/

-- We must refresh it (it will take time but it is one-time or infrequent)
REFRESH MATERIALIZED VIEW mv_ret_2016_2021 WITH DATA;

-- CHECK
SELECT * FROM mv_ret_2016_2021;
SELECT * FROM mv_ret_2016_2021 WHERE symbol='AAPL' ORDER BY date;
SELECT * FROM mv_ret_2016_2021 WHERE symbol='SP500TR' ORDER BY date;

------------------------------------------------------------------
-- Identify potential errors and expand the exlusions list --------
------------------------------------------------------------------

-- Let's explore first
SELECT min(ret),avg(ret),max(ret) from mv_ret_2016_2021;
SELECT * FROM mv_ret_2016_2021 ORDER BY ret DESC;

-- Make an arbitrary decision how much daily return is too much (e.g. 100%), identify such symbols
-- and add them to exclusions_2015_2020
INSERT INTO exclusions_2016_2021
SELECT DISTINCT symbol, 'Return higher than 100%' AS reason FROM mv_ret_2016_2021 WHERE ret > 1.0;

-- Check which stocks were inserted due to Return > 100%
SELECT * FROM exclusions_2016_2021 WHERE reason LIKE 'Return%' ORDER BY symbol;

-- They should be excluded BUT THEY ARE NOT YET!
SELECT * FROM mv_eod_2016_2021 WHERE symbol='GWPH'; -- Example problematic stock
SELECT * FROM mv_ret_2016_2021 WHERE symbol='GWPH' ORDER BY ret DESC;

-- IMPORTANT: Stored (materialized) views must be refreshed AFTER updating exclusions
REFRESH MATERIALIZED VIEW mv_eod_2016_2021 WITH DATA;
-- Check again if excluded properly
SELECT * FROM mv_eod_2016_2021 WHERE symbol='GWPH'; -- should NOT return any rows

-- Then refresh the returns view too
REFRESH MATERIALIZED VIEW mv_ret_2016_2021 WITH DATA;
-- Final check
SELECT * FROM mv_ret_2016_2021 WHERE symbol='GWPH'; -- should NOT return any rows


-- CHECK:
SELECT * FROM exclusions_2016_2021 WHERE reason LIKE 'Return%' ORDER BY symbol;
-- They should be excluded BUT THEY ARE NOT!
SELECT * FROM mv_eod_2016_2021 WHERE symbol='GWPH';
SELECT * FROM mv_ret_2016_2021 WHERE symbol='GWPH' ORDER BY ret DESC;
-- IMPORTANT: we have stored (materialized) views, we need to refresh them IN A SEQUENCE!
REFRESH MATERIALIZED VIEW mv_eod_2016_2021 WITH DATA;
-- CHECK:
SELECT * FROM mv_eod_2016_2021 WHERE symbol='GWPH'; -- excluded

REFRESH MATERIALIZED VIEW mv_ret_2016_2021 WITH DATA;
-- CHECK:
SELECT * FROM mv_ret_2015_2020 WHERE symbol='GWPH'; -- excluded
-- We can continue adding exclusions for various reasons - remember to refresh the stored views



---------------------------------------------------------------------------
-- Format price and return data for export to the analytical tool  --------
---------------------------------------------------------------------------

-- In order to export all data we will left-join custom_calendar with materialized views
-- This way we will not miss a trading day even if there is not a single record available
-- It is very important when data is updated daily

-- We may need to write data to (temporary) tables so that we can export them to CSV
-- Or we can select the query and use "Download as CSV (F8)" in PgAdmin

-- Daily prices export
SELECT PR.* 
INTO export_daily_prices_2016_2021
FROM custom_calendar CC LEFT JOIN mv_eod_2016_2021 PR ON CC.date = PR.date
WHERE CC.trading = 1;

-- Monthly (eom) prices export
SELECT PR.* 
INTO export_monthly_prices_2016_2021
FROM custom_calendar CC LEFT JOIN mv_eod_2016_2021 PR ON CC.date=PR.date
WHERE CC.trading=1 AND CC.eom=1;

-- Daily returns export
SELECT PR.* 
INTO export_daily_returns_2016_2021
FROM custom_calendar CC LEFT JOIN mv_ret_2016_2021 PR ON CC.date=PR.date
WHERE CC.trading=1;

SELECT * FROM export_daily_prices_2016_2021 LIMIT 10;
SELECT * FROM export_monthly_prices_2016_2021 LIMIT 10;
SELECT * FROM export_daily_returns_2016_2021 LIMIT 10;

-- Monthly returns 
-- Do not fall for this trap - you need to compute monthly returns based on eom data
-- We will do it in R (easiest) but you could follow a procedure analogous to the one 
-- we used to compute daily returns

-- YOUR TURN: Let's export price and return data as CSV files (header, comma as delimiter)
-- CHECK the CSV files (Excel will only load about 1M rows)
-- Remove temporary (export_) tables because they are not refreshed
DROP TABLE export_daily_prices_2016_2021;
DROP TABLE export_monthly_prices_2016_2021;
DROP TABLE export_daily_returns_2016_2021;

SELECT * 
FROM crosstab(
  'SELECT date, symbol, adj_close FROM mv_eod_2016_2020 ORDER BY 1,2',
  'SELECT DISTINCT symbol FROM mv_eod_2015_2020 ORDER BY 1'
) 
AS ct(dte date, A real);

-- Technically we could code a custom return type but it would be very tedious and one-time
-- The problem here is that we need to manually define return types for all 2000+ stock tickers
-- If you think you can work-around that with /crosstabview (PSQL) - you can't because of 1600 columns limit
-- So, we will deal with pivoting in R (Excel will not take 6M+ rows)

-------------------------------------------
-- Create a role for the database  --------
-------------------------------------------
-- rolename: stockmarketreader
-- password: read123

/*
-- LIFELINE:
-- REVOKE ALL PRIVILEGES ON ALL TABLES IN SCHEMA public FROM stockmarketreader;
-- DROP USER stockmarketreader;

CREATE USER stockmarketreader WITH
	LOGIN
	NOSUPERUSER
	NOCREATEDB
	NOCREATEROLE
	INHERIT
	NOREPLICATION
	CONNECTION LIMIT -1
	PASSWORD 'read123';
*/

-- Grant read rights (on existing tables and views)
GRANT SELECT ON ALL TABLES IN SCHEMA public TO stockmarketreader;

-- Grant read rights (for future tables and views)
ALTER DEFAULT PRIVILEGES IN SCHEMA public
   GRANT SELECT ON TABLES TO stockmarketreader;
   

----------------------------------
-- For homework/projects  --------
----------------------------------

SELECT LEFT(symbol,1) letter,COUNT(*) as no_of_symbols
FROM
(SELECT DISTINCT symbol FROM mv_eod_2015_2020) S
GROUP BY LEFT(symbol,1)
ORDER BY letter;

--------------------------------
----- End of Part 3b -----------
--------------------------------

/*
******** RESTORE POINT stockmarket4
In order to continue learning, you need to have all the previous steps completed
If you would like to review later (and you need to know how to complete these steps).
However, in the interest of time, I have created a backup of the current progress and 
will now demonstrate how to restore it.

IMPORTANT: remove the current database and recreate it to restore from backup
DO NOT RESTORE THE BACKUP TO THE postgres database!
*/



SELECT MIN(date) AS start_date, MAX(date) AS end_date FROM eod_quotes;

SELECT MIN(date) AS start_date, MAX(date) AS end_date FROM eod_indices;

SELECT MIN(date) AS start_date, MAX(date) AS end_date FROM custom_calendar;

SELECT MIN(date) AS start_date, MAX(date) AS end_date FROM v_eod_quotes_2016_2020;

SELECT MIN(date) AS start_date, MAX(date) AS end_date FROM v_eod_indices_2016_2020;

SELECT MIN(date) AS start_date, MAX(date) AS end_date FROM v_eod_2016_2020;

SELECT MIN(date) AS start_date, MAX(date) AS end_date FROM mv_eod_2016_2021;
