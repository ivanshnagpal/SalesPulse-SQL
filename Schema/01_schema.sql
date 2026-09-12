-- ============================================================
-- PROJECT  : SalesPulse — Sales Analytics System
-- FILE     : 01_schema.sql
-- PURPOSE  : Database schema — all tables, constraints, relationships
-- CONCEPTS : DDL, PRIMARY KEY, FOREIGN KEY, UNIQUE, CHECK, DEFAULT,
--            Self-referencing FK, 1NF / 2NF / 3NF Normalization
-- AUTHOR   : Vansh Nagpal
-- DB       : MySQL 8.0+
-- ============================================================

-- ============================================================
-- NORMALIZATION NOTES  ← explain this in every interview
-- ============================================================
--
-- BEFORE normalization (flat table problem):
--   One giant table: sale_id | cust_name | cust_city | region |
--                    product_name | category | price | sp_name | total
--   Problems:
--   → cust_name repeats on every sale of that customer       (redundancy)
--   → Change customer email → update 100 rows                (update anomaly)
--   → Delete last sale → lose customer record                (delete anomaly)
--   → Can't add a product until someone buys it              (insert anomaly)
--
-- AFTER normalization — we split into clean separate tables:
--
-- 1NF  → Every column holds ONE atomic value. No comma-separated lists.
--         Example: phone is a single value, not "9876,9123"
--
-- 2NF  → No partial dependency. Every non-key column depends on the
--         FULL primary key, not just part of it.
--         Example: product_name depends on product_id alone →
--         move it to dim_product, not fact_sales
--
-- 3NF  → No transitive dependency. Non-key columns depend only on PK.
--         Example: region_name depends on region_id, not customer_id →
--         move to dim_region, reach via FK
--
-- FUNCTIONAL DEPENDENCIES in this schema:
--   region_id      → region_name, city, zone
--   product_id     → product_name, category, unit_price, cost_price
--   customer_id    → full_name, email, segment, region_id
--   salesperson_id → full_name, email, region_id, manager_id, target
--   sale_id        → customer_id, product_id, salesperson_id, date, total
-- ============================================================

CREATE DATABASE IF NOT EXISTS salesiq;
USE salesiq;

-- ── TABLE 1 : dim_region ────────────────────────────────────────
-- Stores region master. Separated so region_name never repeats
-- inside dim_customer (3NF compliance).
CREATE TABLE dim_region (
    region_id   INT          PRIMARY KEY AUTO_INCREMENT,
    region_name VARCHAR(60)  NOT NULL,
    city        VARCHAR(60)  NOT NULL,
    zone        VARCHAR(20)  NOT NULL,
    CONSTRAINT chk_zone CHECK (zone IN ('North','South','East','West'))
);

-- ── TABLE 2 : dim_product ───────────────────────────────────────
-- Product catalogue. Separated so product details never repeat
-- in fact_sales (2NF compliance).
CREATE TABLE dim_product (
    product_id   INT            PRIMARY KEY AUTO_INCREMENT,
    product_name VARCHAR(100)   NOT NULL,
    category     VARCHAR(50)    NOT NULL,
    unit_price   DECIMAL(10,2)  NOT NULL,
    cost_price   DECIMAL(10,2)  NOT NULL,
    is_available BOOLEAN        DEFAULT TRUE,
    CONSTRAINT chk_price CHECK (unit_price > 0 AND cost_price > 0)
);

-- ── TABLE 3 : dim_customer ──────────────────────────────────────
-- Customer master. region_id FK avoids storing region info here.
CREATE TABLE dim_customer (
    customer_id INT          PRIMARY KEY AUTO_INCREMENT,
    full_name   VARCHAR(100) NOT NULL,
    email       VARCHAR(120) NOT NULL UNIQUE,
    phone       VARCHAR(15),
    segment     VARCHAR(30)  NOT NULL  DEFAULT 'Retail',
    region_id   INT          NOT NULL,
    signup_date DATE         NOT NULL,
    is_active   BOOLEAN      DEFAULT TRUE,
    CONSTRAINT chk_segment  CHECK (segment IN ('Enterprise','SMB','Retail','Government')),
    CONSTRAINT fk_cust_region FOREIGN KEY (region_id)
        REFERENCES dim_region(region_id)
);

