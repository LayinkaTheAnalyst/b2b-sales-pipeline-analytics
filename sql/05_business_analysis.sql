-- =============================================================
-- Project: B2B Sales Pipeline Analytics
-- File: 05_business_analysis.sql
-- Purpose: Answer the project's main commercial questions using
--          the cleaned analytical tables
-- Database: MySQL 8+
-- =============================================================

USE maventech_sales;

-- This script is read-only. It does not change the clean or raw
-- tables. Each section answers a specific business question and
-- can be run separately in MySQL Workbench.

-- =============================================================
-- PART 1: EXECUTIVE KPIs AND SALES TRENDS
-- =============================================================

-- -------------------------------------------------------------
-- 1. OVERALL COMMERCIAL PERFORMANCE
-- -------------------------------------------------------------
-- Question: What does MavenTech's performance look like at the
-- highest level?
--
-- Win rate uses only completed opportunities in the denominator:
-- Won / (Won + Lost). Open opportunities are excluded because
-- they do not yet have a final outcome.

SELECT
    COUNT(*) AS total_opportunities,
    SUM(deal_stage IN ('Won', 'Lost')) AS completed_opportunities,
    SUM(deal_stage = 'Won') AS won_opportunities,
    SUM(deal_stage = 'Lost') AS lost_opportunities,
    SUM(deal_stage IN ('Prospecting', 'Engaging')) AS open_opportunities,
    ROUND(
        100.0 * SUM(deal_stage = 'Won')
        / NULLIF(SUM(deal_stage IN ('Won', 'Lost')), 0),
        1
    ) AS win_rate_pct,
    ROUND(SUM(CASE WHEN deal_stage = 'Won' THEN close_value ELSE 0 END), 2)
        AS won_revenue,
    ROUND(AVG(CASE WHEN deal_stage = 'Won' THEN close_value END), 2)
        AS average_won_deal_value,
    ROUND(AVG(CASE
        WHEN deal_stage IN ('Won', 'Lost') THEN sales_cycle_days
    END), 1) AS average_completed_sales_cycle_days
FROM fact_sales_pipeline;

-- -------------------------------------------------------------
-- 2. PIPELINE STAGE DISTRIBUTION
-- -------------------------------------------------------------
-- Question: How are the 8,800 opportunities distributed across
-- the sales process?
--
-- Open pipeline is reported as opportunity volume rather than a
-- dollar amount because active opportunities have no estimated
-- deal values in the source data.

SELECT
    deal_stage,
    COUNT(*) AS opportunity_count,
    ROUND(
        100.0 * COUNT(*) / SUM(COUNT(*)) OVER (),
        1
    ) AS share_of_all_opportunities_pct
FROM fact_sales_pipeline
GROUP BY deal_stage
ORDER BY FIELD(deal_stage, 'Prospecting', 'Engaging', 'Won', 'Lost');

-- -------------------------------------------------------------
-- 3. COMPLETED OUTCOMES
-- -------------------------------------------------------------
-- Question: Among opportunities with a final decision, what share
-- was won or lost?

SELECT
    deal_stage,
    COUNT(*) AS completed_opportunities,
    ROUND(
        100.0 * COUNT(*) / SUM(COUNT(*)) OVER (),
        1
    ) AS share_of_completed_opportunities_pct
FROM fact_sales_pipeline
WHERE deal_stage IN ('Won', 'Lost')
GROUP BY deal_stage
ORDER BY FIELD(deal_stage, 'Won', 'Lost');

-- -------------------------------------------------------------
-- 4. MONTHLY CLOSED-DEAL PERFORMANCE
-- -------------------------------------------------------------
-- Question: How did closed opportunity volume, revenue, win rate
-- and average deal value change from month to month?
--
-- The reporting month is based on close_date because revenue is
-- recognized here only when an opportunity is won.

WITH monthly_closed_performance AS (
    SELECT
        DATE_FORMAT(close_date, '%Y-%m-01') AS month_start,
        COUNT(*) AS closed_opportunities,
        SUM(deal_stage = 'Won') AS won_opportunities,
        SUM(deal_stage = 'Lost') AS lost_opportunities,
        SUM(CASE WHEN deal_stage = 'Won' THEN close_value ELSE 0 END)
            AS won_revenue,
        AVG(CASE WHEN deal_stage = 'Won' THEN close_value END)
            AS average_won_deal_value,
        AVG(sales_cycle_days) AS average_sales_cycle_days
    FROM fact_sales_pipeline
    WHERE deal_stage IN ('Won', 'Lost')
    GROUP BY DATE_FORMAT(close_date, '%Y-%m-01')
)
SELECT
    month_start,
    closed_opportunities,
    won_opportunities,
    lost_opportunities,
    ROUND(
        100.0 * won_opportunities
        / NULLIF(closed_opportunities, 0),
        1
    ) AS win_rate_pct,
    ROUND(won_revenue, 2) AS won_revenue,
    ROUND(average_won_deal_value, 2) AS average_won_deal_value,
    ROUND(average_sales_cycle_days, 1) AS average_sales_cycle_days
