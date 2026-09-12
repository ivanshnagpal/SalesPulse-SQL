-- ============================================================
-- PROJECT  : SalesPulse — Sales Analytics System
-- FILE     : 06_advanced.sql
-- PURPOSE  : Advanced SQL — Views, Stored Procedures,
--            Window Functions, CTEs
-- CONCEPTS : CREATE VIEW, CALL procedure, RANK, DENSE_RANK,
--            ROW_NUMBER, LAG, SUM OVER (running total),
--            WITH (CTE), chained CTEs
-- ============================================================

-- ════════════════════════════════════════════════════════════
-- SECTION 1: VIEWS
-- A VIEW is a saved SELECT query stored in the DB.
-- It behaves like a virtual table — no data stored, runs fresh each time.
-- Benefits: Reusability, security, simplify complex queries.
-- ════════════════════════════════════════════════════════════

-- VIEW 1: Full sales report — 4-table JOIN saved as a reusable view
-- After creating this, run: SELECT * FROM vw_sales_report;
CREATE OR REPLACE VIEW vw_sales_report AS
SELECT
    fs.sale_id,
    fs.sale_date,
    YEAR(fs.sale_date)   AS sale_year,
    MONTH(fs.sale_date)  AS sale_month,
    dc.full_name         AS customer_name,
    dc.segment,
    dr.region_name,
    dr.zone,
    dp.product_name,
    dp.category,
    dsp.full_name        AS salesperson_name,
    fs.quantity,
    fs.unit_price,
    fs.discount_pct,
    fs.total_amount,
    dp.cost_price,
    ROUND(fs.total_amount - (fs.quantity * dp.cost_price), 2) AS gross_profit,
    fs.payment_method,
    fs.status
FROM fact_sales fs
INNER JOIN dim_customer    dc  ON fs.customer_id    = dc.customer_id
INNER JOIN dim_product     dp  ON fs.product_id     = dp.product_id
INNER JOIN dim_salesperson dsp ON fs.salesperson_id = dsp.salesperson_id
INNER JOIN dim_region      dr  ON dc.region_id      = dr.region_id;

-- Using the view — simple queries on top of complex JOIN:
SELECT * FROM vw_sales_report WHERE status = 'Completed' ORDER BY total_amount DESC;
SELECT zone, SUM(total_amount) AS revenue FROM vw_sales_report GROUP BY zone;
SELECT * FROM vw_sales_report WHERE segment = 'Enterprise';

-- VIEW 2: Customer lifetime value and buyer status
CREATE OR REPLACE VIEW vw_customer_summary AS
SELECT
    dc.customer_id,
    dc.full_name,
    dc.email,
    dc.segment,
    dr.region_name,
    dc.signup_date,
    dc.is_active,
    COUNT(fs.sale_id)                             AS total_orders,
    COALESCE(ROUND(SUM(fs.total_amount), 2), 0)   AS lifetime_value,
    MAX(fs.sale_date)                             AS last_purchase_date,
    CASE
        WHEN COUNT(fs.sale_id) = 0               THEN 'Never Purchased'
        WHEN MAX(fs.sale_date) < DATE_SUB(CURDATE(), INTERVAL 6 MONTH)
                                                 THEN 'Dormant'
        ELSE                                          'Active Buyer'
    END AS buyer_status
FROM dim_customer dc
LEFT JOIN fact_sales fs ON dc.customer_id = fs.customer_id
                       AND fs.status = 'Completed'
INNER JOIN dim_region dr ON dc.region_id = dr.region_id
GROUP BY dc.customer_id, dc.full_name, dc.email, dc.segment,
         dr.region_name, dc.signup_date, dc.is_active;

-- Using the view:
SELECT * FROM vw_customer_summary WHERE buyer_status = 'Never Purchased';
SELECT * FROM vw_customer_summary ORDER BY lifetime_value DESC LIMIT 5;

-- VIEW 3: Product performance summary
CREATE OR REPLACE VIEW vw_product_performance AS
SELECT
    dp.product_id,
    dp.product_name,
    dp.category,
    dp.unit_price,
    COALESCE(COUNT(fs.sale_id), 0)                               AS times_sold,
    COALESCE(SUM(fs.quantity), 0)                                AS units_sold,
    COALESCE(ROUND(SUM(fs.total_amount), 2), 0)                  AS total_revenue,
    COALESCE(ROUND(SUM(fs.quantity * dp.cost_price), 2), 0)      AS total_cost,
    COALESCE(ROUND(
        SUM(fs.total_amount) - SUM(fs.quantity * dp.cost_price), 2
    ), 0)                                                        AS gross_profit
