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
-- PART 2: SALES TEAM AND REGIONAL PERFORMANCE
-- =============================================================

-- -------------------------------------------------------------
-- 9. REGIONAL-OFFICE PERFORMANCE
-- -------------------------------------------------------------
-- Question: Which regional offices generate the most revenue, and
-- are the differences driven by volume, win rate or deal size?

SELECT
    a.regional_office,
    COUNT(p.opportunity_id) AS total_opportunities,
    SUM(p.deal_stage IN ('Won', 'Lost')) AS completed_opportunities,
    SUM(p.deal_stage = 'Won') AS won_opportunities,
    SUM(p.deal_stage = 'Lost') AS lost_opportunities,
    SUM(p.deal_stage IN ('Prospecting', 'Engaging')) AS open_opportunities,
    ROUND(
        100.0 * SUM(p.deal_stage = 'Won')
        / NULLIF(SUM(p.deal_stage IN ('Won', 'Lost')), 0),
        1
    ) AS win_rate_pct,
    ROUND(
        SUM(CASE WHEN p.deal_stage = 'Won' THEN p.close_value ELSE 0 END),
        2
    ) AS won_revenue,
    ROUND(
        AVG(CASE WHEN p.deal_stage = 'Won' THEN p.close_value END),
        2
    ) AS average_won_deal_value,
    ROUND(
        AVG(CASE
            WHEN p.deal_stage IN ('Won', 'Lost') THEN p.sales_cycle_days
        END),
        1
    ) AS average_completed_sales_cycle_days
FROM fact_sales_pipeline AS p
INNER JOIN dim_sales_agents AS a
    ON p.sales_agent = a.sales_agent
GROUP BY a.regional_office
ORDER BY won_revenue DESC;

-- -------------------------------------------------------------
-- 10. MANAGER PERFORMANCE
-- -------------------------------------------------------------
-- Question: How do the sales teams compare under each manager?
--
-- Agent count comes from the full roster, including agents with no
-- recorded opportunities, so team size is not understated.

WITH manager_roster AS (
    SELECT
        manager,
        regional_office,
        COUNT(*) AS rostered_agents
    FROM dim_sales_agents
    GROUP BY manager, regional_office
),
manager_results AS (
    SELECT
        a.manager,
        a.regional_office,
        COUNT(p.opportunity_id) AS total_opportunities,
        SUM(p.deal_stage IN ('Won', 'Lost')) AS completed_opportunities,
        SUM(p.deal_stage = 'Won') AS won_opportunities,
        SUM(p.deal_stage = 'Lost') AS lost_opportunities,
        SUM(p.deal_stage IN ('Prospecting', 'Engaging')) AS open_opportunities,
        SUM(CASE WHEN p.deal_stage = 'Won' THEN p.close_value ELSE 0 END)
            AS won_revenue,
        AVG(CASE WHEN p.deal_stage = 'Won' THEN p.close_value END)
            AS average_won_deal_value,
        AVG(CASE
            WHEN p.deal_stage IN ('Won', 'Lost') THEN p.sales_cycle_days
        END) AS average_completed_sales_cycle_days
    FROM dim_sales_agents AS a
    LEFT JOIN fact_sales_pipeline AS p
        ON a.sales_agent = p.sales_agent
    GROUP BY a.manager, a.regional_office
)
SELECT
    r.manager,
    r.regional_office,
    r.rostered_agents,
    m.total_opportunities,
    m.completed_opportunities,
    m.won_opportunities,
    m.lost_opportunities,
    m.open_opportunities,
    ROUND(
        100.0 * m.won_opportunities
        / NULLIF(m.completed_opportunities, 0),
        1
    ) AS win_rate_pct,
    ROUND(m.won_revenue, 2) AS won_revenue,
    ROUND(m.won_revenue / NULLIF(r.rostered_agents, 0), 2)
        AS revenue_per_rostered_agent,
    ROUND(m.average_won_deal_value, 2) AS average_won_deal_value,
    ROUND(m.average_completed_sales_cycle_days, 1)
        AS average_completed_sales_cycle_days
FROM manager_roster AS r
INNER JOIN manager_results AS m
    ON r.manager = m.manager
   AND r.regional_office = m.regional_office
ORDER BY won_revenue DESC;

-- -------------------------------------------------------------
-- 11. INDIVIDUAL AGENT SCORECARD
-- -------------------------------------------------------------
-- Question: How is each agent performing across activity, outcomes
-- and revenue?
--
-- Starting from the agent dimension keeps the five rostered agents
-- with no opportunities visible instead of silently dropping them.

