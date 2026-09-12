-- ============================================================
-- PROJECT  : SalesPulse — Sales Analytics System
-- FILE     : 04_joins.sql
-- PURPOSE  : All JOIN types with real business context
-- CONCEPTS : INNER JOIN, LEFT JOIN, RIGHT JOIN, SELF JOIN,
--            3-4 table joins, JOIN + aggregation, NULL detection
-- ============================================================

-- ════════════════════════════════════════════════════════════
-- WHAT IS A JOIN? (say this in interviews)
-- Tables in a normalised DB store data separately to avoid
-- redundancy. JOINs reassemble that data at query time.
-- fact_sales has customer_id (a number). To see the name,
-- INNER JOIN dim_customer ON customer_id.
-- ════════════════════════════════════════════════════════════

-- ════════════════════════════════════════════════════════════
-- SECTION 1: INNER JOIN
-- Returns only rows where the condition matches in BOTH tables.
-- ════════════════════════════════════════════════════════════

-- Q1: Basic INNER JOIN — sales with product details
-- Business: Transaction report showing what was sold
SELECT
    fs.sale_id,
    fs.sale_date,
    dp.product_name,
    dp.category,
    fs.quantity,
    fs.total_amount,
    fs.status
FROM fact_sales fs
INNER JOIN dim_product dp ON fs.product_id = dp.product_id
WHERE fs.status = 'Completed'
ORDER BY fs.total_amount DESC;

-- Q2: 3-table INNER JOIN — sales + customer + product
-- Business: Full transaction detail with buyer info
SELECT
    fs.sale_id,
    fs.sale_date,
    dc.full_name      AS customer,
    dc.segment,
    dp.product_name,
    dp.category,
    fs.quantity,
    fs.total_amount
FROM fact_sales fs
INNER JOIN dim_customer dc ON fs.customer_id = dc.customer_id
INNER JOIN dim_product  dp ON fs.product_id  = dp.product_id
WHERE fs.status = 'Completed'
ORDER BY fs.sale_date;

-- Q3: 4-table INNER JOIN — complete sales context (management report)
-- Business: One query that gives the full picture of every transaction
SELECT
    fs.sale_id,
    fs.sale_date,
    dc.full_name       AS customer,
    dc.segment,
    dr.region_name,
    dr.zone,
    dp.product_name,
    dp.category,
    dsp.full_name      AS salesperson,
    fs.quantity,
    fs.discount_pct    AS disc_pct,
    fs.total_amount,
    fs.payment_method
FROM fact_sales fs
INNER JOIN dim_customer    dc  ON fs.customer_id    = dc.customer_id
INNER JOIN dim_product     dp  ON fs.product_id     = dp.product_id
INNER JOIN dim_salesperson dsp ON fs.salesperson_id = dsp.salesperson_id
INNER JOIN dim_region      dr  ON dc.region_id      = dr.region_id
WHERE fs.status = 'Completed'
ORDER BY fs.total_amount DESC;

-- Q4: INNER JOIN + aggregation — revenue per salesperson with region
-- Business: Sales leaderboard for monthly review meeting
SELECT
    dsp.full_name          AS salesperson,
    dr.region_name,
    dr.zone,
    COUNT(fs.sale_id)              AS deals_closed,
    ROUND(SUM(fs.total_amount), 2) AS total_revenue,
    ROUND(AVG(fs.total_amount), 2) AS avg_deal_size
FROM fact_sales fs
INNER JOIN dim_salesperson dsp ON fs.salesperson_id = dsp.salesperson_id
INNER JOIN dim_region      dr  ON dsp.region_id     = dr.region_id
WHERE fs.status = 'Completed'
GROUP BY dsp.full_name, dr.region_name, dr.zone
ORDER BY total_revenue DESC;

