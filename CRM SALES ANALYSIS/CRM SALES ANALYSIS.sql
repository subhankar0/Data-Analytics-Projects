CREATE DATABASE crm_sales
USE crm_sales;

-- Create sales pipeline table

CREATE TABLE sales_pipeline (
	opportunity_id VARCHAR(20) PRIMARY KEY,
	sales_agent VARCHAR(100),
	product VARCHAR(100),
	account VARCHAR(100),
	deal_stage VARCHAR(50),
	engage_date DATE,
	close_date DATE,
	close_value DECIMAL(12, 2)
);

-- Create accounts table

CREATE TABLE accounts (
	account VARCHAR(100) PRIMARY KEY,
	secotr VARCHAR(100),
	year_established INT,
	revenue DECIMAL(18, 2),
	employee INT,
	office_location VARCHAR(100),
	subsidiary_of VARCHAR(100)
);

-- Create products table
CREATE TABLE products (
	product VARCHAR(100) PRIMARY KEY,
	series VARCHAR(50),
	sales_price DECIMAL(12, 2)
);

-- Create sales team table

CREATE TABLE sales_teams (
    sales_agent     VARCHAR(100) PRIMARY KEY,
    manager         VARCHAR(100),
    regional_office VARCHAR(100)
);

-- Load data into each table
-- sales pipeline

BULK INSERT sales_pipeline
FROM 'C:\Users\dassu\Desktop\DATA SETS\New folder\CRM Sales Opportunities\sales_pipeline.csv'
WITH (
	FORMAT = 'csv',
	FIRSTROW = 2,
	FIELDTERMINATOR = ',',
	ROWTERMINATOR = '\n',
	TABLOCK
);

-- accounts
BULK INSERT accounts
FROM 'C:\Users\dassu\Desktop\DATA SETS\New folder\CRM Sales Opportunities\accounts.csv'
WITH (
	FORMAT = 'csv',
	FIRSTROW = 2,
	FIELDTERMINATOR = ',',
	ROWTERMINATOR = '\n',
	TABLOCK
);

-- products
BULK INSERT products
FROM 'C:\Users\dassu\Desktop\DATA SETS\New folder\CRM Sales Opportunities\products.csv'
WITH (
	FORMAT = 'csv',
	FIRSTROW = 2,
	FIELDTERMINATOR = ',',
	ROWTERMINATOR = '\n',
	TABLOCK
);

-- sales teams
BULK INSERT sales_teams
FROM 'C:\Users\dassu\Desktop\DATA SETS\New folder\CRM Sales Opportunities\sales_teams.csv'
WITH (
	FORMAT = 'csv',
	FIRSTROW = 2,
	FIELDTERMINATOR = ',',
	ROWTERMINATOR = '\n',
	TABLOCK
);

-- 1. Findings KEY MATRICS
-- Overall KPIs

SELECT
    COUNT(*) AS total_opportunities,
    SUM(CASE WHEN deal_stage = 'Won' THEN 1 ELSE 0 END) AS won_deals,
	CAST(AVG(CASE WHEN deal_stage = 'Won' THEN 1.0 ELSE 0.0 END) * 100 AS DECIMAL(5,1)) AS win_rate_pct,
    FORMAT(
        SUM(CASE WHEN deal_stage = 'Won' THEN close_value ELSE 0 END), 'C0') AS total_won_revenue,
    FORMAT(
        AVG(CASE WHEN deal_stage = 'Won' THEN close_value END), 'C0') AS avg_deal_size_won,
    CAST(
        AVG(CASE WHEN deal_stage = 'Won' THEN CAST(DATEDIFF(DAY, engage_date, close_date) AS FLOAT) END) AS DECIMAL(5,1))
		AS avg_sales_cycle_days

FROM sales_pipeline;

-- Deal stage

SELECT deal_stage, COUNT(*) AS total,
    CAST(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER() AS DECIMAL(5,1)) AS pct_of_pipeline
FROM sales_pipeline
GROUP BY deal_stage
ORDER BY total DESC;

-- Lost deal analysis

SELECT COUNT(*) AS lost_deals,
       CAST(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM sales_pipeline) AS DECIMAL(5,1)) AS pct_of_pipeline,
       CAST(AVG(close_value * 1.0) AS DECIMAL(10,0)) AS avg_lost_deal_value,
       SUM(CAST(close_value AS MONEY)) AS total_lost_value,
       (SELECT TOP 1 product
       FROM sales_pipeline
       WHERE deal_stage = 'Lost'
       GROUP BY product
       ORDER BY COUNT(*) DESC) AS top_lost_product,
       (SELECT TOP 1 t2.manager
       FROM sales_pipeline p2
       JOIN sales_teams    t2 ON p2.sales_agent = t2.sales_agent
       WHERE p2.deal_stage = 'Lost'
       GROUP BY t2.manager
       ORDER BY COUNT(*) DESC) AS most_losses_manager
