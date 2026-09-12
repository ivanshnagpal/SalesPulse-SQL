-- ============================================================
-- PROJECT  : SalesPulse — Sales Analytics System
-- FILE     : 05_subqueries.sql
-- PURPOSE  : All subquery types with real business context
-- CONCEPTS : Scalar subquery, IN/NOT IN, Correlated subquery,
--            EXISTS/NOT EXISTS, FROM-clause (derived table),
--            JOIN vs Subquery side-by-side comparison
-- ============================================================

-- ════════════════════════════════════════════════════════════
-- WHAT IS A SUBQUERY?
-- A SELECT statement nested inside another SELECT.
-- The inner query runs FIRST; its result is used by the outer query.
-- Types: Scalar (1 value), IN list, Correlated (per row), FROM table
-- ════════════════════════════════════════════════════════════

-- ════════════════════════════════════════════════════════════
-- SECTION 1: SCALAR SUBQUERY
-- Returns exactly ONE value (one row, one column).
-- Placed in SELECT clause or WHERE clause.
-- ════════════════════════════════════════════════════════════

-- Q1: Scalar in SELECT — compare each sale to overall average
-- Business: Tag every transaction as above or below average
SELECT
    sale_id,
    total_amount,
    ROUND(
        (SELECT AVG(total_amount) FROM fact_sales WHERE status = 'Completed')
    , 2) AS company_avg,
    CASE
        WHEN total_amount > (SELECT AVG(total_amount) FROM fact_sales WHERE status = 'Completed')
        THEN 'Above Average'
        ELSE 'Below Average'
    END AS vs_avg
FROM fact_sales
WHERE status = 'Completed'
ORDER BY total_amount DESC;

-- Q2: Scalar in WHERE — find the single highest-value sale
-- Business: What is our biggest transaction ever?
SELECT sale_id, customer_id, product_id, total_amount, sale_date
FROM fact_sales
WHERE total_amount = (
    SELECT MAX(total_amount)
    FROM fact_sales
    WHERE status = 'Completed'
);

-- Q3: Scalar in WHERE — find the most expensive product by price
-- Business: Premium product details for enterprise pitch
SELECT product_name, category, unit_price, cost_price
FROM dim_product
WHERE unit_price = (
    SELECT MAX(unit_price) FROM dim_product
);

-- ════════════════════════════════════════════════════════════
-- SECTION 2: IN / NOT IN SUBQUERY
-- Inner query returns a LIST. Outer checks membership.
-- ════════════════════════════════════════════════════════════

-- Q4: IN — customers who have completed at least one purchase
-- Business: Verified buyer list for loyalty program
SELECT full_name, email, segment, signup_date
FROM dim_customer
WHERE customer_id IN (
    SELECT DISTINCT customer_id
    FROM fact_sales
    WHERE status = 'Completed'
)
ORDER BY full_name;

-- Q5: NOT IN — customers who have NEVER bought anything
-- Business: Dormant account list for re-engagement campaign
SELECT full_name, email, segment, signup_date
FROM dim_customer
WHERE customer_id NOT IN (
    SELECT DISTINCT customer_id
    FROM fact_sales
)
ORDER BY signup_date;

-- Q6: IN — products sold in the first quarter of 2024
-- Business: Q1 product performance check
SELECT product_name, category, unit_price
FROM dim_product
WHERE product_id IN (
    SELECT DISTINCT product_id
    FROM fact_sales
    WHERE sale_date BETWEEN '2024-01-01' AND '2024-03-31'
      AND status = 'Completed'
);

-- Q7: NOT IN — products NEVER sold (slow/dead stock)
-- Business: Inventory review — flag products with zero movement
SELECT product_name, category, unit_price
FROM dim_product
WHERE product_id NOT IN (
    SELECT DISTINCT product_id
    FROM fact_sales
    WHERE status = 'Completed'
);

-- Q8: IN with two conditions — Enterprise customers in South zone
-- Business: Enterprise penetration in southern region
SELECT full_name, email
FROM dim_customer
WHERE segment = 'Enterprise'
  AND region_id IN (
    SELECT region_id
    FROM dim_region
    WHERE zone = 'South'
  );

-- ════════════════════════════════════════════════════════════
-- SECTION 3: CORRELATED SUBQUERY
-- Inner query references a column from the OUTER query.
-- Runs once per row in the outer query.
-- ════════════════════════════════════════════════════════════

-- Q9: CORRELATED — flag if each sale is the customer's biggest order
-- Business: Identify the peak deal for every customer
-- The inner query's WHERE uses fs.customer_id from the outer query
SELECT
    fs.sale_id,
    dc.full_name      AS customer,
    fs.total_amount,
    fs.sale_date,
    CASE
        WHEN fs.total_amount = (
            SELECT MAX(fs2.total_amount)
            FROM fact_sales fs2
            WHERE fs2.customer_id = fs.customer_id   -- ← CORRELATION
              AND fs2.status = 'Completed'
        )
        THEN 'Yes — Biggest Deal'
        ELSE 'No'
    END AS is_biggest_order
FROM fact_sales fs
INNER JOIN dim_customer dc ON fs.customer_id = dc.customer_id
WHERE fs.status = 'Completed'
ORDER BY dc.full_name, fs.total_amount DESC;

-- Q10: CORRELATED — salespersons who beat their own region's average
-- Business: Star performers within each geographic zone
SELECT
    dsp.full_name     AS salesperson,
    dr.region_name,
    ROUND(SUM(fs.total_amount), 2) AS personal_revenue