SELECT
    a.sales_agent,
    a.manager,
    a.regional_office,
    COUNT(p.opportunity_id) AS total_opportunities,
    SUM(COALESCE(p.deal_stage IN ('Won', 'Lost'), 0))
        AS completed_opportunities,
    SUM(COALESCE(p.deal_stage = 'Won', 0)) AS won_opportunities,
    SUM(COALESCE(p.deal_stage = 'Lost', 0)) AS lost_opportunities,
    SUM(COALESCE(p.deal_stage IN ('Prospecting', 'Engaging'), 0))
        AS open_opportunities,
    ROUND(
        100.0 * SUM(COALESCE(p.deal_stage = 'Won', 0))
        / NULLIF(SUM(COALESCE(p.deal_stage IN ('Won', 'Lost'), 0)), 0),
        1
    ) AS win_rate_pct,
    ROUND(
        SUM(CASE WHEN p.deal_stage = 'Won' THEN p.close_value ELSE 0 END),
        2
    ) AS won_revenue,
    ROUND(
        AVG(CASE WHEN p.deal_stage = 'Won' THEN p.close_value END),
        2
    ) AS average_won_deal_value,
    ROUND(
        AVG(CASE
            WHEN p.deal_stage IN ('Won', 'Lost') THEN p.sales_cycle_days
        END),
        1
    ) AS average_completed_sales_cycle_days,
    CASE
        WHEN COUNT(p.opportunity_id) = 0 THEN 'No recorded activity'
        ELSE 'Active'
    END AS activity_status
FROM dim_sales_agents AS a
LEFT JOIN fact_sales_pipeline AS p
    ON a.sales_agent = p.sales_agent
GROUP BY
    a.sales_agent,
    a.manager,
    a.regional_office
ORDER BY won_revenue DESC, a.sales_agent;

-- -------------------------------------------------------------
-- 12. AGENT PERFORMANCE RANKING
-- -------------------------------------------------------------
-- Question: Who leads on revenue, win rate and deal size?
--
-- Win-rate rank is shown only for agents with at least 30 completed
-- opportunities. This avoids presenting a tiny sample as if it
-- were directly comparable with a full workload.

WITH agent_performance AS (
    SELECT
        a.sales_agent,
        a.manager,
        a.regional_office,
        COUNT(p.opportunity_id) AS total_opportunities,
        SUM(COALESCE(p.deal_stage IN ('Won', 'Lost'), 0))
            AS completed_opportunities,
        SUM(COALESCE(p.deal_stage = 'Won', 0)) AS won_opportunities,
        SUM(CASE WHEN p.deal_stage = 'Won' THEN p.close_value ELSE 0 END)
            AS won_revenue,
        AVG(CASE WHEN p.deal_stage = 'Won' THEN p.close_value END)
            AS average_won_deal_value
    FROM dim_sales_agents AS a
    LEFT JOIN fact_sales_pipeline AS p
        ON a.sales_agent = p.sales_agent
    GROUP BY
        a.sales_agent,
        a.manager,
        a.regional_office
),
agent_metrics AS (
    SELECT
        *,
        100.0 * won_opportunities / NULLIF(completed_opportunities, 0)
            AS win_rate_pct
    FROM agent_performance
)
SELECT
    sales_agent,
    manager,
    regional_office,
    total_opportunities,
    completed_opportunities,
    won_opportunities,
    ROUND(win_rate_pct, 1) AS win_rate_pct,
    ROUND(won_revenue, 2) AS won_revenue,
    ROUND(average_won_deal_value, 2) AS average_won_deal_value,
    DENSE_RANK() OVER (ORDER BY won_revenue DESC) AS revenue_rank,
    CASE
        WHEN completed_opportunities >= 30
            THEN DENSE_RANK() OVER (
                ORDER BY
                    CASE
                        WHEN completed_opportunities >= 30 THEN win_rate_pct
                    END DESC
            )
        ELSE NULL
    END AS qualified_win_rate_rank
FROM agent_metrics
ORDER BY revenue_rank, sales_agent;

-- -------------------------------------------------------------
-- 13. WHAT DRIVES EACH AGENT'S REVENUE?
-- -------------------------------------------------------------
-- Question: Is an agent's revenue mainly explained by handling more
-- opportunities, winning more often or closing larger deals?
--
-- Won revenue can be understood as:
-- completed volume x win rate x average won deal value.

