-- ============================================================
-- PROJECT  : SalesPulse — Sales Analytics System
-- FILE     : 03_dql_basics.sql
-- PURPOSE  : DQL — Data Query Language fundamentals
-- CONCEPTS : SELECT, WHERE, ORDER BY, DISTINCT, LIMIT, BETWEEN,
--            IN, LIKE, IS NULL, AND/OR/NOT, Aliases, CASE WHEN,
--            COALESCE, NULLIF, GROUP BY, HAVING, Aggregates
-- ============================================================

-- ════════════════════════════════════════════════════════════
-- SECTION 1: BASIC SELECT & RETRIEVAL
-- ════════════════════════════════════════════════════════════

-- Q1: View all products with clear column aliases
-- Business: Product catalogue listing for the sales team
SELECT
    product_id                 AS "ID",
    product_name               AS "Product",
    category                   AS "Category",
    unit_price                 AS "Price (₹)",
    cost_price                 AS "Cost (₹)",
    ROUND(unit_price - cost_price, 2) AS "Margin (₹)"
FROM dim_product
ORDER BY unit_price DESC;

-- Q2: DISTINCT — what unique segments do our customers belong to?
-- Business: Quick overview of market segments we serve
SELECT DISTINCT segment FROM dim_customer ORDER BY segment;

-- Q3: DISTINCT + multiple columns — unique segment-region combos
-- Business: Find which segment operates in which zone
SELECT DISTINCT
    dc.segment,
    dr.zone
FROM dim_customer dc
INNER JOIN dim_region dr ON dc.region_id = dr.region_id
ORDER BY dc.segment, dr.zone;

-- Q4: LIMIT — top 5 most expensive products
-- Business: Premium product listing for enterprise sales pitch
SELECT product_name, category, unit_price
FROM dim_product
ORDER BY unit_price DESC
LIMIT 5;

-- Q5: All active customers sorted by signup date
-- Business: Newest customers list for onboarding follow-up
SELECT full_name, email, segment, signup_date
FROM dim_customer
WHERE is_active = TRUE
ORDER BY signup_date DESC;

-- ════════════════════════════════════════════════════════════
-- SECTION 2: WHERE CLAUSE — FILTERING
-- ════════════════════════════════════════════════════════════

-- Q6: WHERE with single condition — Enterprise customers only
-- Business: Target list for enterprise account managers
SELECT full_name, email, phone, signup_date
FROM dim_customer
WHERE segment = 'Enterprise';

-- Q7: WHERE with comparison — products priced above ₹10,000
-- Business: Mid-range and premium product filter
SELECT product_name, category, unit_price
FROM dim_product
WHERE unit_price > 10000
ORDER BY unit_price ASC;

-- Q8: BETWEEN — sales with total amount in ₹20K–₹2L range
-- Business: Medium deal size filter for performance review
SELECT sale_id, customer_id, total_amount, sale_date, status
FROM fact_sales
WHERE total_amount BETWEEN 20000 AND 200000
ORDER BY total_amount DESC;

-- Q9: IN — customers in Enterprise or Government segments
-- Business: B2B priority segment report
SELECT full_name, email, segment
FROM dim_customer
WHERE segment IN ('Enterprise', 'Government')
ORDER BY segment, full_name;

-- Q10: NOT IN — all sales except Cancelled and Returned
-- Business: Valid revenue transactions only
SELECT sale_id, customer_id, total_amount, sale_date
FROM fact_sales
WHERE status NOT IN ('Cancelled', 'Returned')
ORDER BY sale_date DESC;

-- Q11: LIKE — customers with Gmail addresses
-- Business: Find personal email users (individual/retail segment)
SELECT full_name, email, segment
FROM dim_customer
WHERE email LIKE '%@gmail.com';

-- Q12: LIKE — products whose name starts with "Laptop"
-- Business: All laptop variants in catalogue
SELECT product_name, unit_price
FROM dim_product
WHERE product_name LIKE 'Laptop%';

-- Q13: IS NULL — salespersons with no manager (top-level)
-- Business: Identify team leads / VP-level staff
SELECT full_name, email, hire_date
FROM dim_salesperson
WHERE manager_id IS NULL;