FROM dim_product dp
LEFT JOIN fact_sales fs ON dp.product_id = fs.product_id
                       AND fs.status = 'Completed'
GROUP BY dp.product_id, dp.product_name, dp.category, dp.unit_price;

SELECT * FROM vw_product_performance ORDER BY gross_profit DESC;

-- ════════════════════════════════════════════════════════════
-- SECTION 2: STORED PROCEDURES
-- Named, saved SQL blocks stored in the DB.
-- Accept parameters. Called with CALL.
-- Benefits: Reusability, pre-compiled speed, security.
-- ════════════════════════════════════════════════════════════

DELIMITER $$

-- PROCEDURE 1: All sales for a given customer
-- How to call: CALL sp_customer_sales(1);
CREATE PROCEDURE sp_customer_sales(IN p_customer_id INT)
BEGIN
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
    WHERE fs.customer_id = p_customer_id
    ORDER BY fs.sale_date DESC;
END$$

-- PROCEDURE 2: Monthly revenue for any year
-- How to call: CALL sp_monthly_revenue(2024);
CREATE PROCEDURE sp_monthly_revenue(IN p_year INT)
BEGIN
    SELECT
        MONTH(sale_date)              AS month_num,
        MONTHNAME(sale_date)          AS month_name,
        COUNT(sale_id)                AS total_orders,
        ROUND(SUM(total_amount), 2)   AS revenue
    FROM fact_sales
    WHERE YEAR(sale_date) = p_year
      AND status = 'Completed'
    GROUP BY MONTH(sale_date), MONTHNAME(sale_date)
    ORDER BY month_num;
END$$

-- PROCEDURE 3: Salesperson performance report
-- How to call: CALL sp_salesperson_report(3);
CREATE PROCEDURE sp_salesperson_report(IN p_salesperson_id INT)
BEGIN
    SELECT
        dsp.full_name      AS salesperson,
        dsp.target_amount,
        COUNT(fs.sale_id)              AS deals_closed,
        ROUND(SUM(fs.total_amount), 2) AS achieved,
        ROUND(SUM(fs.total_amount) / dsp.target_amount * 100, 2) AS target_pct,
        CASE
            WHEN SUM(fs.total_amount) >= dsp.target_amount THEN 'Target Hit'
            WHEN SUM(fs.total_amount) >= dsp.target_amount * 0.75 THEN 'On Track'
            ELSE 'Needs Push'
        END AS status_flag
    FROM dim_salesperson dsp
    LEFT JOIN fact_sales fs ON dsp.salesperson_id = fs.salesperson_id
                           AND fs.status = 'Completed'
    WHERE dsp.salesperson_id = p_salesperson_id
    GROUP BY dsp.salesperson_id, dsp.full_name, dsp.target_amount;
END$$

-- PROCEDURE 4: Add a new product to catalogue
-- How to call: CALL sp_add_product('Smart Hub 5G', 'Electronics', 45000, 28000);
CREATE PROCEDURE sp_add_product(
    IN p_name      VARCHAR(100),
    IN p_category  VARCHAR(50),
    IN p_price     DECIMAL(10,2),
    IN p_cost      DECIMAL(10,2)
)
BEGIN
    INSERT INTO dim_product (product_name, category, unit_price, cost_price)
    VALUES (p_name, p_category, p_price, p_cost);
    SELECT LAST_INSERT_ID() AS new_product_id,
           p_name           AS product_name,
           'Added successfully' AS result;
END$$

DELIMITER ;

-- Call examples:
CALL sp_customer_sales(1);
CALL sp_monthly_revenue(2024);
CALL sp_salesperson_report(4);
CALL sp_add_product('Smart Hub 5G', 'Electronics', 45000, 28000);

-- ════════════════════════════════════════════════════════════
-- SECTION 3: WINDOW FUNCTIONS
-- Compute across a set of rows while keeping every individual row.
-- Unlike GROUP BY which collapses rows, window functions ADD a column.
-- Syntax: function() OVER (PARTITION BY ... ORDER BY ...)
-- PARTITION BY = define the group | ORDER BY = define ordering in group
-- ════════════════════════════════════════════════════════════