-- Q5: INNER JOIN + profitability — product margin report
-- Business: Which products make us the most profit?
SELECT
    dp.product_name,
    dp.category,
    COUNT(fs.sale_id)                                        AS times_sold,
    ROUND(SUM(fs.total_amount), 2)                           AS revenue,
    ROUND(SUM(fs.quantity * dp.cost_price), 2)               AS total_cost,
    ROUND(SUM(fs.total_amount) - SUM(fs.quantity * dp.cost_price), 2) AS gross_profit
FROM fact_sales fs
INNER JOIN dim_product dp ON fs.product_id = dp.product_id
WHERE fs.status = 'Completed'
GROUP BY dp.product_name, dp.category
ORDER BY gross_profit DESC;

-- Q6: INNER JOIN — zone-wise revenue summary
-- Business: North vs South vs East vs West performance
SELECT
    dr.zone,
    COUNT(DISTINCT dc.customer_id)  AS customers,
    COUNT(fs.sale_id)               AS orders,
    ROUND(SUM(fs.total_amount), 2)  AS total_revenue,
    ROUND(AVG(fs.total_amount), 2)  AS avg_order_value
FROM fact_sales fs
INNER JOIN dim_customer dc ON fs.customer_id = dc.customer_id
INNER JOIN dim_region   dr ON dc.region_id   = dr.region_id
WHERE fs.status = 'Completed'
GROUP BY dr.zone
ORDER BY total_revenue DESC;

-- Q7: INNER JOIN with HAVING — high-value regions only
-- Business: Zones generating more than ₹3L revenue
SELECT
    dr.zone,
    dr.region_name,
    ROUND(SUM(fs.total_amount), 2) AS revenue
FROM fact_sales fs
INNER JOIN dim_customer dc ON fs.customer_id = dc.customer_id
INNER JOIN dim_region   dr ON dc.region_id   = dr.region_id
WHERE fs.status = 'Completed'
GROUP BY dr.zone, dr.region_name
HAVING SUM(fs.total_amount) > 300000
ORDER BY revenue DESC;

-- ════════════════════════════════════════════════════════════
-- SECTION 2: LEFT JOIN
-- Returns ALL rows from LEFT table.
-- No match on the right = NULL values on right side.
-- KEY PATTERN: WHERE right.id IS NULL → "no match" filter
-- ════════════════════════════════════════════════════════════

-- Q8: LEFT JOIN — all customers with their order count
-- Business: Full customer list including those who haven't ordered
SELECT
    dc.full_name,
    dc.email,
    dc.segment,
    dc.signup_date,
    COUNT(fs.sale_id) AS total_orders,
    COALESCE(ROUND(SUM(fs.total_amount), 2), 0) AS lifetime_value
FROM dim_customer dc
LEFT JOIN fact_sales fs ON dc.customer_id = fs.customer_id
GROUP BY dc.customer_id, dc.full_name, dc.email, dc.segment, dc.signup_date
ORDER BY lifetime_value DESC;

-- Q9: LEFT JOIN + NULL filter — customers who NEVER purchased
-- Business: Re-engagement target list — signed up but never bought
-- THE PATTERN: LEFT JOIN then WHERE right_side.id IS NULL
SELECT
    dc.full_name,
    dc.email,
    dc.segment,
    dc.signup_date
FROM dim_customer dc
LEFT JOIN fact_sales fs ON dc.customer_id = fs.customer_id
WHERE fs.sale_id IS NULL   -- ← NULL means no matching sale row
ORDER BY dc.signup_date;

-- Q10: LEFT JOIN — all sales flagged with return status
-- Business: Full transaction view showing which were returned
SELECT
    fs.sale_id,
    dc.full_name      AS customer,
    dp.product_name,
    fs.total_amount,
    CASE
        WHEN fr.return_id IS NOT NULL THEN 'Returned'
        ELSE 'Not Returned'
    END                          AS return_status,
    COALESCE(fr.refund_amount, 0) AS refund_amount
