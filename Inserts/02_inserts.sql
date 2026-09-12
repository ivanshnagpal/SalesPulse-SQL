-- ============================================================
-- PROJECT  : SalesPulse — Sales Analytics System
-- FILE     : 02_inserts.sql
-- PURPOSE  : All data insertion — DML operations
-- CONCEPTS : INSERT (single, multi-row, bulk), INSERT...SELECT,
--            UPDATE, DELETE, ALTER TABLE, dirty data staging
-- ============================================================

-- ── INSERT: dim_region ──────────────────────────────────────────
-- Multi-row bulk INSERT: one statement, multiple rows — more efficient
-- than individual INSERTs (fewer round-trips to the DB server)
INSERT INTO dim_region (region_name, city, zone) VALUES
('Mumbai Metro',     'Mumbai',    'West'),
('Delhi NCR',        'Delhi',     'North'),
('Bangalore Tech',   'Bangalore', 'South'),
('Chennai Hub',      'Chennai',   'South'),
('Kolkata East',     'Kolkata',   'East'),
('Hyderabad Cyber',  'Hyderabad', 'South'),
('Pune IT Park',     'Pune',      'West'),
('Jaipur Pink City', 'Jaipur',    'North');

-- ── INSERT: dim_product ─────────────────────────────────────────
INSERT INTO dim_product (product_name, category, unit_price, cost_price, is_available) VALUES
('Laptop Pro X1',         'Electronics', 85000.00, 60000.00, TRUE),
('Wireless Mouse M200',   'Electronics',  1500.00,   800.00, TRUE),
('Office Chair Ergo Pro', 'Furniture',   12000.00,  7000.00, TRUE),
('Standing Desk Pro',     'Furniture',   25000.00, 15000.00, TRUE),
('CRM Software License',  'Software',    50000.00,  5000.00, TRUE),
('Cloud Storage 1TB',     'Software',     8000.00,  1000.00, TRUE),
('Monitor 27 inch 4K',    'Electronics', 28000.00, 18000.00, TRUE),
('Annual Support Plan',   'Services',    20000.00,  2000.00, TRUE),
('Mechanical Keyboard K1','Electronics',  3500.00,  2000.00, TRUE),
('UPS 2kVA Power Backup', 'Electronics',  9500.00,  6000.00, TRUE),
('Network Switch 24P',    'Electronics', 12500.00,  7800.00, TRUE),
('ERP Software Suite',    'Software',   120000.00, 15000.00, TRUE);

-- ── INSERT: dim_salesperson (managers first, then their reports) ─
-- manager_id = NULL means this person is at the top of hierarchy
INSERT INTO dim_salesperson (full_name, email, region_id, manager_id, target_amount, hire_date) VALUES
('Rahul Mishra',   'rahul.m@salesiq.com',   1, NULL, 5000000.00, '2019-04-01'),  -- VP Sales
('Sunita Rao',     'sunita.r@salesiq.com',  1,    1, 2500000.00, '2020-06-15'),  -- reports to Rahul
('Deepak Nair',    'deepak.n@salesiq.com',  2,    1, 2000000.00, '2020-09-01'),
('Priti Shah',     'priti.s@salesiq.com',   3,    1, 2200000.00, '2021-01-10'),
('Arun Kumar',     'arun.k@salesiq.com',    4,    1, 1800000.00, '2021-03-20'),
('Neha Jain',      'neha.j@salesiq.com',    2,    3, 1500000.00, '2022-02-01'),  -- reports to Deepak
('Varun Tiwari',   'varun.t@salesiq.com',   3,    4, 1200000.00, '2022-05-15'),  -- reports to Priti
('Ankita Bhatt',   'ankita.b@salesiq.com',  1,    2, 1000000.00, '2023-01-10'),  -- reports to Sunita
('Rohit Sinha',    'rohit.s@salesiq.com',   5,    1, 1600000.00, '2021-08-01'),
('Manisha Dubey',  'manisha.d@salesiq.com', 7,    2,  900000.00, '2022-11-01');