WITH agent_drivers AS (
    SELECT
        a.sales_agent,
        a.manager,
        a.regional_office,
        COUNT(p.opportunity_id) AS total_opportunities,
        SUM(COALESCE(p.deal_stage IN ('Won', 'Lost'), 0))
            AS completed_opportunities,
        SUM(COALESCE(p.deal_stage = 'Won', 0)) AS won_opportunities,
        SUM(CASE WHEN p.deal_stage = 'Won' THEN p.close_value ELSE 0 END)
            AS won_revenue,
        AVG(CASE WHEN p.deal_stage = 'Won' THEN p.close_value END)
            AS average_won_deal_value
    FROM dim_sales_agents AS a
    LEFT JOIN fact_sales_pipeline AS p
        ON a.sales_agent = p.sales_agent
    GROUP BY
        a.sales_agent,
        a.manager,
        a.regional_office
)
SELECT
    sales_agent,
    manager,
    regional_office,
    total_opportunities,
    completed_opportunities,
    ROUND(
        100.0 * won_opportunities
        / NULLIF(completed_opportunities, 0),
        1
    ) AS win_rate_pct,
    ROUND(average_won_deal_value, 2) AS average_won_deal_value,
    ROUND(won_revenue, 2) AS won_revenue,
    ROUND(
        100.0 * won_revenue / NULLIF(SUM(won_revenue) OVER (), 0),
        1
    ) AS share_of_company_revenue_pct
FROM agent_drivers
ORDER BY won_revenue DESC, sales_agent;

-- -------------------------------------------------------------
-- 14. REGIONAL MONTHLY TREND
-- -------------------------------------------------------------
-- Question: Did the offices perform consistently through the year,
-- or did their results rise and fall at different times?

SELECT
    DATE_FORMAT(p.close_date, '%Y-%m-01') AS month_start,
    a.regional_office,
    COUNT(*) AS closed_opportunities,
    SUM(p.deal_stage = 'Won') AS won_opportunities,
    ROUND(
        100.0 * SUM(p.deal_stage = 'Won') / NULLIF(COUNT(*), 0),
        1
    ) AS win_rate_pct,
    ROUND(
        SUM(CASE WHEN p.deal_stage = 'Won' THEN p.close_value ELSE 0 END),
        2
    ) AS won_revenue
FROM fact_sales_pipeline AS p
INNER JOIN dim_sales_agents AS a
    ON p.sales_agent = a.sales_agent
WHERE p.deal_stage IN ('Won', 'Lost')
GROUP BY
    DATE_FORMAT(p.close_date, '%Y-%m-01'),
    a.regional_office
ORDER BY month_start, a.regional_office;

-- =============================================================
-- PART 3: PRODUCT, PRICING AND CUSTOMER PERFORMANCE
-- =============================================================

-- -------------------------------------------------------------
-- 15. PRODUCT PERFORMANCE
-- -------------------------------------------------------------
-- Question: Which products generate the most revenue, convert most
-- successfully and carry the largest active pipelines?

SELECT
    pr.product,
    pr.series,
    pr.suggested_price,
    COUNT(p.opportunity_id) AS total_opportunities,
    SUM(p.deal_stage IN ('Won', 'Lost')) AS completed_opportunities,
    SUM(p.deal_stage = 'Won') AS won_opportunities,
    SUM(p.deal_stage = 'Lost') AS lost_opportunities,
    SUM(p.deal_stage IN ('Prospecting', 'Engaging')) AS open_opportunities,
    ROUND(
        100.0 * SUM(p.deal_stage = 'Won')
        / NULLIF(SUM(p.deal_stage IN ('Won', 'Lost')), 0),
        1
    ) AS win_rate_pct,
    ROUND(
        SUM(CASE WHEN p.deal_stage = 'Won' THEN p.close_value ELSE 0 END),
        2
    ) AS won_revenue,
    ROUND(
        AVG(CASE WHEN p.deal_stage = 'Won' THEN p.close_value END),
        2
    ) AS average_won_deal_value,
    ROUND(
        AVG(CASE
            WHEN p.deal_stage IN ('Won', 'Lost') THEN p.sales_cycle_days
        END),
        1
    ) AS average_completed_sales_cycle_days
FROM dim_products AS pr
LEFT JOIN fact_sales_pipeline AS p
    ON pr.product = p.product
GROUP BY
    pr.product,
    pr.series,
    pr.suggested_price
ORDER BY won_revenue DESC;

-- -------------------------------------------------------------
-- 16. PRODUCT-SERIES PERFORMANCE
-- -------------------------------------------------------------
-- Question: At the broader portfolio level, which product series
-- contributes the most revenue and converts most effectively?

