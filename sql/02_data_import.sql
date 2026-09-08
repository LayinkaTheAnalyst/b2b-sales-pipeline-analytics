-- =============================================================
-- Project: B2B Sales Pipeline Analytics
-- File: 02_data_import.sql
-- Purpose: Stage, transform, and validate the source data import
-- Database: MySQL 8+
-- =============================================================

USE maventech_sales;

-- -------------------------------------------------------------
-- 1. Create staging table
-- All fields are initially stored as text to preserve blank
-- values and prevent conversion failures during CSV ingestion.
-- -------------------------------------------------------------

CREATE TABLE IF NOT EXISTS stg_sales_pipeline_import (
    opportunity_id  VARCHAR(20),
    sales_agent     VARCHAR(100),
    product         VARCHAR(50),
    account         VARCHAR(100),
    deal_stage      VARCHAR(20),
    engage_date     VARCHAR(20),
    close_date      VARCHAR(20),
    close_value     VARCHAR(30)
);

-- -------------------------------------------------------------
-- 2. Import sales_pipeline.csv
-- -------------------------------------------------------------
-- MySQL Workbench Table Data Import Wizard was used to load
-- sales_pipeline.csv into stg_sales_pipeline_import.
--
-- Direct import into raw_sales_pipeline loaded only 6,711 of
-- 8,800 records because 2,089 open opportunities contained
-- blank close_date and close_value fields.
--
-- The staging table prevents blank fields from being rejected
-- during type conversion.

-- Confirm complete staging import.
SELECT COUNT(*) AS staging_row_count
FROM stg_sales_pipeline_import;

-- Expected result: 8,800

-- -------------------------------------------------------------
-- 3. Load the typed raw table
-- Run only after staging_row_count returns 8,800.
-- -------------------------------------------------------------

TRUNCATE TABLE raw_sales_pipeline;

INSERT INTO raw_sales_pipeline (
    opportunity_id,
    sales_agent,
    product,
    account,
    deal_stage,
    engage_date,
    close_date,
    close_value
)
SELECT
    TRIM(opportunity_id),
    TRIM(sales_agent),
    TRIM(product),
    NULLIF(TRIM(account), ''),
    TRIM(deal_stage),
    STR_TO_DATE(NULLIF(TRIM(engage_date), ''), '%Y-%m-%d'),
    STR_TO_DATE(NULLIF(TRIM(close_date), ''), '%Y-%m-%d'),
    CAST(NULLIF(TRIM(close_value), '') AS DECIMAL(12,2))
FROM stg_sales_pipeline_import;

-- -------------------------------------------------------------
-- 4. Reconcile imported row counts
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

-- Expected counts:
-- raw_accounts:       85
-- raw_products:        7
-- raw_sales_teams:    35
-- raw_sales_pipeline: 8,800

-- Validate opportunity counts by stage.
SELECT
    deal_stage,
    COUNT(*) AS opportunity_count
FROM raw_sales_pipeline
GROUP BY deal_stage
ORDER BY deal_stage;

-- Expected counts:
-- Engaging:    1,589
-- Lost:        2,473
-- Prospecting:   500
-- Won:         4,238