-- ── INSERT: dim_customer ────────────────────────────────────────
INSERT INTO dim_customer (full_name, email, phone, segment, region_id, signup_date, is_active) VALUES
('Arjun Sharma',    'arjun.sharma@tata.com',       '9876543210', 'Enterprise', 1, '2021-03-15', TRUE),
('Priya Patel',     'priya.patel@infosys.com',     '9823456780', 'Enterprise', 3, '2021-06-20', TRUE),
('Rohan Mehta',     'rohan.m@startup.io',          '9912345678', 'SMB',        7, '2022-01-10', TRUE),
('Sneha Reddy',     'sneha.reddy@wipro.com',       '9700123456', 'Enterprise', 6, '2020-11-05', TRUE),
('Vikram Singh',    'vikram.singh@gmail.com',      '9988776655', 'Retail',     2, '2022-04-01', TRUE),
('Ananya Krishnan', 'ananya.k@hcl.com',            '9345678901', 'Enterprise', 4, '2021-09-12', TRUE),
('Karan Gupta',     'karan.g@amazon.in',           '9213456789', 'Enterprise', 2, '2020-07-22', TRUE),
('Meera Iyer',      'meera.iyer@zoho.com',         '9654321098', 'SMB',        4, '2022-08-30', TRUE),
('Siddharth Joshi', 'sid.joshi@freelancer.com',    '9777654321', 'SMB',        7, '2023-01-15', TRUE),
('Kavya Nair',      'kavya.nair@flipkart.com',     '9123456780', 'Enterprise', 3, '2021-12-01', TRUE),
('Rajesh Kumar',    'rajesh.k@gov.in',             '9800012345', 'Government', 2, '2020-03-01', TRUE),
('Deepika Singh',   'deepika.s@retail.com',        '9456789012', 'Retail',     1, '2022-11-20', TRUE),
('Amit Verma',      'amit.v@tech.com',             '9321654987', 'SMB',        8, '2023-03-10', FALSE),
('Pooja Sharma',    'pooja.sharma@edu.org',        '9867543210', 'Government', 2, '2021-07-08', TRUE),
('Nikhil Agarwal',  'nikhil.a@mnc.com',            '9234567891', 'Enterprise', 1, '2022-05-17', TRUE);

-- ── INSERT: fact_sales ──────────────────────────────────────────
INSERT INTO fact_sales (customer_id, product_id, salesperson_id, sale_date, quantity, unit_price, discount_pct, total_amount, payment_method, status) VALUES
( 1,  1, 2, '2024-01-15', 2, 85000.00,  5.00, 161500.00, 'Bank Transfer', 'Completed'),
( 2,  5, 4, '2024-01-15', 1, 50000.00,  0.00,  50000.00, 'Bank Transfer', 'Completed'),
( 3,  2, 10,'2024-02-01', 5,  1500.00,  0.00,   7500.00, 'Credit Card',   'Completed'),
( 4,  7, 5, '2024-02-01', 2, 28000.00,  3.00,  54320.00, 'Bank Transfer', 'Completed'),
( 5,  3, 3, '2024-02-15', 4, 12000.00,  0.00,  48000.00, 'Cash',          'Completed'),
( 6,  6, 4, '2024-02-15', 3,  8000.00, 10.00,  21600.00, 'Credit Card',   'Completed'),
( 7, 12, 3, '2024-03-01', 1,120000.00,  8.00, 110400.00, 'Bank Transfer', 'Completed'),
( 8,  9, 10,'2024-03-01', 6,  3500.00,  0.00,  21000.00, 'Credit Card',   'Completed'),
( 9,  4, 10,'2024-03-15', 2, 25000.00,  5.00,  47500.00, 'UPI',           'Completed'),
(10,  1, 4, '2024-03-15', 2, 85000.00,  5.00, 161500.00, 'Bank Transfer', 'Completed'),
( 1,  8, 2, '2024-04-01', 3, 20000.00,  0.00,  60000.00, 'Bank Transfer', 'Completed'),
(11,  2, 3, '2024-04-01', 3,  1500.00,  0.00,   4500.00, 'UPI',           'Completed'),
( 4,  7, 5, '2024-04-15', 1, 28000.00,  0.00,  28000.00, 'Bank Transfer', 'Completed'),
( 2,  1, 4, '2024-05-01', 3, 85000.00, 10.00, 229500.00, 'Bank Transfer', 'Completed'),
( 3,  3, 10,'2024-05-01', 2, 12000.00,  5.00,  22800.00, 'Credit Card',   'Completed'),
(12,  2, 2, '2024-05-15', 5,  1500.00,  0.00,   7500.00, 'UPI',           'Completed'),
( 5,  9, 6, '2024-06-01', 3,  3500.00,  0.00,  10500.00, 'Cash',          'Completed'),
( 6,  6, 4, '2024-06-01', 6,  8000.00, 10.00,  43200.00, 'Credit Card',   'Completed'),
(10,  5, 4, '2024-06-15', 1, 50000.00,  0.00,  50000.00, 'Bank Transfer', 'Completed'),
( 1,  7, 2, '2024-07-01', 3, 28000.00,  0.00,  84000.00, 'Bank Transfer', 'Completed'),
( 7,  1, 3, '2024-07-15', 2, 85000.00,  5.00, 161500.00, 'Bank Transfer', 'Completed'),
( 9,  6, 10,'2024-07-15', 5,  8000.00,  0.00,  40000.00, 'Credit Card',   'Completed'),
( 4,  1, 5, '2024-08-01', 4, 85000.00,  7.00, 316200.00, 'Bank Transfer', 'Completed'),
( 8,  8, 10,'2024-08-15', 1, 20000.00,  0.00,  20000.00, 'Bank Transfer', 'Completed'),
( 2,  5, 4, '2024-09-01', 1, 50000.00, 12.00,  44000.00, 'Bank Transfer', 'Completed'),
(12,  4, 2, '2024-09-15', 1, 25000.00,  0.00,  25000.00, 'Credit Card',   'Pending'),
( 7,  8, 3, '2024-10-01', 2, 20000.00,  0.00,  40000.00, 'Bank Transfer', 'Completed'),
( 3,  7, 10,'2024-10-01', 1, 28000.00,  5.00,  26600.00, 'Credit Card',   'Completed'),
(10,  1, 4, '2024-11-01', 2, 85000.00,  5.00, 161500.00, 'Bank Transfer', 'Completed'),
( 6,  5, 4, '2024-11-15', 1, 50000.00,  0.00,  50000.00, 'Bank Transfer', 'Completed'),
( 1,  7, 2, '2024-12-01', 3, 28000.00,  0.00,  84000.00, 'Bank Transfer', 'Completed'),
( 4,  8, 5, '2024-12-15', 3, 20000.00,  5.00,  57000.00, 'Bank Transfer', 'Completed'),
( 2,  1, 4, '2024-12-15', 3, 85000.00,  8.00, 234600.00, 'Bank Transfer', 'Completed'),
(13,  2, 7, '2024-12-31', 5,  1500.00, 10.00,   6750.00, 'UPI',           'Returned'),
(14, 11, 6, '2024-11-20', 2, 12500.00,  0.00,  25000.00, 'Bank Transfer', 'Completed'),
(15,  1, 2, '2024-10-10', 1, 85000.00,  5.00,  80750.00, 'Bank Transfer', 'Completed');