SELECT
    pr.series,
    COUNT(p.opportunity_id) AS total_opportunities,
    SUM(p.deal_stage IN ('Won', 'Lost')) AS completed_opportunities,
    SUM(p.deal_stage = 'Won') AS won_opportunities,
    SUM(p.deal_stage IN ('Prospecting', 'Engaging')) AS open_opportunities,
    ROUND(
        100.0 * SUM(p.deal_stage = 'Won')
        / NULLIF(SUM(p.deal_stage IN ('Won', 'Lost')), 0),
        1
    ) AS win_rate_pct,
    ROUND(
        SUM(CASE WHEN p.deal_stage = 'Won' THEN p.close_value ELSE 0 END),
        2
    ) AS won_revenue,
    ROUND(
        AVG(CASE WHEN p.deal_stage = 'Won' THEN p.close_value END),
        2
    ) AS average_won_deal_value
FROM dim_products AS pr
LEFT JOIN fact_sales_pipeline AS p
    ON pr.product = p.product
GROUP BY pr.series
ORDER BY won_revenue DESC;

-- -------------------------------------------------------------
-- 17. PRICE REALIZATION BY PRODUCT
-- -------------------------------------------------------------
-- Question: How closely do actual selling prices match suggested
-- catalogue prices?
--
-- Price realization above 100% indicates an average premium, while
-- a result below 100% indicates an average discount.

SELECT
    pr.product,
    pr.series,
    pr.suggested_price,
    COUNT(*) AS won_deals,
    ROUND(AVG(p.close_value), 2) AS average_selling_price,
    ROUND(MIN(p.close_value), 2) AS minimum_selling_price,
    ROUND(MAX(p.close_value), 2) AS maximum_selling_price,
    ROUND(
        100.0 * AVG(p.close_value) / NULLIF(pr.suggested_price, 0),
        1
    ) AS average_price_realization_pct,
    ROUND(AVG(p.close_value) - pr.suggested_price, 2)
        AS average_price_variance
FROM fact_sales_pipeline AS p
INNER JOIN dim_products AS pr
    ON p.product = pr.product
WHERE p.deal_stage = 'Won'
GROUP BY
    pr.product,
    pr.series,
    pr.suggested_price
ORDER BY average_price_realization_pct DESC;

-- -------------------------------------------------------------
-- 18. MONTHLY PRODUCT REVENUE
-- -------------------------------------------------------------
-- Question: Which products drove revenue in each month, and did the
-- product mix change through the year?

SELECT
    DATE_FORMAT(p.close_date, '%Y-%m-01') AS month_start,
    p.product,
    COUNT(*) AS won_deals,
    ROUND(SUM(p.close_value), 2) AS won_revenue,
    ROUND(AVG(p.close_value), 2) AS average_won_deal_value
FROM fact_sales_pipeline AS p
WHERE p.deal_stage = 'Won'
GROUP BY
    DATE_FORMAT(p.close_date, '%Y-%m-01'),
    p.product
ORDER BY month_start, won_revenue DESC;

-- -------------------------------------------------------------
-- 19. ACCOUNT PERFORMANCE
-- -------------------------------------------------------------
-- Question: Which customer accounts generate the most revenue and
-- how consistently do their opportunities convert?

SELECT
    a.account,
    a.sector,
    a.office_location,
    a.revenue_millions AS account_revenue_millions,
    a.employees,
    COUNT(p.opportunity_id) AS total_opportunities,
    SUM(p.deal_stage = 'Won') AS won_opportunities,
    SUM(p.deal_stage = 'Lost') AS lost_opportunities,
    ROUND(
        100.0 * SUM(p.deal_stage = 'Won')
        / NULLIF(SUM(p.deal_stage IN ('Won', 'Lost')), 0),
        1
    ) AS win_rate_pct,
    ROUND(
        SUM(CASE WHEN p.deal_stage = 'Won' THEN p.close_value ELSE 0 END),
        2
    ) AS won_revenue,
    ROUND(
        AVG(CASE WHEN p.deal_stage = 'Won' THEN p.close_value END),
        2
    ) AS average_won_deal_value,
    ROUND(
        AVG(CASE
            WHEN p.deal_stage IN ('Won', 'Lost') THEN p.sales_cycle_days
        END),
        1
    ) AS average_completed_sales_cycle_days
FROM dim_accounts AS a
LEFT JOIN fact_sales_pipeline AS p
    ON a.account = p.account
