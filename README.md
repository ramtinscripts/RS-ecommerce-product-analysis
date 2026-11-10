# E-commerce Product & Revenue Performance Analysis

**Language:** English | [فارسی](README.fa.md)

SQL Server 2022 and Power BI portfolio project focused on product performance,
revenue, estimated profitability, customer behavior, acquisition channels,
returns, cancellations, discounts, shipping groups, payment methods, and
monthly trends.

This is an e-commerce analytics project. It is not presented as logistics or
delivery analytics because the source data has no delivery date, SLA, courier,
route, distance, first-mile, or last-mile fields.

## Business Questions

- Which products and categories generate the most revenue and estimated profit?
- Which high-revenue products have weak margins?
- Which products and categories have high return rates?
- How are revenue, profit, and order volume changing over time?
- Which acquisition channels and states generate the strongest results?
- How do discounted and non-discounted orders compare?
- How do free-shipping and paid-shipping orders compare?
- Which payment methods generate the strongest order value and revenue?
- How many customers return for another completed purchase?

## Dataset

The project uses four CSV files imported into SQL Server with SSMS **Import Flat
File**:

| Table | Grain | Rows |
|---|---|---:|
| `dbo.customers` | One row per customer | 3,600 |
| `dbo.orders` | One raw row per order record | 9,245 |
| `dbo.order_items` | One row per product inside an order | 15,608 |
| `dbo.products` | One row per product | 90 |

The raw order table contains 9,207 unique orders covering January 1, 2024 to
December 31, 2025.

## Data Model and Grain

```text
customers (1) ──── (*) orders (1) ──── (*) order_items (*) ──── (1) products
```

- `vw_orders_clean`: one row per unique order
- `vw_products_clean`: one row per product with a standardized category
- `vw_order_items_enriched`: one row per order-product with pricing and profit
- `vw_powerbi_orders`: order-grain Power BI view
- `vw_powerbi_order_items`: order-item-grain Power BI view

Separating the two Power BI grains prevents order counts and shipping fees from
being repeated when an order contains several products.

## Data Quality Problems and Decisions

### 1. Duplicate Orders

The raw `orders` table contains 38 completely duplicated rows. A duplicate order
would duplicate all matching items after a join and overstate revenue and profit.
The project first checks that duplicate versions do not conflict, then removes
exact duplicates with `SELECT DISTINCT` inside `vw_orders_clean`. Raw data is not
deleted or overwritten.

### 2. Inconsistent Categories

The product table contains 24 raw category spellings, including differences in
case and surrounding spaces such as `Kitchen`, ` kitchen`, and `KITCHEN`. These
would split one business category across several dashboard rows. `TRIM`, `UPPER`,
and `LOWER` standardize them into 8 clean categories while preserving the raw
category for auditing.

### 3. Missing Unit Prices

There are 199 missing `unit_price` values, or 1.27% of order-item rows. Replacing
them with zero would understate revenue, while deleting them would lose real sold
units. The project therefore uses:

```text
effective_unit_price =
    original unit_price
    else average observed price of the same product
    else product list_price as the final fallback
```

Every replacement receives an `is_price_imputed` flag and a
`price_imputation_method`. All 199 missing values are resolved by the same-product
average; no list-price fallback is required in the current data. Revenue and
profit are labeled as estimated because they include imputed prices.

## KPI Definitions

| KPI | Definition |
|---|---|
| Completed Rate | Completed orders / all unique orders |
| Cancellation Rate | Canceled orders / all unique orders |
| Return Rate | Returned orders / completed plus returned orders |
| Completed Net Revenue | Completed-order `quantity × effective price − discount` |
| Estimated Gross Profit | Net revenue − `quantity × unit cost` |
| Gross Margin | Estimated gross profit / completed net revenue |
| Average Order Value | Completed net revenue / completed unique orders |
| Repeat Customer Rate | Customers with 2+ completed orders / customers with 1+ |
| Free Shipping Rate | Unique orders with zero shipping fee / all unique orders |
| Price Imputation Rate | Imputed item rows / all item rows |

Canceled and returned orders are excluded from completed revenue and profit.
Shipping fee is not treated as product revenue or shipping cost.

## Project Files

Run the scripts from `01` through `07` in order. There is no database-creation or
CSV-import SQL file because the CSV files are imported with SSMS **Import Flat
File** before the analysis begins.

1. `01_data_quality_and_cleaning.sql`
2. `02_exploration_and_kpis.sql`
3. `03_product_analysis.sql`
4. `04_customer_analysis.sql`
5. `05_trend_and_comparison_analysis.sql`
6. `06_powerbi_views.sql`
7. `07_validation_checks.sql`

The two-page Power BI report is stored in `Dashboard.pbix` and uses only the
two reporting views created by script `06`.

Select the imported database from the SSMS database dropdown before execution.

The SQL files intentionally use familiar analyst-level techniques: `SELECT`,
`JOIN`, `GROUP BY`, `CASE`, CTEs, aggregate functions, window functions, and
regular views. They avoid stored procedures, triggers, transactions, dynamic
SQL, physical staging layers, and unnecessary database-engineering code.

## Key Findings

1. The cleaned data contains **9,207 unique orders**: 8,456 completed, 407
   returned, and 344 canceled. The completed rate is **91.84%**, the cancellation
   rate is **3.74%**, and the defined return rate is **4.59%**.
2. Completed net revenue is **$1,881,905.60** and estimated gross profit is
   **$925,879.58**, producing a **49.20%** estimated gross margin and **$222.55**
   average order value.