FROM sales_pipeline
WHERE deal_stage = 'Lost';

-- 2. PIPELINE OVERVIEW
-- Monthly won revenue

SELECT
    FORMAT(close_date, 'yyyy-MM') AS close_month,
    COUNT(*) AS deals_won,
    SUM(close_value) AS revenue,
    LAG(SUM(close_value)) OVER (ORDER BY FORMAT(close_date,'yyyy-MM')) AS prev_month_revenue,
    CAST((SUM(close_value) - LAG(SUM(close_value)) OVER (ORDER BY FORMAT(close_date,'yyyy-MM')))
        / NULLIF(LAG(SUM(close_value)) OVER (ORDER BY FORMAT(close_date,'yyyy-MM')), 0) * 100 AS DECIMAL(5,1)) AS mom_growth_pct
FROM sales_pipeline
WHERE deal_stage = 'Won'
GROUP BY FORMAT(close_date, 'yyyy-MM')
ORDER BY close_month;

-- Quaterly won revenue with QoQ growth

WITH quarterly AS (
    SELECT
        CONCAT(YEAR(close_date), ' Q', DATEPART(QUARTER, close_date)) AS close_quarter,
        YEAR(close_date) AS yr,
        DATEPART(QUARTER, close_date) AS qtr,
        COUNT(*) AS deals_won,
        SUM(close_value) AS revenue,
        COUNT(*) * 100.0 / SUM(COUNT(*)) OVER() AS pct_deals
    FROM sales_pipeline
    WHERE deal_stage = 'Won'
    GROUP BY YEAR(close_date), DATEPART(QUARTER, close_date)
)
SELECT
    close_quarter, deals_won,
    CAST(revenue AS DECIMAL(12,0)) AS revenue,
    LAG(revenue) OVER (ORDER BY yr, qtr) AS prev_quarter_revenue,
    CAST(
        (revenue - LAG(revenue) OVER (ORDER BY yr, qtr))
        / NULLIF(LAG(revenue) OVER (ORDER BY yr, qtr), 0) * 100 AS DECIMAL(5,1)) AS qoq_revenue_growth_pct,
    CAST(pct_deals AS DECIMAL(5,1)) AS pct_of_annual_deals
FROM quarterly
ORDER BY yr, qtr;

-- Best quater by revenue

SELECT TOP 1
    CONCAT(YEAR(close_date), 'Q', DATEPART(QUARTER, close_date)) AS item,
    SUM(close_value) AS revenue, COUNT(*) AS won_deals,
    CAST(
        SUM(close_value) * 100.0 / SUM(SUM(close_value)) OVER () AS DECIMAL(5,1)) AS pct_of_annual_revenue
FROM sales_pipeline
WHERE deal_stage = 'Won'
GROUP BY YEAR(close_date), DATEPART(QUARTER, close_date)
ORDER BY revenue DESC;

-- Revenue by region

SELECT t.regional_office, COUNT(*) AS total_opps,
    SUM(CASE WHEN p.deal_stage = 'Won' THEN 1 ELSE 0 END) AS won_deals,
    CAST(SUM(CASE WHEN p.deal_stage = 'Won' THEN 1.0 ELSE 0 END) / COUNT(*) * 100 AS DECIMAL(5,1)) AS win_rate_pct,
    SUM(CASE WHEN p.deal_stage = 'Won' THEN p.close_value ELSE 0 END) AS total_revenue
FROM sales_pipeline  p
JOIN sales_teams t ON p.sales_agent = t.sales_agent
GROUP BY t.regional_office
ORDER BY total_revenue DESC;

-- Top region by revenue

SELECT TOP 1
    t.regional_office AS item,
    SUM(p.close_value) AS revenue,
    COUNT(*) AS won_deals,
    CAST(SUM(CASE WHEN p.deal_stage = 'Won' THEN 1.0 ELSE 0 END) / COUNT(*) * 100 AS DECIMAL(5,1)) AS win_rate_pct
FROM sales_pipeline  p
JOIN sales_teams     t ON p.sales_agent = t.sales_agent
WHERE p.deal_stage = 'Won'
GROUP BY t.regional_office
ORDER BY revenue DESC;