-- ── INSERT: fact_returns ────────────────────────────────────────
INSERT INTO fact_returns (sale_id, return_date, reason, refund_amount) VALUES
(34, '2025-01-05', 'Product not as described',     6750.00),
( 3, '2024-02-05', 'Wrong item delivered',          7500.00);

-- ── INSERT: raw_sales_staging (intentionally dirty) ─────────────
-- Dirty data patterns: mixed case, extra spaces, bad date formats,
-- non-numeric qty, currency symbols, inconsistent statuses
INSERT INTO raw_sales_staging VALUES
(1,  '  arjun sharma ',  'laptop pro x1',      '15-01-2024', '2',   ' 85000',  'Mumbai',    'Bank Transfer', 'completed'),
(2,  'Priya Patel',      'CRM Software',        '2024/01/15', 'one', '50000',   'Bangalore', 'Bank Transfer', 'COMPLETED'),
(3,  'ROHAN MEHTA',      'wireless mouse m200', '01/02/2024', '5',   '$1500',   'Pune',      'Credit Card',   'done'),
(4,  'Sneha Reddy',      'Monitor 27 4K',       '2024-02-01', '2',   '28000 ',  'Hyderabad', 'Bank Transfer', 'Completed'),
(5,  'vikram singh',     'Office Chair',        'Feb 15 2024','4',   '12000',   'Delhi',     'Cash',          'complete'),
(6,  '',                 'Cloud Storage',       '2024-03-01', '3',   '8,000',   'Delhi',     'Credit Card',   'completed'),
(7,  'Meera Iyer',       'Keyboard K1',         '2024-03-01', '6',   'N/A',     'Chennai',   'Credit Card',   'completed'),
(8,  'Kavya Nair',       'Laptop Pro X1',       '2024-03-15', '2',   '85000',   'Bangalore', 'Bank Transfer', 'Completed');

-- ============================================================
-- DML: UPDATE EXAMPLES  (commented — run individually to test)
-- ============================================================

-- Deactivate a customer who hasn't ordered in 1 year
-- UPDATE dim_customer SET is_active = FALSE WHERE customer_id = 13;

-- Apply 5% discount to all Pending orders
-- UPDATE fact_sales SET discount_pct = 5.00 WHERE status = 'Pending';

-- Increase price of Electronics products by 10%
-- UPDATE dim_product SET unit_price = unit_price * 1.10 WHERE category = 'Electronics';

-- Mark a returned sale properly
-- UPDATE fact_sales SET status = 'Returned' WHERE sale_id = 34;

-- ============================================================
-- DML: DELETE EXAMPLES  (commented — run individually to test)
-- ============================================================

-- Remove all cancelled orders
-- DELETE FROM fact_sales WHERE status = 'Cancelled';

-- Delete a specific return record
-- DELETE FROM fact_returns WHERE return_id = 2;

-- ============================================================
-- DDL: ALTER TABLE EXAMPLES
-- ============================================================

-- Add a loyalty_points column to dim_customer
-- ALTER TABLE dim_customer ADD COLUMN loyalty_points INT DEFAULT 0;

-- Modify unit_price precision
-- ALTER TABLE dim_product MODIFY COLUMN unit_price DECIMAL(12,2);

-- Rename a column (MySQL 8.0+)
-- ALTER TABLE dim_product RENAME COLUMN cost_price TO purchase_price;

-- Drop a column
-- ALTER TABLE dim_customer DROP COLUMN loyalty_points;