GROUP BY
    a.account,
    a.sector,
    a.office_location,
    a.revenue_millions,
    a.employees
ORDER BY won_revenue DESC, a.account;

-- -------------------------------------------------------------
-- 20. SECTOR PERFORMANCE
-- -------------------------------------------------------------
-- Question: Which customer sectors produce the strongest commercial
-- results?

SELECT
    a.sector,
    COUNT(DISTINCT a.account) AS accounts,
    COUNT(p.opportunity_id) AS total_opportunities,
    SUM(p.deal_stage IN ('Won', 'Lost')) AS completed_opportunities,
    SUM(p.deal_stage = 'Won') AS won_opportunities,
    ROUND(
        100.0 * SUM(p.deal_stage = 'Won')
        / NULLIF(SUM(p.deal_stage IN ('Won', 'Lost')), 0),
        1
    ) AS win_rate_pct,
    ROUND(
        SUM(CASE WHEN p.deal_stage = 'Won' THEN p.close_value ELSE 0 END),
        2
    ) AS won_revenue,
    ROUND(
        AVG(CASE WHEN p.deal_stage = 'Won' THEN p.close_value END),
        2
    ) AS average_won_deal_value,
    ROUND(
        AVG(CASE
            WHEN p.deal_stage IN ('Won', 'Lost') THEN p.sales_cycle_days
        END),
        1
    ) AS average_completed_sales_cycle_days
FROM dim_accounts AS a
LEFT JOIN fact_sales_pipeline AS p
    ON a.account = p.account
GROUP BY a.sector
ORDER BY won_revenue DESC;

-- -------------------------------------------------------------
-- 21. CUSTOMER LOCATION PERFORMANCE
-- -------------------------------------------------------------
-- Question: Where are MavenTech's strongest customer markets?
--
-- Results should be read alongside account counts because most
-- accounts are located in the United States and several countries
-- are represented by only one account.

SELECT
    a.office_location,
    COUNT(DISTINCT a.account) AS accounts,
    COUNT(p.opportunity_id) AS total_opportunities,
    SUM(p.deal_stage = 'Won') AS won_opportunities,
    ROUND(
        100.0 * SUM(p.deal_stage = 'Won')
        / NULLIF(SUM(p.deal_stage IN ('Won', 'Lost')), 0),
        1
    ) AS win_rate_pct,
    ROUND(
        SUM(CASE WHEN p.deal_stage = 'Won' THEN p.close_value ELSE 0 END),
        2
    ) AS won_revenue,
    ROUND(
        AVG(CASE WHEN p.deal_stage = 'Won' THEN p.close_value END),
        2
    ) AS average_won_deal_value
FROM dim_accounts AS a
LEFT JOIN fact_sales_pipeline AS p
    ON a.account = p.account
GROUP BY a.office_location
ORDER BY won_revenue DESC;

-- -------------------------------------------------------------
-- 22. COMPANY-SIZE PERFORMANCE
-- -------------------------------------------------------------
-- Question: Do small, medium and large customer organizations show
-- different revenue or conversion patterns?
--
-- The employee bands are analytical groupings created for this
-- project rather than categories supplied in the source data.

WITH accounts_with_size AS (
    SELECT
        account,
        CASE
            WHEN employees < 100 THEN 'Small: fewer than 100'
            WHEN employees < 1000 THEN 'Medium: 100-999'
            WHEN employees < 10000 THEN 'Large: 1,000-9,999'
            ELSE 'Enterprise: 10,000+'
        END AS company_size,
        CASE
            WHEN employees < 100 THEN 1
            WHEN employees < 1000 THEN 2
            WHEN employees < 10000 THEN 3
            ELSE 4
        END AS size_order
    FROM dim_accounts
)
SELECT
    a.company_size,
    COUNT(DISTINCT a.account) AS accounts,
    COUNT(p.opportunity_id) AS total_opportunities,
    SUM(p.deal_stage = 'Won') AS won_opportunities,
    ROUND(
        100.0 * SUM(p.deal_stage = 'Won')
        / NULLIF(SUM(p.deal_stage IN ('Won', 'Lost')), 0),
        1
    ) AS win_rate_pct,
    ROUND(
        SUM(CASE WHEN p.deal_stage = 'Won' THEN p.close_value ELSE 0 END),
        2
    ) AS won_revenue,
    ROUND(
        AVG(CASE WHEN p.deal_stage = 'Won' THEN p.close_value END),
        2
    ) AS average_won_deal_value,
    ROUND(
        AVG(CASE
            WHEN p.deal_stage IN ('Won', 'Lost') THEN p.sales_cycle_days
        END),
        1
    ) AS average_completed_sales_cycle_days