3. In 2025, completed revenue increased **21.13%**, estimated gross profit
   increased **27.53%**, and completed orders increased **18.67%** versus 2024.
4. **Furniture** generated the most revenue at **$322,887.17**, but also had the
   highest category return rate at **12.09%**, making it a priority for product-
   level investigation.
5. **Storage** had the highest category margin at **55.60%**, while **Cotton Patio
   Chair** was the highest-revenue product at **$67,046.12**.
6. Discounted completed orders had a **$179.65** average order value and
   **40.83%** margin, compared with **$230.28** and **50.38%** for non-discounted
   orders. This is descriptive association, not proof that discounts caused the
   difference.
7. Of 2,047 customers with a completed order, 1,318 were repeat customers, for a
   **64.39%** repeat-customer rate. Organic search generated **$773,658.94**, or
   approximately **41.11%** of completed revenue.

## Power BI Setup

### Model Setup

1. Run scripts `01` through `07` in SQL Server.
2. In Power BI Desktop, choose **Get Data → SQL Server** and select **Import**
   mode.
3. Import `dbo.vw_powerbi_orders` and `dbo.vw_powerbi_order_items`.
4. Create a one-to-many relationship from
   `vw_powerbi_orders[order_id]` to `vw_powerbi_order_items[order_id]`.
5. Keep the relationship single-directional, filtering from orders to items.
6. Use `order_date`, `state`, and `acquisition_channel` from the order view as
   shared slicers on both pages. Keep `payment_method` on the executive page,
   and use product and category fields from the item view only on the product
   page.

These two views are the only Power BI data sources used in this project. Do not
import the raw tables, cleaning views, analysis queries, or validation results.

This separation is important: `vw_powerbi_orders` contains one row per order,
while `vw_powerbi_order_items` can contain several rows for the same order.
Order counts, customer counts, AOV, shipping fee, and overall cards must come
from the order view. Product and category visuals must use fields from the item
view.

With the single-direction relationship, product and category slicers do not
filter order-level cards backward. This is intentional; use the item-level
fields for product and category analysis.

The Date, State, and Acquisition Channel slicers are synchronized across both
pages. Product and Category slicers remain limited to the product page. A
selection made directly on a chart does not carry to another page; synchronized
slicers provide the intended cross-page filtering.

No additional calculated columns, Power BI tables, or DAX measures are required
for the initial report. Use the built-in `Count`, `Distinct count`, `Sum`, and
`Average` aggregations in each visual.

### Built-in Aggregations

| View | Field | Aggregation | Required filter | Use |
|---|---|---|---|---|
| Orders | `order_id` | Count | None | Total orders |
| Orders | `order_id` | Count | `status = completed` | Completed orders |
| Orders | `customer_id` | Distinct count | `status = completed` | Purchasing customers |
| Orders | `completed_net_revenue` | Sum | None | Completed net revenue |
| Orders | `completed_estimated_gross_profit` | Sum | None | Estimated gross profit |
| Orders | `order_net_revenue` | Average | `status = completed` | Average order value |
| Items | `order_id` | Distinct count | `status = completed` | Product-level completed orders |
| Items | `quantity` | Sum | `status = completed` | Units sold |
| Items | `completed_net_revenue` | Sum | None | Product/category revenue |
| Items | `completed_estimated_gross_profit` | Sum | None | Product/category profit |
| Items | `order_id` | Distinct count | `status = returned` | Returned orders by category |

Use the `order_date` date hierarchy from the order view and expand it through
the Month level for the monthly trend. `order_id` must use **Distinct count**
in item-level visuals because one order can appear on several item rows.

### Implemented Dashboard Pages

**Page 1 — Executive Overview**

- Cards: Total Orders, Completed Orders, Purchasing Customers, Completed Net
  Revenue, Estimated Gross Profit, and Average Order Value
- Line chart: Completed Net Revenue and Estimated Gross Profit by order year
  and month using the `order_date` hierarchy
- Column chart: order count by status
- Column chart: Completed Net Revenue by acquisition channel
- Donut chart: order count by `discount_code`
- Column chart: average `order_net_revenue` by payment method, filtered to
  completed orders
- Slicers from the order view: Date, State, Acquisition Channel, and Payment
  Method

**Page 2 — Product and Category Performance**

- Matrix: Product, Category, distinct completed orders, units sold, completed
  net revenue, and estimated gross profit
- Bar chart: Top 10 Products by Completed Net Revenue, ranked and sorted by
  revenue, with Estimated Gross Profit in the tooltip
- Bar chart: distinct returned orders by category, filtered to returned orders
- Clustered column chart: Completed Net Revenue and Estimated Gross Profit by
  category, sorted by Estimated Gross Profit
- Slicers: Category and Product, plus the synchronized Date, State, and
  Acquisition Channel slicers from the order view

Do not place raw row counts, duplicate checks, reconciliation outputs, or the
full price-imputation audit on the business dashboard. Those belong in the SQL
validation scripts. If desired, include only a small data-quality note stating
that 1.27% of item prices were imputed.

## Limitations

- No delivery, SLA, courier, route, distance, first-mile, or last-mile data
- Profit excludes overhead, fulfillment, tax, payment fees, and shipping cost
- 1.27% of item prices are imputed, so revenue and profit include estimates
- No return reason, refund amount, return date, or partial-return information
- Discount comparison is observational and does not establish causality
- Acquisition data has no marketing spend, so channel ROI cannot be calculated

## Data Source

[Data Career School — E-commerce Sales Analysis](https://www.datacareerschool.com/datalabs/ecommerce-sales-analysis)

The original CSV files are excluded from the project package and should not be
committed to the public repository.