-- W1: ROW_NUMBER — number each sale per customer in date order
-- Business: Show each customer's 1st, 2nd, 3rd order sequence
SELECT
    dc.full_name      AS customer,
    fs.sale_date,
    fs.total_amount,
    ROW_NUMBER() OVER (
        PARTITION BY fs.customer_id
        ORDER BY fs.sale_date
    ) AS order_number
FROM fact_sales fs
INNER JOIN dim_customer dc ON fs.customer_id = dc.customer_id
WHERE fs.status = 'Completed'
ORDER BY dc.full_name, fs.sale_date;

-- W2: RANK vs DENSE_RANK — customer revenue ranking
-- RANK: 1,2,2,4  (skips after tie)
-- DENSE_RANK: 1,2,2,3  (no skip)
SELECT
    dc.full_name,
    dc.segment,
    ROUND(SUM(fs.total_amount), 2)                                 AS total_spent,
    RANK()       OVER (ORDER BY SUM(fs.total_amount) DESC)         AS rank_with_gap,
    DENSE_RANK() OVER (ORDER BY SUM(fs.total_amount) DESC)         AS rank_no_gap,
    RANK()       OVER (PARTITION BY dc.segment
                       ORDER BY SUM(fs.total_amount) DESC)         AS segment_rank
FROM fact_sales fs
INNER JOIN dim_customer dc ON fs.customer_id = dc.customer_id
WHERE fs.status = 'Completed'
GROUP BY dc.customer_id, dc.full_name, dc.segment
ORDER BY total_spent DESC;

-- W3: LAG — month-over-month revenue change
-- LAG(col, 1) gets the value from the PREVIOUS row in the window
SELECT
    YEAR(sale_date)              AS yr,
    MONTH(sale_date)             AS mo,
    MONTHNAME(sale_date)         AS month_name,
    ROUND(SUM(total_amount), 2)  AS revenue,
    LAG(ROUND(SUM(total_amount), 2)) OVER (
        ORDER BY YEAR(sale_date), MONTH(sale_date)
    )                            AS prev_month_revenue,
    ROUND(
        SUM(total_amount) -
        LAG(SUM(total_amount)) OVER (ORDER BY YEAR(sale_date), MONTH(sale_date))
    , 2)                         AS mom_change
FROM fact_sales
WHERE status = 'Completed'
GROUP BY YEAR(sale_date), MONTH(sale_date), MONTHNAME(sale_date)
ORDER BY yr, mo;

-- W4: Running total (cumulative revenue over time)
-- Business: Track how revenue accumulates through the year
SELECT
    sale_date,
    total_amount,
    ROUND(
        SUM(total_amount) OVER (
            ORDER BY sale_date
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ), 2
    ) AS running_total
FROM fact_sales
WHERE status = 'Completed'
ORDER BY sale_date;

-- ════════════════════════════════════════════════════════════
-- SECTION 4: CTEs (Common Table Expressions)
-- Named temporary result sets using WITH.
-- Cleaner than nested subqueries — you name each step.
-- ════════════════════════════════════════════════════════════

-- CTE 1: Simple CTE — customer totals, then classify
-- Business: Revenue tier classification using clean modular steps
WITH customer_revenue AS (
    SELECT
        fs.customer_id,
        ROUND(SUM(fs.total_amount), 2) AS total_spent
    FROM fact_sales fs
    WHERE fs.status = 'Completed'
    GROUP BY fs.customer_id
)
SELECT
    dc.full_name,
    dc.segment,
    cr.total_spent,
    CASE
        WHEN cr.total_spent >= 500000 THEN 'Platinum'
        WHEN cr.total_spent >= 200000 THEN 'Gold'
        WHEN cr.total_spent >= 50000  THEN 'Silver'
        ELSE                               'Bronze'
    END AS tier
FROM customer_revenue cr
INNER JOIN dim_customer dc ON cr.customer_id = dc.customer_id
ORDER BY cr.total_spent DESC;

-- CTE 2: Chained CTEs — top product per category
-- Business: One winner per category for promotional highlight
WITH product_revenue AS (
    SELECT
        dp.category,
        dp.product_name,
        ROUND(SUM(fs.total_amount), 2) AS revenue,
        RANK() OVER (
            PARTITION BY dp.category
            ORDER BY SUM(fs.total_amount) DESC
        ) AS rnk
    FROM fact_sales fs
    INNER JOIN dim_product dp ON fs.product_id = dp.product_id
    WHERE fs.status = 'Completed'
    GROUP BY dp.category, dp.product_name
)
SELECT category, product_name, revenue
FROM product_revenue
WHERE rnk = 1
ORDER BY revenue DESC;