FROM accounts_with_size AS a
LEFT JOIN fact_sales_pipeline AS p
    ON a.account = p.account
GROUP BY a.company_size, a.size_order
ORDER BY a.size_order;

-- -------------------------------------------------------------
-- 23. ACCOUNT CONCENTRATION
-- -------------------------------------------------------------
-- Question: How dependent is total revenue on MavenTech's largest
-- customer accounts?

WITH account_revenue AS (
    SELECT
        a.account,
        a.sector,
        SUM(CASE WHEN p.deal_stage = 'Won' THEN p.close_value ELSE 0 END)
            AS won_revenue
    FROM dim_accounts AS a
    LEFT JOIN fact_sales_pipeline AS p
        ON a.account = p.account
    GROUP BY a.account, a.sector
),
ranked_accounts AS (
    SELECT
        account,
        sector,
        won_revenue,
        ROW_NUMBER() OVER (ORDER BY won_revenue DESC) AS revenue_rank,
        SUM(won_revenue) OVER () AS company_revenue
    FROM account_revenue
)
SELECT
    account,
    sector,
    revenue_rank,
    ROUND(won_revenue, 2) AS won_revenue,
    ROUND(100.0 * won_revenue / NULLIF(company_revenue, 0), 1)
        AS share_of_company_revenue_pct,
    ROUND(
        100.0 * SUM(won_revenue) OVER (ORDER BY revenue_rank)
        / NULLIF(company_revenue, 0),
        1
    ) AS cumulative_revenue_share_pct
FROM ranked_accounts
ORDER BY revenue_rank;

-- =============================================================
-- PART 4: OPEN PIPELINE HEALTH AND MANAGEMENT ATTENTION
-- =============================================================

-- -------------------------------------------------------------
-- 24. CONFIRM THE PIPELINE SNAPSHOT DATE
-- -------------------------------------------------------------
-- The source does not provide an explicit extract date. December
-- 31, 2017 is used as the reporting snapshot because it is the
-- latest recorded close date in the dataset.
--
-- Using CURRENT_DATE would be misleading: it would add years that
-- occurred after the dataset ended to every open opportunity.

SELECT
    MAX(close_date) AS reporting_snapshot_date,
    MIN(engage_date) AS first_recorded_engagement,
    MAX(engage_date) AS latest_recorded_engagement
FROM fact_sales_pipeline;

-- -------------------------------------------------------------
-- 25. OPEN PIPELINE OVERVIEW
-- -------------------------------------------------------------
-- Question: How much open work sits at each stage, and how much of
-- it has not yet been linked to a named customer account?

SELECT
    deal_stage,
    COUNT(*) AS open_opportunities,
    SUM(account IS NULL) AS opportunities_without_account,
    ROUND(
        100.0 * SUM(account IS NULL) / NULLIF(COUNT(*), 0),
        1
    ) AS missing_account_pct,
    COUNT(DISTINCT sales_agent) AS agents_with_open_opportunities,
    COUNT(DISTINCT product) AS products_in_open_pipeline
FROM fact_sales_pipeline
WHERE deal_stage IN ('Prospecting', 'Engaging')
GROUP BY deal_stage
ORDER BY FIELD(deal_stage, 'Prospecting', 'Engaging');

-- -------------------------------------------------------------
-- 26. AGEING OF ENGAGING OPPORTUNITIES
-- -------------------------------------------------------------
-- Question: How long have currently engaging opportunities remained
-- open since customer engagement began?
--
-- Prospecting opportunities are excluded because they have no
-- creation or engagement date and therefore cannot be aged fairly.

WITH engaging_age AS (
    SELECT
        opportunity_id,
        DATEDIFF('2017-12-31', engage_date) AS pipeline_age_days
    FROM fact_sales_pipeline
    WHERE deal_stage = 'Engaging'
)
SELECT
    CASE
        WHEN pipeline_age_days <= 30 THEN '0-30 days'
        WHEN pipeline_age_days <= 60 THEN '31-60 days'
        WHEN pipeline_age_days <= 90 THEN '61-90 days'
        WHEN pipeline_age_days <= 138 THEN '91-138 days'
        ELSE '139+ days'
    END AS age_band,
    COUNT(*) AS engaging_opportunities,
    ROUND(
        100.0 * COUNT(*) / SUM(COUNT(*)) OVER (),
        1
    ) AS share_of_engaging_pipeline_pct,
    CASE
        WHEN MAX(pipeline_age_days) > 138
             AND MIN(pipeline_age_days) > 138
            THEN 'Beyond longest completed cycle'
        ELSE 'Within completed-cycle range'
    END AS interpretation
