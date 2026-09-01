-- =============================================================
-- Project: B2B Sales Pipeline Analytics
-- File: 01_database_setup.sql
-- Purpose: Create the project database and raw source tables
-- Database: MySQL 8+
-- =============================================================

CREATE DATABASE IF NOT EXISTS maventech_sales
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_0900_ai_ci;

USE maventech_sales;

-- The raw tables preserve source values as supplied.
-- Foreign keys are intentionally deferred until after data-quality review.

CREATE TABLE IF NOT EXISTS raw_accounts (
    account             VARCHAR(100) NOT NULL,
    sector              VARCHAR(50)  NOT NULL,
    year_established    SMALLINT UNSIGNED NOT NULL,
    revenue             DECIMAL(12,2) NOT NULL COMMENT 'Annual revenue in millions of USD',
    employees           INT UNSIGNED NOT NULL,
    office_location     VARCHAR(100) NOT NULL,
    subsidiary_of       VARCHAR(100) NULL,
    PRIMARY KEY (account)
);

CREATE TABLE IF NOT EXISTS raw_products (
    product             VARCHAR(50) NOT NULL,
    series              VARCHAR(20) NOT NULL,
    sales_price         DECIMAL(12,2) NOT NULL,
    PRIMARY KEY (product)
);

CREATE TABLE IF NOT EXISTS raw_sales_teams (
    sales_agent         VARCHAR(100) NOT NULL,
    manager             VARCHAR(100) NOT NULL,
    regional_office     VARCHAR(20) NOT NULL,
    PRIMARY KEY (sales_agent),
    INDEX idx_raw_sales_teams_manager (manager),
    INDEX idx_raw_sales_teams_region (regional_office)
);

CREATE TABLE IF NOT EXISTS raw_sales_pipeline (
    opportunity_id      CHAR(8) NOT NULL,
    sales_agent         VARCHAR(100) NOT NULL,
    product             VARCHAR(50) NOT NULL,
    account             VARCHAR(100) NULL,
    deal_stage          VARCHAR(20) NOT NULL,
    engage_date         DATE NULL,
    close_date          DATE NULL,
    close_value         DECIMAL(12,2) NULL,
    PRIMARY KEY (opportunity_id),
    INDEX idx_raw_pipeline_agent (sales_agent),
    INDEX idx_raw_pipeline_product (product),
    INDEX idx_raw_pipeline_account (account),
    INDEX idx_raw_pipeline_stage (deal_stage),
    INDEX idx_raw_pipeline_engage_date (engage_date),
    INDEX idx_raw_pipeline_close_date (close_date)
);

-- Confirm that the database and four raw tables were created.
SELECT DATABASE() AS active_database;

SHOW TABLES;
