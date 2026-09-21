-- =============================================================
-- Project: B2B Sales Pipeline Analytics
-- File: 03_data_quality.sql
-- Purpose: Assess completeness, validity, consistency, and
--          relational integrity before cleaning or analysis
-- Database: MySQL 8+
-- =============================================================

USE maventech_sales;

-- This script is diagnostic only. It does not modify source data.

-- -------------------------------------------------------------
-- 1. ROW-COUNT RECONCILIATION
-- -------------------------------------------------------------

SELECT 'raw_accounts' AS table_name, COUNT(*) AS row_count
FROM raw_accounts
UNION ALL
SELECT 'raw_products', COUNT(*)
FROM raw_products
UNION ALL
SELECT 'raw_sales_teams', COUNT(*)
FROM raw_sales_teams
UNION ALL
SELECT 'raw_sales_pipeline', COUNT(*)
FROM raw_sales_pipeline;

-- Expected: accounts 85; products 7; teams 35; pipeline 8,800.

-- -------------------------------------------------------------
-- 2. DUPLICATE KEY CHECKS
-- -------------------------------------------------------------

SELECT opportunity_id, COUNT(*) AS occurrences
FROM raw_sales_pipeline
GROUP BY opportunity_id
HAVING COUNT(*) > 1;

SELECT account, COUNT(*) AS occurrences
FROM raw_accounts
GROUP BY account
HAVING COUNT(*) > 1;

SELECT product, COUNT(*) AS occurrences
FROM raw_products
GROUP BY product
HAVING COUNT(*) > 1;

SELECT sales_agent, COUNT(*) AS occurrences
FROM raw_sales_teams
GROUP BY sales_agent
HAVING COUNT(*) > 1;

-- Expected: zero rows returned by every query.

-- -------------------------------------------------------------
-- 3. COMPLETENESS CHECKS
-- -------------------------------------------------------------

SELECT
    COUNT(*) AS total_opportunities,
    SUM(opportunity_id IS NULL OR TRIM(opportunity_id) = '') AS missing_opportunity_id,
    SUM(sales_agent IS NULL OR TRIM(sales_agent) = '') AS missing_sales_agent,
    SUM(product IS NULL OR TRIM(product) = '') AS missing_product,
    SUM(account IS NULL OR TRIM(account) = '') AS missing_account,
    SUM(deal_stage IS NULL OR TRIM(deal_stage) = '') AS missing_deal_stage,
    SUM(engage_date IS NULL) AS missing_engage_date,
    SUM(close_date IS NULL) AS missing_close_date,
    SUM(close_value IS NULL) AS missing_close_value
FROM raw_sales_pipeline;

-- Review missing values by stage to distinguish expected blanks
-- from potential data-quality problems.
SELECT
    deal_stage,
    COUNT(*) AS opportunity_count,
    SUM(account IS NULL OR TRIM(account) = '') AS missing_account,
    SUM(engage_date IS NULL) AS missing_engage_date,
    SUM(close_date IS NULL) AS missing_close_date,
    SUM(close_value IS NULL) AS missing_close_value
FROM raw_sales_pipeline
GROUP BY deal_stage
ORDER BY deal_stage;

SELECT
    COUNT(*) AS total_accounts,
    SUM(subsidiary_of IS NULL OR TRIM(subsidiary_of) = '') AS missing_parent_company
FROM raw_accounts;

-- -------------------------------------------------------------
-- 4. DOMAIN AND CATEGORY CHECKS
-- -------------------------------------------------------------

SELECT deal_stage, COUNT(*) AS opportunity_count
FROM raw_sales_pipeline
GROUP BY deal_stage
ORDER BY deal_stage;

SELECT product, COUNT(*) AS opportunity_count
FROM raw_sales_pipeline
GROUP BY product
ORDER BY product;

SELECT sector, COUNT(*) AS account_count
FROM raw_accounts
GROUP BY sector
ORDER BY sector;

SELECT office_location, COUNT(*) AS account_count
FROM raw_accounts
GROUP BY office_location
ORDER BY office_location;

SELECT regional_office, COUNT(*) AS agent_count
FROM raw_sales_teams
GROUP BY regional_office
ORDER BY regional_office;

-- -------------------------------------------------------------
-- 5. STAGE, DATE, AND VALUE LOGIC
-- -------------------------------------------------------------

-- Closed opportunities should have engagement dates, closure
-- dates, and recorded values.
SELECT *
FROM raw_sales_pipeline
WHERE deal_stage IN ('Won', 'Lost')
  AND (engage_date IS NULL
       OR close_date IS NULL
       OR close_value IS NULL);

-- Open opportunities should not yet have closure information.
SELECT *
FROM raw_sales_pipeline
WHERE deal_stage IN ('Prospecting', 'Engaging')
  AND (close_date IS NOT NULL OR close_value IS NOT NULL);

-- Engaging opportunities should have an engagement date.
SELECT *
FROM raw_sales_pipeline
WHERE deal_stage = 'Engaging'
  AND engage_date IS NULL;

-- Prospecting opportunities should not yet have an engagement date.
SELECT *
FROM raw_sales_pipeline
WHERE deal_stage = 'Prospecting'
  AND engage_date IS NOT NULL;

-- Closure cannot occur before engagement.
SELECT
    opportunity_id,
    engage_date,
    close_date,
    DATEDIFF(close_date, engage_date) AS sales_cycle_days
FROM raw_sales_pipeline
WHERE close_date < engage_date;