-- Revenue by sector

SELECT TOP 8
    a.sector, COUNT(*) AS total_opps,
    SUM(CASE WHEN p.deal_stage = 'Won' THEN 1 ELSE 0 END) AS won_deals,
    CAST(SUM(CASE WHEN p.deal_stage = 'Won' THEN 1.0 ELSE 0 END) / COUNT(*) * 100 AS DECIMAL(5,1)) AS win_rate_pct,
    SUM(CASE WHEN p.deal_stage = 'Won' THEN p.close_value ELSE 0 END) AS total_revenue
FROM sales_pipeline p
JOIN accounts a ON p.account = a.account
WHERE p.deal_stage = 'Won'
GROUP BY a.sector
ORDER BY total_revenue DESC;

-- 3. PRODUCT ANALYSIS
-- Product performance with win rate & avg deal

SELECT p.product, pr.series, pr.sales_price AS list_price,
       COUNT(*) AS total_opps,
       SUM(CASE WHEN p.deal_stage = 'Won' THEN 1 ELSE 0 END) AS won_deals,
       CAST(SUM(CASE WHEN p.deal_stage = 'Won' THEN 1.0 ELSE 0 END) / COUNT(*) * 100 AS DECIMAL(5,1)) AS win_rate_pct,
       SUM(CASE WHEN p.deal_stage = 'Won' THEN p.close_value ELSE 0 END) AS total_revenue,
       CAST(AVG(CASE WHEN p.deal_stage = 'Won' THEN p.close_value END) AS DECIMAL(10,0)) AS avg_deal_size
FROM sales_pipeline p
JOIN products pr ON p.product = pr.product
GROUP BY p.product, pr.series, pr.sales_price
ORDER BY win_rate_pct DESC;

-- Win rate VS list price comparison

SELECT p.product, pr.sales_price AS list_price,
       CAST(AVG(CASE WHEN p.deal_stage = 'Won' THEN p.close_value END) AS DECIMAL(10,0)) AS avg_closed_price,
       CAST((pr.sales_price - AVG(CASE WHEN p.deal_stage = 'Won' THEN p.close_value END)) / pr.sales_price * 100 AS DECIMAL(5,1)) AS avg_discount_pct,
       CAST(SUM(CASE WHEN p.deal_stage = 'Won' THEN 1.0 ELSE 0 END) / COUNT(*) * 100 AS DECIMAL(5,1)) AS win_rate_pct
FROM sales_pipeline  p
JOIN products pr ON p.product = pr.product
GROUP BY p.product, pr.sales_price
ORDER BY win_rate_pct DESC;

-- 4. SALES TEAM ANALYSIS
-- Manager level performance

SELECT t.manager, t.regional_office, COUNT(*) AS total_opps,
       SUM(CASE WHEN p.deal_stage = 'Won' THEN 1 ELSE 0 END) AS won_deals,
       SUM(CASE WHEN p.deal_stage = 'Lost' THEN 1 ELSE 0 END) AS lost_deals,
       CAST(SUM(CASE WHEN p.deal_stage = 'Won' THEN 1.0 ELSE 0 END) / COUNT(*) * 100 AS DECIMAL(5,1)) AS win_rate_pct,
       SUM(CASE WHEN p.deal_stage = 'Won' THEN p.close_value ELSE 0 END) AS total_revenue,
       CAST(AVG(CASE WHEN p.deal_stage = 'Won' THEN p.close_value END) AS DECIMAL(10,0)) AS avg_deal_size,
       CAST(AVG(CASE WHEN p.deal_stage = 'Won'
                  THEN CAST(DATEDIFF(DAY, p.engage_date, p.close_date) AS FLOAT) END) AS DECIMAL(5,1)) AS avg_cycle_days,
       RANK() OVER (ORDER BY SUM(CASE WHEN p.deal_stage = 'Won' THEN 1.0 ELSE 0 END) / COUNT(*) DESC) AS win_rate_rank
FROM sales_pipeline p
JOIN sales_teams t ON p.sales_agent = t.sales_agent
GROUP BY t.manager, t.regional_office
ORDER BY win_rate_rank;

-- Agent level performance

