/*
===============================================================================
Exploration and KPI Overview | شناخت داده و شاخص‌های اصلی
===============================================================================
Purpose | هدف:
    - Explore the cleaned data before detailed analysis.
      شناخت داده تمیزشده پیش از تحلیل جزئی.
    - Calculate the main business KPIs with clear business definitions.
      محاسبه شاخص‌های اصلی کسب‌وکار با تعریف روشن.

Business note | نکته کسب‌وکاری:
    Revenue and profit include imputed prices, so they are estimates.
    درآمد و سود شامل قیمت‌های جایگزین‌شده‌اند و بنابراین تخمینی هستند.
===============================================================================
*/

-- =============================================================================
-- 1. Database Exploration | بررسی ساختار دیتابیس
-- =============================================================================
-- This confirms that the four imported tables and the three clean views exist.
-- این بخش وجود چهار جدول واردشده و سه View تمیز را بررسی می‌کند.
SELECT
    TABLE_SCHEMA,
    TABLE_NAME,
    TABLE_TYPE
FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_SCHEMA = 'dbo'
ORDER BY TABLE_TYPE, TABLE_NAME;

-- =============================================================================
-- 2. Dimension Exploration | بررسی مقادیر دسته‌ای
-- =============================================================================
-- Distinct values reveal unexpected spelling or formatting differences.
-- مقادیر یکتا ناسازگاری احتمالی در نوشتار یا قالب را نشان می‌دهند.
SELECT DISTINCT status
FROM dbo.vw_orders_clean
ORDER BY status;

SELECT DISTINCT payment_method
FROM dbo.vw_orders_clean
ORDER BY payment_method;

SELECT DISTINCT category_clean
FROM dbo.vw_products_clean
ORDER BY category_clean;

SELECT DISTINCT acquisition_channel
FROM dbo.customers
ORDER BY acquisition_channel;

SELECT DISTINCT state
FROM dbo.customers
ORDER BY state;

-- =============================================================================
-- 3. Date Range | بازه زمانی داده
-- =============================================================================
SELECT
    MIN(order_date) AS first_order_date,
    MAX(order_date) AS last_order_date,
    DATEDIFF(DAY, MIN(order_date), MAX(order_date)) AS order_range_days
FROM dbo.vw_orders_clean;

-- =============================================================================
-- 4. Order KPIs | شاخص‌های سفارش
-- =============================================================================
-- Each row in vw_orders_clean is one unique order, so COUNT(*) is safe here.
-- هر ردیف در این View یک سفارش یکتاست؛ پس COUNT(*) باعث شمارش تکراری نمی‌شود.
SELECT
    COUNT(*) AS unique_orders,
    COUNT(DISTINCT customer_id) AS customers_with_orders,
    SUM(CASE WHEN status = 'completed' THEN 1 ELSE 0 END) AS completed_orders,
    SUM(CASE WHEN status = 'returned' THEN 1 ELSE 0 END) AS returned_orders,
    SUM(CASE WHEN status = 'canceled' THEN 1 ELSE 0 END) AS canceled_orders,
    ROUND(
        100.0 * SUM(CASE WHEN status = 'completed' THEN 1 ELSE 0 END)
        / NULLIF(COUNT(*), 0), 2
    ) AS completed_rate_pct,
    ROUND(
        100.0 * SUM(CASE WHEN status = 'canceled' THEN 1 ELSE 0 END)
        / NULLIF(COUNT(*), 0), 2
    ) AS cancellation_rate_pct,
    ROUND(
        100.0 * SUM(CASE WHEN status = 'returned' THEN 1 ELSE 0 END)
        / NULLIF(
            SUM(CASE WHEN status IN ('completed', 'returned') THEN 1 ELSE 0 END),
            0
        ), 2
    ) AS return_rate_pct,
    ROUND(
        100.0 * SUM(CASE WHEN shipping_fee = 0 THEN 1 ELSE 0 END)
        / NULLIF(COUNT(*), 0), 2
    ) AS free_shipping_rate_pct
FROM dbo.vw_orders_clean;

-- =============================================================================
-- 5. Revenue and Profit KPIs | شاخص‌های درآمد و سود
-- =============================================================================
-- Only completed orders are treated as realized revenue.
-- فقط سفارش‌های تکمیل‌شده به‌عنوان درآمد محقق‌شده در نظر گرفته می‌شوند.
SELECT
    COUNT(DISTINCT o.customer_id) AS total_purchasing_customers,
    COUNT(DISTINCT i.product_id) AS total_distinct_products_sold,
    SUM(i.quantity) AS total_units_sold,
    ROUND(SUM(i.net_revenue), 2) AS total_completed_net_revenue,
    ROUND(SUM(i.estimated_gross_profit), 2)
        AS total_estimated_gross_profit,
    ROUND(
        100.0 * SUM(i.estimated_gross_profit)
        / NULLIF(SUM(i.net_revenue), 0),
        2
    ) AS gross_margin_pct,
    ROUND(
        SUM(i.net_revenue)
        / NULLIF(COUNT(DISTINCT o.order_id), 0),
        2
    ) AS average_order_value
FROM dbo.vw_orders_clean AS o
JOIN dbo.vw_order_items_enriched AS i
    ON i.order_id = o.order_id
WHERE o.status = 'completed';


-- =============================================================================
-- 6. Repeat Customer Rate | نرخ مشتری تکراری
-- =============================================================================
-- A repeat customer has at least two completed orders.
-- مشتری تکراری حداقل دو سفارش تکمیل‌شده دارد.
WITH customer_orders AS (
    SELECT
        customer_id,
        COUNT(*) AS completed_orders
    FROM dbo.vw_orders_clean
    WHERE status = 'completed'
    GROUP BY customer_id
)
SELECT
    COUNT(*) AS purchasing_customers,
    SUM(CASE WHEN completed_orders >= 2 THEN 1 ELSE 0 END) AS repeat_customers,
    ROUND(
        100.0 * SUM(CASE WHEN completed_orders >= 2 THEN 1 ELSE 0 END)
        / NULLIF(COUNT(*), 0), 2
    ) AS repeat_customer_rate_pct
FROM customer_orders;

-- =============================================================================
-- 7. Price Imputation Rate | نرخ جایگزینی قیمت خالی
-- =============================================================================
-- This makes the estimation transparent instead of hiding missing prices.
-- این شاخص میزان برآورد را شفاف می‌کند و قیمت‌های خالی را پنهان نمی‌کند.
SELECT
    COUNT(*) AS all_order_items,
    SUM(CASE WHEN is_price_imputed = 1 THEN 1 ELSE 0 END) AS imputed_items,
    ROUND(
        100.0 * SUM(CASE WHEN is_price_imputed = 1 THEN 1 ELSE 0 END)
        / NULLIF(COUNT(*), 0), 2
    ) AS price_imputation_rate_pct
FROM dbo.vw_order_items_enriched;

-- =============================================================================
-- 8. Status and Payment Distribution | توزیع وضعیت و روش پرداخت
-- =============================================================================
SELECT
    status,
    COUNT(*) AS order_count
FROM dbo.vw_orders_clean
GROUP BY status
ORDER BY order_count DESC;

SELECT
    payment_method,
    COUNT(*) AS order_count,
    COUNT(DISTINCT customer_id) AS customer_count
FROM dbo.vw_orders_clean
GROUP BY payment_method
ORDER BY order_count DESC;
