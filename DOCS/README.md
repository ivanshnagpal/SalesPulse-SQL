# 📊 SalesPulse — Sales Analytics System

> A production-grade SQL portfolio project demonstrating real-world sales analytics using complex JOINs, subqueries, normalization, views, stored procedures, and window functions — built entirely in MySQL.

---

## 🏢 Business Scenario

**SalesPulse** is the analytics backbone for a B2B/B2C sales company operating across 8 Indian cities. It tracks every customer purchase, product sold, salesperson's performance, and return request — answering questions that real sales managers care about daily.

**Who uses it:** Sales Managers, Revenue Operations, Business Analysts, C-suite executives

**Problem it solves:** Fragmented sales data across channels → unified intelligence in one SQL system

### Key Metrics Tracked

| Metric                                      | SQL Technique Used      |
| ------------------------------------------- | ----------------------- |
| Revenue by region/zone                      | INNER JOIN + GROUP BY   |
| Customer lifetime value                     | LEFT JOIN + aggregation |
| Salesperson vs target                       | JOIN + CASE WHEN        |
| Product profitability                       | JOIN + computed margin  |
| Return rate per product                     | LEFT JOIN + NULL count  |
| Month-over-month growth                     | LAG window function     |
| Customer tier (Platinum/Gold/Silver/Bronze) | CTE + CASE WHEN         |

---

## 🗃️ Database Design

### Schema Type: Star Schema — 3NF Normalised

```
                    ┌─────────────────┐
                    │   dim_region    │
                    └────────┬────────┘
                             │ FK
              ┌──────────────▼──────────────┐
              │        dim_customer         │
              └──────────────┬──────────────┘
                             │ FK
┌─────────────┐    ┌─────────▼──────────┐    ┌──────────────────┐
│ dim_product ├────►    fact_sales      ◄────┤ dim_salesperson  │
└─────────────┘    └─────────┬──────────┘    └──────────────────┘
                             │ FK                      │ self-FK (manager_id)
                    ┌────────▼────────┐               ▼
                    │  fact_returns   │    dim_salesperson (hierarchy)
                    └─────────────────┘
```

### Tables

| Table               | Type      | Rows | Purpose                           |
| ------------------- | --------- | ---- | --------------------------------- |
| `dim_region`        | Dimension | 8    | Region/zone master                |
| `dim_product`       | Dimension | 12   | Product catalogue with costs      |
| `dim_customer`      | Dimension | 15   | Customer master with segments     |
| `dim_salesperson`   | Dimension | 10   | Sales team with manager hierarchy |
| `fact_sales`        | Fact      | 36   | Every sales transaction           |
| `fact_returns`      | Fact      | 2    | Return and refund records         |
| `raw_sales_staging` | Staging   | 8    | Dirty data for cleaning demo      |

---

## 📁 Project Structure

```
SalesPulse/
├── schema/
│   └── 01_schema.sql              ← DDL + normalization notes
├── inserts/
│   └── 02_inserts.sql             ← Bulk INSERT, DML examples, dirty data
├── queries/
│   ├── dql/
│   │   └── 03_dql_basics.sql      ← SELECT, WHERE, GROUP BY, HAVING, CASE, NULL (31 queries)
│   ├── joins/
│   │   └── 04_joins.sql           ← INNER, LEFT, RIGHT, SELF JOIN (15 queries)
│   ├── subqueries/
│   │   └── 05_subqueries.sql      ← Scalar, IN, Correlated, EXISTS, FROM clause (16 queries)
│   ├── advanced/
│   │   └── 06_advanced.sql        ← Views, Stored Procedures, Window Functions, CTEs
│   └── analysis/
│       └── 07_analysis.sql        ← Normalization proof, data cleaning, validation, Top-N
└── docs/
    └── README.md
```

---

## ✅ SQL Concepts Covered