FROM engaging_age
GROUP BY
    CASE
        WHEN pipeline_age_days <= 30 THEN '0-30 days'
        WHEN pipeline_age_days <= 60 THEN '31-60 days'
        WHEN pipeline_age_days <= 90 THEN '61-90 days'
        WHEN pipeline_age_days <= 138 THEN '91-138 days'
        ELSE '139+ days'
    END
ORDER BY MIN(pipeline_age_days);

-- The 138-day boundary is evidence-based: 138 days is the longest
-- sales cycle observed among completed opportunities in this data.

-- -------------------------------------------------------------
-- 27. POTENTIALLY STALLED OPPORTUNITIES
-- -------------------------------------------------------------
-- Question: Which engaging opportunities have remained open longer
-- than any opportunity in the completed-deal history?
--
-- These records deserve review, but the label "potentially stalled"
-- is not the same as declaring that the opportunity is invalid.

SELECT
    p.opportunity_id,
    p.sales_agent,
    a.manager,
    a.regional_office,
    p.product,
    p.account,
    p.engage_date,
    DATEDIFF('2017-12-31', p.engage_date) AS pipeline_age_days
FROM fact_sales_pipeline AS p
INNER JOIN dim_sales_agents AS a
    ON p.sales_agent = a.sales_agent
WHERE p.deal_stage = 'Engaging'
  AND DATEDIFF('2017-12-31', p.engage_date) > 138
ORDER BY pipeline_age_days DESC, p.opportunity_id;

-- -------------------------------------------------------------
-- 28. STALLED-PIPELINE CONCENTRATION BY TEAM
-- -------------------------------------------------------------
-- Question: Which managers and offices carry the largest number and
-- share of potentially stalled opportunities?

SELECT
    a.manager,
    a.regional_office,
    SUM(p.deal_stage = 'Engaging') AS engaging_opportunities,
    SUM(
        p.deal_stage = 'Engaging'
        AND DATEDIFF('2017-12-31', p.engage_date) > 138
    ) AS potentially_stalled_opportunities,
    ROUND(
        100.0 * SUM(
            p.deal_stage = 'Engaging'
            AND DATEDIFF('2017-12-31', p.engage_date) > 138
        ) / NULLIF(SUM(p.deal_stage = 'Engaging'), 0),
        1
    ) AS potentially_stalled_share_pct,
    ROUND(
        AVG(CASE
            WHEN p.deal_stage = 'Engaging'
                THEN DATEDIFF('2017-12-31', p.engage_date)
        END),
        1
    ) AS average_engaging_age_days
FROM dim_sales_agents AS a
LEFT JOIN fact_sales_pipeline AS p
    ON a.sales_agent = p.sales_agent
GROUP BY a.manager, a.regional_office
ORDER BY potentially_stalled_opportunities DESC, a.manager;

-- -------------------------------------------------------------
-- 29. STALLED-PIPELINE CONCENTRATION BY AGENT
-- -------------------------------------------------------------
-- Question: Which agents may need the most immediate pipeline review
-- or coaching support?

SELECT
    a.sales_agent,
    a.manager,
    a.regional_office,
    SUM(p.deal_stage = 'Engaging') AS engaging_opportunities,
    SUM(
        p.deal_stage = 'Engaging'
        AND DATEDIFF('2017-12-31', p.engage_date) > 138
    ) AS potentially_stalled_opportunities,
    ROUND(
        100.0 * SUM(
            p.deal_stage = 'Engaging'
            AND DATEDIFF('2017-12-31', p.engage_date) > 138
        ) / NULLIF(SUM(p.deal_stage = 'Engaging'), 0),
        1
    ) AS potentially_stalled_share_pct,
    ROUND(
        AVG(CASE
            WHEN p.deal_stage = 'Engaging'
                THEN DATEDIFF('2017-12-31', p.engage_date)
        END),
        1
    ) AS average_engaging_age_days
FROM dim_sales_agents AS a
LEFT JOIN fact_sales_pipeline AS p
    ON a.sales_agent = p.sales_agent
GROUP BY
    a.sales_agent,
    a.manager,
    a.regional_office