FROM fact_sales fs
INNER JOIN dim_customer dc ON fs.customer_id = dc.customer_id
INNER JOIN dim_product  dp ON fs.product_id  = dp.product_id
LEFT JOIN  fact_returns fr ON fs.sale_id     = fr.sale_id
ORDER BY fs.sale_id;

-- Q11: LEFT JOIN — return rate per product
-- Business: Which products are being returned most often?
SELECT
    dp.product_name,
    dp.category,
    COUNT(fs.sale_id)      AS total_sold,
    COUNT(fr.return_id)    AS total_returned,
    ROUND(
        COUNT(fr.return_id) * 100.0 / NULLIF(COUNT(fs.sale_id), 0), 2
    )                      AS return_rate_pct
FROM fact_sales fs
INNER JOIN dim_product dp ON fs.product_id = dp.product_id
LEFT JOIN  fact_returns fr ON fs.sale_id   = fr.sale_id
GROUP BY dp.product_name, dp.category
ORDER BY return_rate_pct DESC;

-- ════════════════════════════════════════════════════════════
-- SECTION 3: RIGHT JOIN
-- Returns ALL rows from RIGHT table.
-- Swapping tables in a RIGHT JOIN = equivalent LEFT JOIN.
-- Useful when you want all products, even unsold ones.
-- ════════════════════════════════════════════════════════════

-- Q12: RIGHT JOIN — all products including those never sold
-- Business: Dead-stock / slow-moving product identification
SELECT
    dp.product_name,
    dp.category,
    dp.unit_price,
    COUNT(fs.sale_id)    AS times_sold,
    COALESCE(ROUND(SUM(fs.total_amount), 2), 0) AS revenue_generated
FROM fact_sales fs
RIGHT JOIN dim_product dp ON fs.product_id = dp.product_id
GROUP BY dp.product_id, dp.product_name, dp.category, dp.unit_price
ORDER BY times_sold ASC;

-- ════════════════════════════════════════════════════════════
-- SECTION 4: SELF JOIN
-- A table joined to ITSELF using two different aliases.
-- Classic use: hierarchy — employee reports to manager
-- In our schema: dim_salesperson.manager_id → dim_salesperson.salesperson_id
-- ════════════════════════════════════════════════════════════

-- Q13: SELF JOIN — every salesperson with their manager's name
-- Business: Org chart / reporting structure
-- emp = employee alias, mgr = manager alias (SAME table, 2 names)
SELECT
    emp.full_name    AS salesperson,
    emp.email        AS salesperson_email,
    emp.target_amount,
    COALESCE(mgr.full_name, 'VP / Top Level') AS reports_to,
    dr.region_name
FROM dim_salesperson emp
LEFT JOIN dim_salesperson mgr ON emp.manager_id = mgr.salesperson_id
INNER JOIN dim_region     dr  ON emp.region_id  = dr.region_id
ORDER BY mgr.full_name, emp.full_name;

-- Q14: SELF JOIN — how many direct reports does each manager have?
-- Business: Manager span-of-control analysis
SELECT
    mgr.full_name             AS manager,
    COUNT(emp.salesperson_id) AS direct_reports
FROM dim_salesperson emp
INNER JOIN dim_salesperson mgr ON emp.manager_id = mgr.salesperson_id
GROUP BY mgr.full_name
ORDER BY direct_reports DESC;

-- Q15: SELF JOIN — full team hierarchy with revenue
-- Business: Manager-level revenue accountability report
SELECT
    mgr.full_name               AS manager,
    emp.full_name               AS team_member,
    ROUND(SUM(fs.total_amount), 2) AS member_revenue
FROM dim_salesperson emp
INNER JOIN dim_salesperson mgr ON emp.manager_id  = mgr.salesperson_id
INNER JOIN fact_sales      fs  ON emp.salesperson_id = fs.salesperson_id
WHERE fs.status = 'Completed'
GROUP BY mgr.full_name, emp.full_name
ORDER BY mgr.full_name, member_revenue DESC;
