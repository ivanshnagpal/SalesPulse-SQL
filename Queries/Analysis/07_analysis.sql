-- ============================================================
-- PROJECT  : SalesPulse — Sales Analytics System
-- FILE     : 07_analysis.sql
-- PURPOSE  : Business analysis queries + data validation + normalization proof
-- CONCEPTS : Normalization proof queries, data cleaning pipeline,
--            UNION ALL validation, INSERT...SELECT, REGEXP checks
-- ============================================================

-- ════════════════════════════════════════════════════════════
-- SECTION 1: NORMALIZATION PROOF QUERIES
-- ════════════════════════════════════════════════════════════

-- NORM-1: Prove 1NF — every value is atomic (single value per cell)
-- customer phone is one number, not "9876,9123"
SELECT full_name, phone FROM dim_customer LIMIT 5;

-- NORM-2: Prove 2NF — product_name is NOT in fact_sales
-- It lives in dim_product because it depends on product_id alone
SELECT 'product_name correctly in dim_product, not in fact_sales' AS proof_2nf;
DESCRIBE fact_sales;   -- notice: no product_name column here
DESCRIBE dim_product;  -- product_name is here

-- NORM-3: Prove 3NF — region_name is NOT in dim_customer
-- region_name depends on region_id, not customer_id → 3NF violation avoided
SELECT dc.full_name, dc.region_id, dr.region_name, dr.zone
FROM dim_customer dc
INNER JOIN dim_region dr ON dc.region_id = dr.region_id
LIMIT 5;
-- Explanation: knowing customer_id does NOT directly tell you region_name.
-- It tells you region_id → which tells you region_name (transitive removed).

-- NORM-4: Functional dependency — knowing product_id tells you everything about the product
SELECT * FROM dim_product WHERE product_id = 1;
-- product_id → product_name, category, unit_price, cost_price

-- NORM-5: Functional dependency — knowing sale_id tells you the full transaction
SELECT * FROM fact_sales WHERE sale_id = 1;

-- ════════════════════════════════════════════════════════════
-- SECTION 2: DATA CLEANING PIPELINE
-- ════════════════════════════════════════════════════════════

-- CLEAN-1: Inspect the raw dirty data
SELECT * FROM raw_sales_staging;

-- CLEAN-2: Diagnose all issues in the staging table
SELECT
    row_id,
    cust_name,
    CASE WHEN TRIM(cust_name) = '' OR cust_name IS NULL
         THEN 'MISSING' ELSE 'OK' END          AS name_check,
    qty,
    CASE WHEN qty REGEXP '^[0-9]+$'
         THEN 'OK' ELSE 'BAD — not numeric' END AS qty_check,
    price,
    CASE WHEN price REGEXP '^[0-9]+$'
         THEN 'OK' ELSE 'NEEDS CLEANING' END    AS price_check,
    status,
    UPPER(TRIM(status))                         AS normalized_status
FROM raw_sales_staging;

-- CLEAN-3: Preview the cleaned version (no write yet)
SELECT
    row_id,
    TRIM(LOWER(cust_name))                                   AS clean_name,
    TRIM(prod_name)                                          AS clean_product,
    TRIM(REPLACE(REPLACE(price, '$', ''), ',', ''))          AS clean_price,
    CASE WHEN qty REGEXP '^[0-9]+$' THEN CAST(qty AS UNSIGNED) ELSE NULL END AS clean_qty,
    CASE
        WHEN UPPER(TRIM(status)) IN ('COMPLETED','DONE','COMPLETE') THEN 'Completed'
        WHEN UPPER(TRIM(status)) = 'PENDING'                        THEN 'Pending'
        ELSE 'Unknown'
    END                                                      AS clean_status,
    region
FROM raw_sales_staging
WHERE TRIM(cust_name) != ''
  AND qty REGEXP '^[0-9]+$'
  AND price NOT REGEXP '[A-Za-z]';

-- CLEAN-4: INSERT cleaned records using INSERT...SELECT pipeline
-- This is how real ETL pipelines work in companies
CREATE TABLE IF NOT EXISTS clean_sales_staging (
    row_id        INT,
    customer_name VARCHAR(100),
    product_name  VARCHAR(150),
    quantity      INT,
    price         DECIMAL(10,2),
    region        VARCHAR(80),
    pay_method    VARCHAR(50),
    status        VARCHAR(20)
);

INSERT INTO clean_sales_staging
SELECT
    row_id,
    TRIM(LOWER(cust_name)),
    TRIM(prod_name),
    CAST(qty AS UNSIGNED),
    CAST(TRIM(REPLACE(REPLACE(price,'$',''),',',' ')) AS DECIMAL(10,2)),
    TRIM(region),
    TRIM(pay_method),
    CASE
        WHEN UPPER(TRIM(status)) IN ('COMPLETED','DONE','COMPLETE') THEN 'Completed'
        WHEN UPPER(TRIM(status)) = 'PENDING'                        THEN 'Pending'
        ELSE 'Unknown'
    END
