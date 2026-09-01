# B2B Sales Pipeline Analytics

## Business Brief

### Business Context

MavenTech is a fictional computer-hardware company that sells several product lines to business customers through regional sales teams. Its CRM system contains information about sales opportunities, customer accounts, products, and sales representatives.

Sales leadership needs a consolidated view of this data to understand commercial performance, identify areas of concern, and determine where management attention could improve sales results.

### Stakeholders

**Primary stakeholder:** Vice President of Sales

**Supporting stakeholders:** Regional sales managers, sales operations, product leadership, and executive management.

### Business Problem

Sales leadership currently lacks a clear view of:

- Revenue and sales performance over time
- The health of active sales opportunities
- Performance differences across agents, managers, and regions
- The products and customer segments driving results
- Where opportunities are being lost or delayed

The project will address the central question:

> **What is happening across MavenTech's sales pipeline, what factors are influencing performance, and where should management focus to improve results?**

### Project Objective

Develop an interactive sales-intelligence solution using SQL and Power BI that enables leadership to:

- Monitor sales outcomes, revenue, and active opportunities
- Compare performance across teams, products, and customers
- Identify underperforming areas and potential pipeline risks
- Make evidence-based sales-management decisions

### Decisions to Support

The analysis should help management determine:

- Which agents or teams require coaching or additional support
- Which high-performing approaches could be replicated
- Which products and customer segments deserve greater attention
- Where active opportunities may be ageing or stalling
- Whether actual selling prices differ materially from suggested prices
- Where sales resources and management attention should be prioritized

### Core KPIs

| KPI | Definition |
|---|---|
| Won Revenue | Total value of won opportunities |
| Win Rate | Won deals divided by all closed deals |
| Open Opportunities | Opportunities in Prospecting or Engaging |
| Average Deal Value | Won revenue divided by won deals |
| Average Sales Cycle | Average days from engagement to closure |
| Pipeline Age | Days since engagement for open opportunities |
| Price Realization | Actual close value divided by suggested product price |
| Revenue Growth | Change in won revenue between reporting periods |

### Key Analytical Questions

1. How are revenue, win rate, and average deal value changing over time?
2. Which agents, managers, and regional offices perform above or below their peers?
3. Are differences in agent performance driven by opportunity volume, win rate, or deal size?
4. Which products generate the most revenue and achieve the strongest conversion?
5. Which products or teams have unusually long sales cycles?
6. Which customer sectors, locations, and company-size groups produce the strongest results?
7. Where are active opportunities ageing or potentially stalling?
8. How do actual selling prices compare with suggested product prices?
9. Where should sales leadership focus coaching, product attention, or pipeline support?

### Scope and Limitations

The analysis will cover sales opportunities, products, customer accounts, sales agents, managers, and regional offices. It will evaluate revenue, sales outcomes, pipeline activity, customer characteristics, selling prices, and sales-cycle duration.

Profit, sales quotas, marketing attribution, acquisition costs, and probability-weighted forecasting are outside the project's scope because the required data is unavailable.

Open pipeline will be measured through opportunity counts, stage, and age. A dollar-valued open pipeline will not be reported because the dataset does not provide estimated values for active opportunities.

### Deliverables

The completed project will include:

- A documented relational data model
- SQL scripts for data quality, transformation, and analysis
- Defined KPI and DAX measures
- An interactive Power BI report
- An executive summary of findings and recommendations
- A documented methodology and polished GitHub case study

The Power BI report is expected to contain three pages:

1. **Executive Overview**
2. **Sales Team and Pipeline Performance**
3. **Product and Account Insights**

### Success Measure

The project will be successful if sales leadership can use the final solution to quickly understand commercial performance, identify strong and weak areas, recognize pipeline risks, and determine where management action should be prioritized.

---

*Dataset note: This portfolio project uses a fictional CRM dataset published by Maven Analytics. The business scenario, KPI framework, analysis, and dashboard design are independently developed for this project.*