SELECT p.sales_agent, t.manager, t.regional_office, COUNT(*) AS total_opps,
       SUM(CASE WHEN p.deal_stage = 'Won' THEN 1 ELSE 0 END) AS won_deals,
       SUM(CASE WHEN p.deal_stage = 'Lost' THEN 1 ELSE 0 END) AS lost_deals,
       CAST(SUM(CASE WHEN p.deal_stage = 'Won' THEN 1.0 ELSE 0 END) / COUNT(*) * 100 AS DECIMAL(5,1)) AS win_rate_pct,
       SUM(CASE WHEN p.deal_stage = 'Won' THEN p.close_value ELSE 0 END) AS total_revenue,
       CAST(AVG(CASE WHEN p.deal_stage = 'Won'
                  THEN CAST(DATEDIFF(DAY, p.engage_date, p.close_date) AS FLOAT) END) AS DECIMAL(5,1)) AS avg_cycle_days,
       RANK() OVER (ORDER BY SUM(CASE WHEN p.deal_stage = 'Won' THEN 1.0 ELSE 0 END) / COUNT(*) DESC) AS win_rate_rank
FROM sales_pipeline p
JOIN sales_teams t ON p.sales_agent = t.sales_agent
GROUP BY p.sales_agent, t.manager, t.regional_office
ORDER BY win_rate_pct DESC;

-- Top 10 agents by revenue

SELECT TOP 10
    p.sales_agent, t.manager, SUM(p.close_value) AS total_revenue, COUNT(*) AS won_deals,
    CAST(AVG(p.close_value) AS DECIMAL(10,0)) AS avg_deal_size,
    RANK() OVER (ORDER BY SUM(p.close_value) DESC) AS revenue_rank
FROM sales_pipeline p
JOIN sales_teams t ON p.sales_agent = t.sales_agent
WHERE p.deal_stage = 'Won'
GROUP BY p.sales_agent, t.manager
ORDER BY total_revenue DESC;

-- Top 10 agents by win rate

SELECT TOP 10
    p.sales_agent, t.manager, COUNT(*) AS total_opps,
    SUM(CASE WHEN p.deal_stage = 'Won' THEN 1 ELSE 0 END) AS won_deals,
    CAST(SUM(CASE WHEN p.deal_stage = 'Won' THEN 1.0 ELSE 0 END) / COUNT(*) * 100 AS DECIMAL(5,1)) AS win_rate_pct
FROM sales_pipeline p
JOIN sales_teams t ON p.sales_agent = t.sales_agent
GROUP BY p.sales_agent, t.manager
HAVING COUNT(*) >= 100
ORDER BY win_rate_pct DESC;

-- 5. ACCOUNT & SECTOR ANALYSIS
-- Top 10 accounts by revenue

SELECT TOP 10
    p.account, a.sector, a.office_location, a.employee,
    COUNT(*) AS total_opps,
    SUM(CASE WHEN p.deal_stage = 'Won' THEN 1 ELSE 0 END) AS won_deals,
    CAST(SUM(CASE WHEN p.deal_stage = 'Won' THEN 1.0 ELSE 0 END) / COUNT(*) * 100 AS DECIMAL(5,1)) AS win_rate_pct,
    SUM(CASE WHEN p.deal_stage = 'Won' THEN p.close_value ELSE 0 END) AS total_revenue
FROM sales_pipeline p
JOIN accounts a ON p.account = a.account
GROUP BY p.account, a.sector, a.office_location, a.employee
ORDER BY total_revenue DESC;

-- Sector win rate & revenue

SELECT
    a.sector, COUNT(*) AS total_opps,
    SUM(CASE WHEN p.deal_stage = 'Won' THEN 1 ELSE 0 END) AS won_deals,
    CAST(SUM(CASE WHEN p.deal_stage = 'Won' THEN 1.0 ELSE 0 END) / COUNT(*) * 100 AS DECIMAL(5,1)) AS win_rate_pct,
    SUM(CASE WHEN p.deal_stage = 'Won' THEN p.close_value ELSE 0 END) AS total_revenue,
    CAST(AVG(CASE WHEN p.deal_stage = 'Won' THEN p.close_value END) AS DECIMAL(10,0)) AS avg_deal_size
FROM sales_pipeline p
JOIN accounts a ON p.account = a.account
GROUP BY a.sector
ORDER BY total_revenue DESC;

-- Top sector by revenue

SELECT TOP 1
    a.sector AS item,
    SUM(p.close_value) AS revenue,
    COUNT(*) AS won_deals,
    CAST(SUM(p.close_value) * 100.0 / SUM(SUM(p.close_value)) OVER () AS DECIMAL(5,1)) AS pct_of_total_revenue
FROM sales_pipeline p
JOIN accounts a ON p.account = a.account
WHERE p.deal_stage = 'Won'
GROUP BY a.sector
ORDER BY revenue DESC;

-- END --------------------------------------------------------------------------------------------------------