FROM dim_salesperson dsp
INNER JOIN fact_sales fs ON dsp.salesperson_id = fs.salesperson_id
INNER JOIN dim_region dr  ON dsp.region_id     = dr.region_id
WHERE fs.status = 'Completed'
GROUP BY dsp.salesperson_id, dsp.full_name, dr.region_name, dsp.region_id
HAVING SUM(fs.total_amount) > (
    SELECT AVG(reg_rev)
    FROM (
        SELECT dsp2.salesperson_id, SUM(fs2.total_amount) AS reg_rev
        FROM dim_salesperson dsp2
        INNER JOIN fact_sales fs2 ON dsp2.salesperson_id = fs2.salesperson_id
        WHERE dsp2.region_id = dsp.region_id             -- ← CORRELATION
          AND fs2.status = 'Completed'
        GROUP BY dsp2.salesperson_id
    ) AS region_data
)
ORDER BY personal_revenue DESC;

-- ════════════════════════════════════════════════════════════
-- SECTION 4: EXISTS / NOT EXISTS
-- EXISTS = TRUE if inner query returns at least one row.
-- NULL-safe alternative to IN/NOT IN.
-- ════════════════════════════════════════════════════════════

-- Q11: EXISTS — customers with at least one completed sale
-- Business: Verified purchaser list
SELECT dc.full_name, dc.email, dc.segment
FROM dim_customer dc
WHERE EXISTS (
    SELECT 1
    FROM fact_sales fs
    WHERE fs.customer_id = dc.customer_id
      AND fs.status = 'Completed'
)
ORDER BY dc.full_name;

-- Q12: NOT EXISTS — products with zero completed sales
-- Business: Dead-stock alert for inventory management
SELECT dp.product_name, dp.category, dp.unit_price
FROM dim_product dp
WHERE NOT EXISTS (
    SELECT 1
    FROM fact_sales fs
    WHERE fs.product_id = dp.product_id
      AND fs.status = 'Completed'
);

-- Q13: NOT EXISTS — customers with only clean orders (no returns/issues)
-- Business: Reliable buyer badge for preferred customer program
SELECT dc.full_name, dc.segment
FROM dim_customer dc
WHERE EXISTS (
    SELECT 1 FROM fact_sales fs
    WHERE fs.customer_id = dc.customer_id
)
AND NOT EXISTS (
    SELECT 1 FROM fact_sales fs
    WHERE fs.customer_id = dc.customer_id
      AND fs.status IN ('Returned', 'Cancelled')
)
ORDER BY dc.full_name;

-- ════════════════════════════════════════════════════════════
-- SECTION 5: SUBQUERY IN FROM CLAUSE (Derived Table)
-- The inner SELECT acts as a temporary table.
-- Must give it an alias.
-- ════════════════════════════════════════════════════════════

-- Q14: FROM subquery — customers who spent above the average customer
-- Business: High-spender list for premium account management
SELECT
    dc.full_name,
    dc.segment,
    cust_totals.total_spent
FROM (
    -- Inner: calculate total spent per customer
    SELECT customer_id, ROUND(SUM(total_amount), 2) AS total_spent
    FROM fact_sales
    WHERE status = 'Completed'
    GROUP BY customer_id
) AS cust_totals
INNER JOIN dim_customer dc ON cust_totals.customer_id = dc.customer_id
WHERE cust_totals.total_spent > (
    -- Compare to average of all customers' totals
    SELECT AVG(total_spent)
    FROM (
        SELECT customer_id, SUM(total_amount) AS total_spent
        FROM fact_sales
        WHERE status = 'Completed'
        GROUP BY customer_id
    ) AS inner_avg
)
ORDER BY cust_totals.total_spent DESC;

-- Q15: FROM subquery — category summary as a derived table
-- Business: Clean category report with per-order average
SELECT
    cat.category,
    cat.total_revenue,
    cat.total_orders,
    ROUND(cat.total_revenue / cat.total_orders, 2) AS avg_per_order
FROM (
    SELECT
        dp.category,
        ROUND(SUM(fs.total_amount), 2) AS total_revenue,
        COUNT(fs.sale_id)              AS total_orders
    FROM fact_sales fs
    INNER JOIN dim_product dp ON fs.product_id = dp.product_id
    WHERE fs.status = 'Completed'
    GROUP BY dp.category
) AS cat
ORDER BY cat.total_revenue DESC;

-- ════════════════════════════════════════════════════════════
-- SECTION 6: JOIN vs SUBQUERY SIDE-BY-SIDE
-- (Interviewers LOVE asking: "When would you pick one over the other?")
-- ════════════════════════════════════════════════════════════

-- Q16A: Using JOIN — customers who made a completed purchase
SELECT DISTINCT dc.full_name, dc.segment
FROM fact_sales fs
INNER JOIN dim_customer dc ON fs.customer_id = dc.customer_id
WHERE fs.status = 'Completed';

-- Q16B: Same result using IN subquery
SELECT full_name, segment
FROM dim_customer
WHERE customer_id IN (
    SELECT DISTINCT customer_id
    FROM fact_sales
    WHERE status = 'Completed'
);

-- Interview Answer:
-- JOIN is generally faster — the DB optimizer handles it efficiently.
-- Subquery (IN/EXISTS) is cleaner when you only need data from one table
-- and just want to CHECK if a match exists in another.
-- Correlated subqueries are slowest (run N times) — use sparingly.