-- Q14: IS NOT NULL — everyone who has a manager assigned
-- Business: Full list of reportee-level sales staff
SELECT full_name, manager_id, hire_date
FROM dim_salesperson
WHERE manager_id IS NOT NULL
ORDER BY manager_id;

-- Q15: AND — completed sales above ₹50K in Q1 2024
-- Business: High-value deals closed in first quarter
SELECT sale_id, customer_id, total_amount, sale_date
FROM fact_sales
WHERE total_amount > 50000
  AND status = 'Completed'
  AND sale_date BETWEEN '2024-01-01' AND '2024-03-31'
ORDER BY total_amount DESC;

-- Q16: OR — sales paid by Cash OR UPI
-- Business: Non-digital payment method report
SELECT sale_id, total_amount, payment_method, sale_date
FROM fact_sales
WHERE payment_method = 'Cash'
   OR payment_method = 'UPI'
ORDER BY sale_date;

-- Q17: NOT — exclude inactive customers
-- Business: Clean active-customer list for campaigns
SELECT full_name, email, segment
FROM dim_customer
WHERE NOT is_active = FALSE
ORDER BY full_name;

-- Q18: Complex multi-condition — high-value Software sales
-- Business: Software revenue above ₹40K from specific channels
SELECT fs.sale_id, dp.product_name, fs.total_amount, fs.payment_method
FROM fact_sales fs
INNER JOIN dim_product dp ON fs.product_id = dp.product_id
WHERE dp.category = 'Software'
  AND fs.total_amount > 40000
  AND fs.status = 'Completed'
  AND fs.payment_method != 'Cash'
ORDER BY fs.total_amount DESC;

-- ════════════════════════════════════════════════════════════
-- SECTION 3: AGGREGATION — COUNT, SUM, AVG, MAX, MIN
-- ════════════════════════════════════════════════════════════

-- Q19: Overall revenue summary — key business KPIs
-- Business: Executive dashboard numbers
SELECT
    COUNT(sale_id)                AS total_transactions,
    COUNT(DISTINCT customer_id)   AS unique_customers,
    ROUND(SUM(total_amount), 2)   AS total_revenue,
    ROUND(AVG(total_amount), 2)   AS avg_order_value,
    MAX(total_amount)             AS largest_deal,
    MIN(total_amount)             AS smallest_deal
FROM fact_sales
WHERE status = 'Completed';

-- Q20: Revenue and order count by payment method
-- Business: Which payment channel drives the most revenue?
SELECT
    payment_method,
    COUNT(sale_id)              AS order_count,
    ROUND(SUM(total_amount), 2) AS total_revenue,
    ROUND(AVG(total_amount), 2) AS avg_order_value
FROM fact_sales
WHERE status = 'Completed'
GROUP BY payment_method
ORDER BY total_revenue DESC;

-- Q21: Monthly revenue trend for 2024
-- Business: Revenue pattern — identify peak and slow months
SELECT
    YEAR(sale_date)              AS yr,
    MONTH(sale_date)             AS mo,
    MONTHNAME(sale_date)         AS month_name,
    COUNT(sale_id)               AS orders,
    ROUND(SUM(total_amount), 2)  AS monthly_revenue
FROM fact_sales
WHERE status = 'Completed'
  AND YEAR(sale_date) = 2024
GROUP BY YEAR(sale_date), MONTH(sale_date), MONTHNAME(sale_date)
ORDER BY mo;

-- Q22: Revenue by product category
-- Business: Which category drives the most revenue?
SELECT
    dp.category,
    COUNT(fs.sale_id)              AS times_sold,
    SUM(fs.quantity)               AS units_sold,
    ROUND(SUM(fs.total_amount), 2) AS total_revenue,
    ROUND(AVG(fs.total_amount), 2) AS avg_sale_value
FROM fact_sales fs
INNER JOIN dim_product dp ON fs.product_id = dp.product_id
WHERE fs.status = 'Completed'
GROUP BY dp.category
ORDER BY total_revenue DESC;

-- Q23: HAVING — only categories with revenue above ₹1 lakh
-- Business: Focus categories that are actually contributing
SELECT
    dp.category,
    ROUND(SUM(fs.total_amount), 2) AS total_revenue
FROM fact_sales fs
INNER JOIN dim_product dp ON fs.product_id = dp.product_id
WHERE fs.status = 'Completed'
GROUP BY dp.category
HAVING SUM(fs.total_amount) > 100000
ORDER BY total_revenue DESC;

