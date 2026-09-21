-- =============================================================
-- Project: B2B Sales Pipeline Analytics
-- File: 04_data_cleaning.sql
-- Purpose: Build a clean analytical layer from the raw tables
-- Database: MySQL 8+
-- =============================================================

USE maventech_sales;

-- The raw tables are never updated in this script. Instead, the
-- approved corrections are applied while creating a separate set
-- of dimension and fact tables for analysis and Power BI.

-- -------------------------------------------------------------
-- 1. REBUILD THE CLEAN ANALYTICAL LAYER
-- -------------------------------------------------------------
-- Dropping the fact table first avoids foreign-key dependency
-- errors and makes the script safe to rerun during development.

DROP TABLE IF EXISTS fact_sales_pipeline;
DROP TABLE IF EXISTS dim_sales_agents;
DROP TABLE IF EXISTS dim_products;
DROP TABLE IF EXISTS dim_accounts;

-- -------------------------------------------------------------
-- 2. CREATE AND LOAD THE ACCOUNT DIMENSION
-- -------------------------------------------------------------

CREATE TABLE dim_accounts (
    account             VARCHAR(100) NOT NULL,
    sector              VARCHAR(50) NOT NULL,
    year_established    SMALLINT UNSIGNED NOT NULL,
    revenue_millions    DECIMAL(12,2) NOT NULL,
    employees           INT UNSIGNED NOT NULL,
    office_location     VARCHAR(100) NOT NULL,
    subsidiary_of       VARCHAR(100) NULL,
    PRIMARY KEY (account),
    INDEX idx_dim_accounts_sector (sector),
    INDEX idx_dim_accounts_location (office_location)
);

INSERT INTO dim_accounts (
    account,
    sector,
    year_established,
    revenue_millions,
    employees,
    office_location,
    subsidiary_of
)
SELECT
    TRIM(account),
    CASE
        WHEN TRIM(sector) = 'technolgy' THEN 'technology'
        ELSE TRIM(sector)
    END AS sector,
    year_established,
    revenue,
    employees,
    CASE
        WHEN TRIM(office_location) = 'Philipines' THEN 'Philippines'
        ELSE TRIM(office_location)
    END AS office_location,
    NULLIF(TRIM(subsidiary_of), '') AS subsidiary_of
FROM raw_accounts;

-- -------------------------------------------------------------
-- 3. CREATE AND LOAD THE PRODUCT DIMENSION
-- -------------------------------------------------------------

CREATE TABLE dim_products (
    product             VARCHAR(50) NOT NULL,
    series              VARCHAR(20) NOT NULL,
    suggested_price     DECIMAL(12,2) NOT NULL,
    PRIMARY KEY (product),
    INDEX idx_dim_products_series (series)
);

INSERT INTO dim_products (
    product,
    series,
    suggested_price
)
SELECT
    TRIM(product),
    TRIM(series),
    sales_price
FROM raw_products;

-- -------------------------------------------------------------
-- 4. CREATE AND LOAD THE SALES-AGENT DIMENSION
-- -------------------------------------------------------------

CREATE TABLE dim_sales_agents (
    sales_agent         VARCHAR(100) NOT NULL,
    manager             VARCHAR(100) NOT NULL,
    regional_office     VARCHAR(20) NOT NULL,
    PRIMARY KEY (sales_agent),
    INDEX idx_dim_agents_manager (manager),
    INDEX idx_dim_agents_region (regional_office)
);

INSERT INTO dim_sales_agents (
    sales_agent,
    manager,
    regional_office
)
SELECT
    TRIM(sales_agent),
    TRIM(manager),
    TRIM(regional_office)
FROM raw_sales_teams;

-- -------------------------------------------------------------
-- 5. CREATE AND LOAD THE SALES-PIPELINE FACT TABLE
-- -------------------------------------------------------------

CREATE TABLE fact_sales_pipeline (
    opportunity_id      CHAR(8) NOT NULL,
    sales_agent         VARCHAR(100) NOT NULL,
    product             VARCHAR(50) NOT NULL,
    account             VARCHAR(100) NULL,
    deal_stage          VARCHAR(20) NOT NULL,
    engage_date         DATE NULL,
    close_date          DATE NULL,
    close_value         DECIMAL(12,2) NULL,
    sales_cycle_days    SMALLINT UNSIGNED NULL,
    PRIMARY KEY (opportunity_id),
    INDEX idx_fact_agent (sales_agent),
    INDEX idx_fact_product (product),
    INDEX idx_fact_account (account),
    INDEX idx_fact_stage (deal_stage),
    INDEX idx_fact_engage_date (engage_date),
    INDEX idx_fact_close_date (close_date),
    CONSTRAINT fk_fact_agent
        FOREIGN KEY (sales_agent)
        REFERENCES dim_sales_agents (sales_agent),
    CONSTRAINT fk_fact_product
        FOREIGN KEY (product)
        REFERENCES dim_products (product),
    CONSTRAINT fk_fact_account
        FOREIGN KEY (account)
        REFERENCES dim_accounts (account),
    CONSTRAINT chk_fact_deal_stage
        CHECK (deal_stage IN ('Prospecting', 'Engaging', 'Won', 'Lost')),
    CONSTRAINT chk_fact_date_order
        CHECK (close_date IS NULL OR engage_date IS NULL OR close_date >= engage_date)
);

