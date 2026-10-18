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
-- END OF PART 2
-- Next: product, pricing, account and customer-segment performance.
-- =============================================================