-- Won deals should have positive revenue; lost deals should not
-- generate revenue in this dataset.
SELECT *
FROM raw_sales_pipeline
WHERE (deal_stage = 'Won' AND close_value <= 0)
   OR (deal_stage = 'Lost' AND close_value <> 0);

-- Check for unrecognized stages.
SELECT DISTINCT deal_stage
FROM raw_sales_pipeline
WHERE deal_stage NOT IN ('Prospecting', 'Engaging', 'Won', 'Lost');

-- -------------------------------------------------------------
-- 6. RELATIONAL INTEGRITY CHECKS
-- -------------------------------------------------------------

-- Pipeline agents missing from the sales-team roster.
SELECT DISTINCT p.sales_agent
FROM raw_sales_pipeline AS p
LEFT JOIN raw_sales_teams AS t
    ON p.sales_agent = t.sales_agent
WHERE t.sales_agent IS NULL;

-- Pipeline products missing from the product catalogue.
SELECT
    p.product,
    COUNT(*) AS affected_opportunities
FROM raw_sales_pipeline AS p
LEFT JOIN raw_products AS pr
    ON p.product = pr.product
WHERE pr.product IS NULL
GROUP BY p.product
ORDER BY affected_opportunities DESC;

-- Named pipeline accounts missing from the account table.
SELECT
    p.account,
    COUNT(*) AS affected_opportunities
FROM raw_sales_pipeline AS p
LEFT JOIN raw_accounts AS a
    ON p.account = a.account
WHERE p.account IS NOT NULL
  AND a.account IS NULL
GROUP BY p.account
ORDER BY affected_opportunities DESC;

-- Parent-company names missing from the account table.
SELECT DISTINCT a.subsidiary_of
FROM raw_accounts AS a
LEFT JOIN raw_accounts AS parent
    ON a.subsidiary_of = parent.account
WHERE a.subsidiary_of IS NOT NULL
  AND parent.account IS NULL;

-- Sales agents with no recorded opportunities.
SELECT
    t.sales_agent,
    t.manager,
    t.regional_office
FROM raw_sales_teams AS t
LEFT JOIN raw_sales_pipeline AS p
    ON t.sales_agent = p.sales_agent
WHERE p.opportunity_id IS NULL
ORDER BY t.sales_agent;

-- Products with no recorded opportunities.
SELECT pr.product
FROM raw_products AS pr
LEFT JOIN raw_sales_pipeline AS p
    ON pr.product = p.product
WHERE p.opportunity_id IS NULL
ORDER BY pr.product;

-- Accounts with no recorded opportunities.
SELECT a.account
FROM raw_accounts AS a
LEFT JOIN raw_sales_pipeline AS p
    ON a.account = p.account
WHERE p.opportunity_id IS NULL
ORDER BY a.account;

-- -------------------------------------------------------------
-- 7. RANGE AND PLAUSIBILITY CHECKS
-- -------------------------------------------------------------

SELECT
    MIN(year_established) AS earliest_year,
    MAX(year_established) AS latest_year,
    MIN(revenue) AS minimum_revenue_millions,
    MAX(revenue) AS maximum_revenue_millions,
    MIN(employees) AS minimum_employees,
    MAX(employees) AS maximum_employees
FROM raw_accounts;

SELECT
    MIN(sales_price) AS minimum_sales_price,
    MAX(sales_price) AS maximum_sales_price
FROM raw_products;

SELECT
    MIN(engage_date) AS first_engagement_date,
    MAX(engage_date) AS last_engagement_date,
    MIN(close_date) AS first_close_date,
    MAX(close_date) AS last_close_date,
    MIN(CASE WHEN deal_stage = 'Won' THEN close_value END) AS minimum_won_value,
    MAX(CASE WHEN deal_stage = 'Won' THEN close_value END) AS maximum_won_value
FROM raw_sales_pipeline;

-- Sales-cycle distribution for completed opportunities.
SELECT
    deal_stage,
    MIN(DATEDIFF(close_date, engage_date)) AS minimum_days,
    ROUND(AVG(DATEDIFF(close_date, engage_date)), 1) AS average_days,
    MAX(DATEDIFF(close_date, engage_date)) AS maximum_days
FROM raw_sales_pipeline
WHERE deal_stage IN ('Won', 'Lost')
GROUP BY deal_stage;

-- -------------------------------------------------------------
-- 8. PRICE CONSISTENCY REVIEW
-- -------------------------------------------------------------

-- Compare won deal values with suggested product prices. Records
-- with unmatched product labels are reported in Section 6 and
-- will not appear here until standardized.
SELECT
    p.product,
    pr.sales_price AS suggested_price,
    COUNT(*) AS won_deals,
    ROUND(AVG(p.close_value), 2) AS average_close_value,
    MIN(p.close_value) AS minimum_close_value,
    MAX(p.close_value) AS maximum_close_value,
    ROUND(AVG(p.close_value / NULLIF(pr.sales_price, 0)) * 100, 1)
        AS average_price_realization_pct
FROM raw_sales_pipeline AS p
INNER JOIN raw_products AS pr
    ON p.product = pr.product
WHERE p.deal_stage = 'Won'
GROUP BY p.product, pr.sales_price
ORDER BY average_close_value DESC;

-- -------------------------------------------------------------
-- END OF DATA-QUALITY ASSESSMENT
-- Record confirmed issues and treatment decisions in:
-- documentation/data_quality_report.md
-- -------------------------------------------------------------