-- ── TABLE 4 : dim_salesperson ───────────────────────────────────
-- Self-referencing FK: manager_id → same table's salesperson_id.
-- This enables SELF JOIN queries to build the hierarchy report.
CREATE TABLE dim_salesperson (
    salesperson_id INT            PRIMARY KEY AUTO_INCREMENT,
    full_name      VARCHAR(100)   NOT NULL,
    email          VARCHAR(120)   NOT NULL UNIQUE,
    region_id      INT            NOT NULL,
    manager_id     INT            DEFAULT NULL,   -- NULL = VP / top level
    target_amount  DECIMAL(12,2)  DEFAULT 0.00,
    hire_date      DATE           NOT NULL,
    CONSTRAINT fk_sp_region  FOREIGN KEY (region_id)
        REFERENCES dim_region(region_id),
    CONSTRAINT fk_sp_manager FOREIGN KEY (manager_id)
        REFERENCES dim_salesperson(salesperson_id)
);

-- ── TABLE 5 : fact_sales  (CORE FACT TABLE) ─────────────────────
-- Every sales transaction. All dimension FKs originate here.
-- This is the central table for all JOIN queries.
CREATE TABLE fact_sales (
    sale_id        INT            PRIMARY KEY AUTO_INCREMENT,
    customer_id    INT            NOT NULL,
    product_id     INT            NOT NULL,
    salesperson_id INT            NOT NULL,
    sale_date      DATE           NOT NULL,
    quantity       INT            NOT NULL  DEFAULT 1,
    unit_price     DECIMAL(10,2)  NOT NULL,
    discount_pct   DECIMAL(5,2)   DEFAULT 0.00,
    total_amount   DECIMAL(12,2)  NOT NULL,
    payment_method VARCHAR(30)    NOT NULL,
    status         VARCHAR(20)    NOT NULL  DEFAULT 'Completed',
    CONSTRAINT fk_sale_cust FOREIGN KEY (customer_id)
        REFERENCES dim_customer(customer_id),
    CONSTRAINT fk_sale_prod FOREIGN KEY (product_id)
        REFERENCES dim_product(product_id),
    CONSTRAINT fk_sale_sp   FOREIGN KEY (salesperson_id)
        REFERENCES dim_salesperson(salesperson_id),
    CONSTRAINT chk_sale_status   CHECK (status IN ('Completed','Returned','Pending','Cancelled')),
    CONSTRAINT chk_sale_discount CHECK (discount_pct BETWEEN 0 AND 100),
    CONSTRAINT chk_sale_qty      CHECK (quantity > 0)
);

-- ── TABLE 6 : fact_returns ──────────────────────────────────────
-- Return and refund tracking. Linked to fact_sales via sale_id.
CREATE TABLE fact_returns (
    return_id     INT            PRIMARY KEY AUTO_INCREMENT,
    sale_id       INT            NOT NULL,
    return_date   DATE           NOT NULL,
    reason        VARCHAR(200),
    refund_amount DECIMAL(12,2)  NOT NULL,
    CONSTRAINT fk_return_sale FOREIGN KEY (sale_id)
        REFERENCES fact_sales(sale_id)
);

-- ── TABLE 7 : raw_sales_staging  (DIRTY DATA for cleaning demo) ─
-- Intentionally messy. Used to demonstrate data cleaning pipeline.
CREATE TABLE raw_sales_staging (
    row_id     INT,
    cust_name  VARCHAR(150),   -- mixed case, extra spaces
    prod_name  VARCHAR(150),
    sale_date  VARCHAR(30),    -- multiple date formats
    qty        VARCHAR(10),    -- stored as text, may say "one"
    price      VARCHAR(20),    -- may have '$', commas, spaces
    region     VARCHAR(80),
    pay_method VARCHAR(50),
    status     VARCHAR(50)     -- 'done', 'COMPLETED', 'complete'
);