FROM raw_sales_staging
WHERE TRIM(cust_name) != ''
  AND qty REGEXP '^[0-9]+$'
  AND price NOT REGEXP '[A-Za-z]';

-- CLEAN-5: Verify cleaned data
SELECT * FROM clean_sales_staging;

-- ════════════════════════════════════════════════════════════
-- SECTION 3: DATA VALIDATION QUERIES
-- ════════════════════════════════════════════════════════════

-- VAL-1: Duplicate customer emails
SELECT email, COUNT(*) AS occurrences
FROM dim_customer
GROUP BY email
HAVING COUNT(*) > 1;

-- VAL-2: Orphan sales — sale references customer that doesn't exist
SELECT fs.sale_id, fs.customer_id
FROM fact_sales fs
WHERE fs.customer_id NOT IN (SELECT customer_id FROM dim_customer);

-- VAL-3: Sales with zero or negative total amount
SELECT sale_id, customer_id, total_amount
FROM fact_sales
WHERE total_amount <= 0;

-- VAL-4: Invalid discount percentage (must be 0-100)
SELECT sale_id, discount_pct
FROM fact_sales
WHERE discount_pct < 0 OR discount_pct > 100;

-- VAL-5: Returns without a matching sale record
SELECT fr.return_id, fr.sale_id
FROM fact_returns fr
WHERE fr.sale_id NOT IN (SELECT sale_id FROM fact_sales);

-- VAL-6: UNION ALL — Full validation summary report
-- Business: Run this before any monthly reporting cycle
SELECT 'Duplicate customer emails'        AS check_name, COUNT(*) AS issues
FROM (SELECT email FROM dim_customer GROUP BY email HAVING COUNT(*) > 1) x
UNION ALL
SELECT 'Zero or negative sale amounts',   COUNT(*)
FROM fact_sales WHERE total_amount <= 0
UNION ALL
SELECT 'Invalid discount (>100%)',        COUNT(*)
FROM fact_sales WHERE discount_pct > 100
UNION ALL
SELECT 'Orphan sales (missing customer)', COUNT(*)
FROM fact_sales WHERE customer_id NOT IN (SELECT customer_id FROM dim_customer)
UNION ALL
SELECT 'Inactive customers with active sales', COUNT(*)
FROM fact_sales fs
INNER JOIN dim_customer dc ON fs.customer_id = dc.customer_id
WHERE dc.is_active = FALSE AND fs.status IN ('Completed','Pending')
UNION ALL
SELECT 'Returns referencing invalid sale', COUNT(*)
FROM fact_returns WHERE sale_id NOT IN (SELECT sale_id FROM fact_sales);

-- ════════════════════════════════════════════════════════════
-- SECTION 4: TOP-N BUSINESS ANALYSIS QUERIES
-- ════════════════════════════════════════════════════════════

-- BIZ-1: Top 5 customers by revenue (classic Top-N query)
SELECT
    dc.full_name,
    dc.segment,
    ROUND(SUM(fs.total_amount), 2) AS total_revenue
FROM fact_sales fs
INNER JOIN dim_customer dc ON fs.customer_id = dc.customer_id
WHERE fs.status = 'Completed'
GROUP BY dc.full_name, dc.segment
ORDER BY total_revenue DESC
LIMIT 5;

-- BIZ-2: Top 3 products by gross profit
SELECT
    dp.product_name,
    ROUND(SUM(fs.total_amount) - SUM(fs.quantity * dp.cost_price), 2) AS gross_profit
FROM fact_sales fs
INNER JOIN dim_product dp ON fs.product_id = dp.product_id
WHERE fs.status = 'Completed'
GROUP BY dp.product_name
ORDER BY gross_profit DESC
LIMIT 3;

-- BIZ-3: Quarterly revenue breakdown
SELECT
    YEAR(sale_date)   AS yr,
    QUARTER(sale_date) AS quarter,
    COUNT(sale_id)               AS orders,
    ROUND(SUM(total_amount), 2)  AS revenue
FROM fact_sales
WHERE status = 'Completed'
GROUP BY YEAR(sale_date), QUARTER(sale_date)
ORDER BY yr, quarter;

-- BIZ-4: Payment method mix — count and revenue share
SELECT
    payment_method,
    COUNT(*)                    AS count,
    ROUND(SUM(total_amount), 2) AS revenue,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) AS pct_of_orders
FROM fact_sales
WHERE status = 'Completed'
GROUP BY payment_method
ORDER BY count DESC;