FROM monthly_closed_performance
ORDER BY month_start;

-- -------------------------------------------------------------
-- 5. MONTH-OVER-MONTH REVENUE CHANGE
-- -------------------------------------------------------------
-- Question: In which months did won revenue grow or decline?

WITH monthly_revenue AS (
    SELECT
        DATE_FORMAT(close_date, '%Y-%m-01') AS month_start,
        SUM(close_value) AS won_revenue
    FROM fact_sales_pipeline
    WHERE deal_stage = 'Won'
    GROUP BY DATE_FORMAT(close_date, '%Y-%m-01')
),
revenue_with_previous_month AS (
    SELECT
        month_start,
        won_revenue,
        LAG(won_revenue) OVER (ORDER BY month_start)
            AS previous_month_revenue
    FROM monthly_revenue
)
SELECT
    month_start,
    ROUND(won_revenue, 2) AS won_revenue,
    ROUND(previous_month_revenue, 2) AS previous_month_revenue,
    ROUND(won_revenue - previous_month_revenue, 2)
        AS revenue_change,
    ROUND(
        100.0 * (won_revenue - previous_month_revenue)
        / NULLIF(previous_month_revenue, 0),
        1
    ) AS revenue_growth_pct
FROM revenue_with_previous_month
ORDER BY month_start;

-- The first month will have no previous-month comparison, so its
-- revenue_change and revenue_growth_pct will correctly appear NULL.

-- -------------------------------------------------------------
-- 6. QUARTERLY PERFORMANCE
-- -------------------------------------------------------------
-- Question: Is the broader performance trend clearer when monthly
-- fluctuations are grouped into quarters?

SELECT
    YEAR(close_date) AS close_year,
    QUARTER(close_date) AS close_quarter,
    COUNT(*) AS closed_opportunities,
    SUM(deal_stage = 'Won') AS won_opportunities,
    SUM(deal_stage = 'Lost') AS lost_opportunities,
    ROUND(
        100.0 * SUM(deal_stage = 'Won') / NULLIF(COUNT(*), 0),
        1
    ) AS win_rate_pct,
    ROUND(
        SUM(CASE WHEN deal_stage = 'Won' THEN close_value ELSE 0 END),
        2
    ) AS won_revenue,
    ROUND(
        AVG(CASE WHEN deal_stage = 'Won' THEN close_value END),
        2
    ) AS average_won_deal_value,
    ROUND(AVG(sales_cycle_days), 1) AS average_sales_cycle_days
FROM fact_sales_pipeline
WHERE deal_stage IN ('Won', 'Lost')
GROUP BY YEAR(close_date), QUARTER(close_date)
ORDER BY close_year, close_quarter;

-- -------------------------------------------------------------
-- 7. WON VERSUS LOST SALES-CYCLE COMPARISON
-- -------------------------------------------------------------
-- Question: Do successful opportunities take longer to close than
-- unsuccessful ones?

SELECT
    deal_stage,
    COUNT(*) AS completed_opportunities,
    MIN(sales_cycle_days) AS shortest_cycle_days,
    ROUND(AVG(sales_cycle_days), 1) AS average_cycle_days,
    MAX(sales_cycle_days) AS longest_cycle_days
FROM fact_sales_pipeline
WHERE deal_stage IN ('Won', 'Lost')
GROUP BY deal_stage
ORDER BY FIELD(deal_stage, 'Won', 'Lost');

-- -------------------------------------------------------------
-- 8. MONTHLY SALES-CYCLE TREND
-- -------------------------------------------------------------
-- Question: Are completed opportunities taking more or less time
-- to close as the year progresses?

SELECT
    DATE_FORMAT(close_date, '%Y-%m-01') AS month_start,
    ROUND(AVG(sales_cycle_days), 1) AS average_cycle_days,
    ROUND(AVG(CASE
        WHEN deal_stage = 'Won' THEN sales_cycle_days
    END), 1) AS average_won_cycle_days,
    ROUND(AVG(CASE
        WHEN deal_stage = 'Lost' THEN sales_cycle_days
    END), 1) AS average_lost_cycle_days
FROM fact_sales_pipeline
WHERE deal_stage IN ('Won', 'Lost')
GROUP BY DATE_FORMAT(close_date, '%Y-%m-01')
ORDER BY month_start;

-- =============================================================
-- END OF PART 1
-- Next: team, regional-office and individual-agent performance.
-- =============================================================