-- Q24: HAVING — salespersons who closed more than 3 orders
-- Business: Identify most active deal closers
SELECT
    salesperson_id,
    COUNT(sale_id)               AS deals_closed,
    ROUND(SUM(total_amount), 2)  AS revenue_generated
FROM fact_sales
WHERE status = 'Completed'
GROUP BY salesperson_id
HAVING COUNT(sale_id) > 3
ORDER BY revenue_generated DESC;

-- Q25: Discount impact analysis — avg discount per category
-- Business: Are heavy discounts hurting margin in any category?
SELECT
    dp.category,
    ROUND(AVG(fs.discount_pct), 2)  AS avg_discount_pct,
    ROUND(SUM(fs.total_amount), 2)  AS net_revenue
FROM fact_sales fs
INNER JOIN dim_product dp ON fs.product_id = dp.product_id
WHERE fs.status = 'Completed'
GROUP BY dp.category
ORDER BY avg_discount_pct DESC;

-- ════════════════════════════════════════════════════════════
-- SECTION 4: CASE WHEN + NULL HANDLING
-- ════════════════════════════════════════════════════════════

-- Q26: CASE WHEN — classify products into price tiers
-- Business: Quick product tier overview for pricing strategy
SELECT
    product_name,
    unit_price,
    CASE
        WHEN unit_price >= 50000  THEN 'Premium'
        WHEN unit_price >= 10000  THEN 'Mid-Range'
        ELSE                           'Budget'
    END AS price_tier
FROM dim_product
ORDER BY unit_price DESC;

-- Q27: CASE WHEN — classify customers by revenue tier
-- Business: Segment customers for loyalty program design
SELECT
    dc.full_name,
    dc.segment,
    ROUND(SUM(fs.total_amount), 2) AS lifetime_value,
    CASE
        WHEN SUM(fs.total_amount) >= 500000 THEN 'Platinum'
        WHEN SUM(fs.total_amount) >= 200000 THEN 'Gold'
        WHEN SUM(fs.total_amount) >= 50000  THEN 'Silver'
        ELSE                                     'Bronze'
    END AS customer_tier
FROM fact_sales fs
INNER JOIN dim_customer dc ON fs.customer_id = dc.customer_id
WHERE fs.status = 'Completed'
GROUP BY dc.full_name, dc.segment
ORDER BY lifetime_value DESC;

-- Q28: CASE WHEN — salesperson performance vs target
-- Business: Quick status flag for monthly performance review
SELECT
    dsp.full_name,
    dsp.target_amount,
    ROUND(SUM(fs.total_amount), 2) AS achieved,
    CASE
        WHEN SUM(fs.total_amount) >= dsp.target_amount         THEN 'Target Hit'
        WHEN SUM(fs.total_amount) >= dsp.target_amount * 0.75  THEN 'On Track'
        WHEN SUM(fs.total_amount) >= dsp.target_amount * 0.50  THEN 'Needs Push'
        ELSE                                                         'Underperforming'
    END AS performance_status
FROM dim_salesperson dsp
LEFT JOIN fact_sales fs ON dsp.salesperson_id = fs.salesperson_id
                       AND fs.status = 'Completed'
GROUP BY dsp.salesperson_id, dsp.full_name, dsp.target_amount
ORDER BY achieved DESC;

-- Q29: COALESCE — handle NULLs gracefully in output
-- Business: Show manager label even for top-level staff
SELECT
    full_name,
    COALESCE(CAST(manager_id AS CHAR), 'No Manager — Top Level') AS manager_info,
    target_amount
FROM dim_salesperson;

-- Q30: NULLIF — safe profit margin (avoid divide by zero)
-- Business: Calculate margin % without crashing on zero-price items
SELECT
    product_name,
    unit_price,
    cost_price,
    ROUND(
        (unit_price - cost_price) / NULLIF(unit_price, 0) * 100, 2
    ) AS margin_pct
FROM dim_product
ORDER BY margin_pct DESC;

-- Q31: IFNULL — show phone or a fallback label
-- Business: Customer contact list with missing phone handling
SELECT
    full_name,
    IFNULL(phone, 'Phone not registered') AS contact_number,
    segment
FROM dim_customer
ORDER BY full_name;