| Concept                                        | File              | Query Numbers |
| ---------------------------------------------- | ----------------- | ------------- |
| DDL (CREATE TABLE, constraints)                | 01_schema.sql     | All           |
| DML (INSERT bulk, UPDATE, DELETE, ALTER)       | 02_inserts.sql    | All           |
| SELECT, aliases, DISTINCT, LIMIT               | 03_dql_basics.sql | Q1–Q5         |
| WHERE (BETWEEN, IN, LIKE, IS NULL, AND/OR/NOT) | 03_dql_basics.sql | Q6–Q18        |
| Aggregation (COUNT, SUM, AVG, MAX, MIN)        | 03_dql_basics.sql | Q19–Q25       |
| CASE WHEN, COALESCE, NULLIF, IFNULL            | 03_dql_basics.sql | Q26–Q31       |
| INNER JOIN (3–4 tables)                        | 04_joins.sql      | Q1–Q7         |
| LEFT JOIN + NULL detection                     | 04_joins.sql      | Q8–Q11        |
| RIGHT JOIN                                     | 04_joins.sql      | Q12           |
| SELF JOIN (hierarchy)                          | 04_joins.sql      | Q13–Q15       |
| Scalar subquery (SELECT + WHERE)               | 05_subqueries.sql | Q1–Q3         |
| IN / NOT IN subquery                           | 05_subqueries.sql | Q4–Q8         |
| Correlated subquery                            | 05_subqueries.sql | Q9–Q10        |
| EXISTS / NOT EXISTS                            | 05_subqueries.sql | Q11–Q13       |
| FROM-clause subquery                           | 05_subqueries.sql | Q14–Q15       |
| JOIN vs Subquery comparison                    | 05_subqueries.sql | Q16           |
| Views (CREATE + query)                         | 06_advanced.sql   | V1–V3         |
| Stored Procedures (with params)                | 06_advanced.sql   | SP1–SP4       |
| Window Functions (RANK, LAG, ROW_NUMBER)       | 06_advanced.sql   | W1–W4         |
| CTEs (WITH clause)                             | 06_advanced.sql   | CTE1–CTE2     |
| Normalization proof queries                    | 07_analysis.sql   | NORM1–NORM5   |
| Data cleaning pipeline                         | 07_analysis.sql   | CLEAN1–CLEAN5 |
| Data validation (UNION ALL)                    | 07_analysis.sql   | VAL1–VAL6     |

---

## ⚙️ Setup Instructions

```sql
-- Step 1: Run schema (creates database and all tables)
SOURCE schema/01_schema.sql;

-- Step 2: Load data
SOURCE inserts/02_inserts.sql;

-- Step 3: Run queries in any order
SOURCE queries/dql/03_dql_basics.sql;
SOURCE queries/joins/04_joins.sql;
SOURCE queries/subqueries/05_subqueries.sql;
SOURCE queries/advanced/06_advanced.sql;
SOURCE queries/analysis/07_analysis.sql;
```

**Compatible with:** MySQL 8.0+

---

## 💡 5 Interview Talking Points

1. **"I designed the schema in 3NF."** — product_name lives in dim_product because it depends on product_id alone (2NF), and region_name lives in dim_region because it depends on region_id not customer_id (3NF). No data redundancy.

2. **"I used SELF JOIN for the salesperson hierarchy."** — dim_salesperson has a manager_id that points back to its own salesperson_id. Joining the table to itself as 'emp' and 'mgr' lets me display each person with their manager's name in one query.

3. **"LEFT JOIN with IS NULL is my go-to for finding missing data."** — All customers with no purchases: LEFT JOIN fact_sales, then WHERE sale_id IS NULL. The NULL after LEFT JOIN means no matching row was found.

4. **"A correlated subquery runs once per outer row."** — In Q9, for each sale row in the outer query, the inner query computes the MAX for that specific customer using the outer row's customer_id. That linkage is the correlation.

5. **"A View is a saved SELECT that runs fresh every time."** — vw_sales_report joins 4 tables. After creating it, anyone can query it with simple SELECT statements. No data is stored — it's just the query definition saved.

---

_SalesPulse — Sales Analytics System | MySQL Implementation & Adaptation by Vansh Nagpal | [GitHub](https://github.com/ivanshnagpal) | [LinkedIn](https://www.linkedin.com/in/vansh-nagpal-vn011/)_