INSERT INTO fact_sales_pipeline (
    opportunity_id,
    sales_agent,
    product,
    account,
    deal_stage,
    engage_date,
    close_date,
    close_value,
    sales_cycle_days
)
SELECT
    TRIM(opportunity_id),
    TRIM(sales_agent),
    CASE
        WHEN TRIM(product) = 'GTXPro' THEN 'GTX Pro'
        ELSE TRIM(product)
    END AS product,
    NULLIF(TRIM(account), '') AS account,
    TRIM(deal_stage),
    engage_date,
    close_date,
    close_value,
    CASE
        WHEN engage_date IS NOT NULL AND close_date IS NOT NULL
            THEN DATEDIFF(close_date, engage_date)
        ELSE NULL
    END AS sales_cycle_days
FROM raw_sales_pipeline;

-- -------------------------------------------------------------
-- 6. CONFIRM THAT THE APPROVED CORRECTIONS WERE APPLIED
-- -------------------------------------------------------------

-- Each of these counts should return zero.
SELECT
    SUM(product = 'GTXPro') AS remaining_gtxpro_labels
FROM fact_sales_pipeline;

SELECT
    SUM(sector = 'technolgy') AS remaining_sector_typos,
    SUM(office_location = 'Philipines') AS remaining_location_typos
FROM dim_accounts;

-- The standardized GTX Pro label should now cover all 1,480
-- opportunities previously recorded as GTXPro.
SELECT
    product,
    COUNT(*) AS opportunity_count
FROM fact_sales_pipeline
WHERE product = 'GTX Pro'
GROUP BY product;

-- Expected result: GTX Pro = 1,480 opportunities.

-- -------------------------------------------------------------
-- 7. RECONCILE RAW AND CLEAN RECORD COUNTS
-- -------------------------------------------------------------

SELECT
    'accounts' AS dataset,
    (SELECT COUNT(*) FROM raw_accounts) AS raw_count,
    (SELECT COUNT(*) FROM dim_accounts) AS clean_count
UNION ALL
SELECT
    'products',
    (SELECT COUNT(*) FROM raw_products),
    (SELECT COUNT(*) FROM dim_products)
UNION ALL
SELECT
    'sales_agents',
    (SELECT COUNT(*) FROM raw_sales_teams),
    (SELECT COUNT(*) FROM dim_sales_agents)
UNION ALL
SELECT
    'sales_pipeline',
    (SELECT COUNT(*) FROM raw_sales_pipeline),
    (SELECT COUNT(*) FROM fact_sales_pipeline);

-- Expected clean counts:
-- dim_accounts:          85
-- dim_products:           7
-- dim_sales_agents:      35
-- fact_sales_pipeline: 8,800

-- -------------------------------------------------------------
-- 8. CONFIRM RELATIONSHIP INTEGRITY
-- -------------------------------------------------------------

-- All three counts should return zero. NULL accounts are valid
-- for open opportunities and are deliberately excluded here.
SELECT
    SUM(a.sales_agent IS NULL) AS unmatched_agents,
    SUM(pr.product IS NULL) AS unmatched_products,
    SUM(p.account IS NOT NULL AND ac.account IS NULL) AS unmatched_named_accounts
FROM fact_sales_pipeline AS p
LEFT JOIN dim_sales_agents AS a
    ON p.sales_agent = a.sales_agent
LEFT JOIN dim_products AS pr
    ON p.product = pr.product
LEFT JOIN dim_accounts AS ac
    ON p.account = ac.account;

-- -------------------------------------------------------------
-- 9. FINAL PIPELINE CHECK
-- -------------------------------------------------------------

SELECT
    deal_stage,
    COUNT(*) AS opportunity_count,
    SUM(account IS NULL) AS opportunities_without_account,
    SUM(engage_date IS NULL) AS opportunities_without_engagement,
    SUM(close_date IS NULL) AS opportunities_without_close_date,
    SUM(close_value IS NULL) AS opportunities_without_close_value
FROM fact_sales_pipeline
GROUP BY deal_stage
ORDER BY deal_stage;

-- Expected stage counts:
-- Engaging:    1,589
-- Lost:        2,473
-- Prospecting:   500
-- Won:         4,238

-- The clean analytical layer is now ready for business analysis.