HAVING engaging_opportunities > 0
ORDER BY
    potentially_stalled_opportunities DESC,
    potentially_stalled_share_pct DESC,
    a.sales_agent;

-- -------------------------------------------------------------
-- 30. OPEN PIPELINE BY PRODUCT
-- -------------------------------------------------------------
-- Question: Which products account for the greatest share of future
-- sales activity and the oldest engaging opportunities?

SELECT
    pr.product,
    pr.series,
    SUM(p.deal_stage = 'Prospecting') AS prospecting_opportunities,
    SUM(p.deal_stage = 'Engaging') AS engaging_opportunities,
    SUM(p.deal_stage IN ('Prospecting', 'Engaging'))
        AS total_open_opportunities,
    ROUND(
        AVG(CASE
            WHEN p.deal_stage = 'Engaging'
                THEN DATEDIFF('2017-12-31', p.engage_date)
        END),
        1
    ) AS average_engaging_age_days,
    SUM(
        p.deal_stage = 'Engaging'
        AND DATEDIFF('2017-12-31', p.engage_date) > 138
    ) AS potentially_stalled_opportunities
FROM dim_products AS pr
LEFT JOIN fact_sales_pipeline AS p
    ON pr.product = p.product
GROUP BY pr.product, pr.series
ORDER BY total_open_opportunities DESC, pr.product;

-- -------------------------------------------------------------
-- 31. OPEN PIPELINE BY REGIONAL OFFICE
-- -------------------------------------------------------------
-- Question: How is current pipeline workload distributed across the
-- three regional offices?

SELECT
    a.regional_office,
    SUM(p.deal_stage = 'Prospecting') AS prospecting_opportunities,
    SUM(p.deal_stage = 'Engaging') AS engaging_opportunities,
    SUM(p.deal_stage IN ('Prospecting', 'Engaging'))
        AS total_open_opportunities,
    ROUND(
        100.0 * SUM(p.deal_stage IN ('Prospecting', 'Engaging'))
        / NULLIF(
            SUM(SUM(p.deal_stage IN ('Prospecting', 'Engaging'))) OVER (),
            0
        ),
        1
    ) AS share_of_open_pipeline_pct,
    SUM(
        p.deal_stage IN ('Prospecting', 'Engaging')
        AND p.account IS NULL
    ) AS open_opportunities_without_account,
    ROUND(
        AVG(CASE
            WHEN p.deal_stage = 'Engaging'
                THEN DATEDIFF('2017-12-31', p.engage_date)
        END),
        1
    ) AS average_engaging_age_days
FROM dim_sales_agents AS a
LEFT JOIN fact_sales_pipeline AS p
    ON a.sales_agent = p.sales_agent
GROUP BY a.regional_office
ORDER BY total_open_opportunities DESC;

-- -------------------------------------------------------------
-- 32. MANAGEMENT ATTENTION SUMMARY
-- -------------------------------------------------------------
-- Question: Which managers combine weaker closed-deal performance
-- with a large or ageing open pipeline?
--
-- This is a diagnostic view rather than a performance verdict. It
-- brings outcome and pipeline-health measures together so leaders
-- can decide where a closer review may be useful.

SELECT
    a.manager,
    a.regional_office,
    SUM(p.deal_stage IN ('Won', 'Lost')) AS completed_opportunities,
    ROUND(
        100.0 * SUM(p.deal_stage = 'Won')
        / NULLIF(SUM(p.deal_stage IN ('Won', 'Lost')), 0),
        1
    ) AS win_rate_pct,
    ROUND(
        SUM(CASE WHEN p.deal_stage = 'Won' THEN p.close_value ELSE 0 END),
        2
    ) AS won_revenue,
    SUM(p.deal_stage IN ('Prospecting', 'Engaging'))
        AS open_opportunities,
    SUM(
        p.deal_stage = 'Engaging'
        AND DATEDIFF('2017-12-31', p.engage_date) > 138
    ) AS potentially_stalled_opportunities,
    SUM(
        p.deal_stage IN ('Prospecting', 'Engaging')
        AND p.account IS NULL
    ) AS open_opportunities_without_account
FROM dim_sales_agents AS a
LEFT JOIN fact_sales_pipeline AS p
    ON a.sales_agent = p.sales_agent
GROUP BY a.manager, a.regional_office
ORDER BY
    potentially_stalled_opportunities DESC,
    win_rate_pct ASC;

-- =============================================================
-- END OF BUSINESS ANALYSIS
-- Findings from these queries will be summarized in the executive
-- insights report and used to design the Power BI dashboard.
-- =============================================================
