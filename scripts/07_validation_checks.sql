/*
===============================================================================
Final Validation Checks | کنترل‌های نهایی
===============================================================================
Purpose | هدف:
    - Prove that cleaning and Power BI views did not lose or duplicate data.
      اثبات اینکه تمیزسازی و Viewهای پاور بی‌آی داده را حذف یا تکراری نکرده‌اند.
    - Make the project auditable for a reviewer or HR interview.
      قابل‌بررسی‌کردن پروژه برای ارزیاب فنی یا مصاحبه HR.
===============================================================================
*/

-- =============================================================================
-- 1. Raw and Clean Row Counts | تعداد ردیف‌های خام و تمیز
-- =============================================================================
-- Expected from the source: 3600 customers, 9245 raw order rows,
-- 9207 unique orders, 15608 order items, and 90 products.
-- مقدار موردانتظار: ۳۶۰۰ مشتری، ۹۲۴۵ ردیف سفارش خام،
-- ۹۲۰۷ سفارش یکتا، ۱۵۶۰۸ قلم سفارش و ۹۰ محصول.
SELECT 'Raw customers' AS check_name, COUNT(*) AS result FROM dbo.customers
UNION ALL
SELECT 'Raw order rows', COUNT(*) FROM dbo.orders
UNION ALL
SELECT 'Clean unique orders', COUNT(*) FROM dbo.vw_orders_clean
UNION ALL
SELECT 'Raw order items', COUNT(*) FROM dbo.order_items
UNION ALL
SELECT 'Raw products', COUNT(*) FROM dbo.products;

-- =============================================================================
-- 2. Price Cleaning Checks | کنترل تمیزسازی قیمت
-- =============================================================================
-- Missing raw prices and imputed prices should both be 199;
-- تعداد قیمت‌های خالی خام و جایگزین‌شده باید هر دو ۱۹۹ باشد؛
-- unresolved prices should be 0.
-- تعداد قیمت‌های حل‌نشده باید صفر باشد.

SELECT
    (SELECT COUNT(*)
     FROM dbo.order_items
     WHERE unit_price IS NULL) AS missing_raw_prices,
    (SELECT COUNT(*)
     FROM dbo.vw_order_items_enriched
     WHERE is_price_imputed = 1) AS imputed_prices,
    (SELECT COUNT(*)
     FROM dbo.vw_order_items_enriched
     WHERE effective_unit_price IS NULL) AS unresolved_prices;

-- =============================================================================
-- 3. Business Rule Checks | بررسی قواعد کسب‌وکار
-- =============================================================================
-- Quantities, prices, and discounts must not be negative.
-- تعداد، قیمت و تخفیف نباید منفی باشد.
-- Discounts must not exceed the gross value of an order item.
-- تخفیف نباید از مبلغ ناخالص قلم سفارش بیشتر باشد.
-- All four results should be zero.
-- هر چهار نتیجه باید صفر باشد.
SELECT
    (SELECT COUNT(*)
     FROM dbo.order_items
     WHERE quantity < 0) AS negative_quantities,
    (SELECT COUNT(*)
     FROM dbo.order_items
     WHERE unit_price < 0) AS negative_prices,
    (SELECT COUNT(*)
     FROM dbo.order_items
     WHERE discount_amount < 0) AS negative_discounts,
    (SELECT COUNT(*)
     FROM dbo.order_items
     WHERE unit_price IS NOT NULL
       AND discount_amount > quantity * unit_price) AS discounts_above_gross
 
    -- =============================================================================
-- 4. Power BI Grain Check | کنترل سطح داده پاور بی‌آی
-- =============================================================================
-- Order and item views must preserve the row counts of their clean sources.
-- Viewهای سفارش و اقلام باید تعداد ردیف منابع تمیز خود را حفظ کنند.
SELECT
    (SELECT COUNT(*) FROM dbo.vw_orders_clean) AS clean_orders,
    (SELECT COUNT(*) FROM dbo.vw_powerbi_orders) AS powerbi_order_rows,
    (SELECT COUNT(DISTINCT order_id) FROM dbo.vw_powerbi_orders)
        AS powerbi_unique_orders,
    (SELECT COUNT(*) FROM dbo.vw_order_items_enriched) AS enriched_item_rows,
    (SELECT COUNT(*) FROM dbo.vw_powerbi_order_items) AS powerbi_item_rows;

-- =============================================================================
-- 5. Revenue and Profit Reconciliation | تطبیق درآمد و سود
-- =============================================================================
-- All three revenue values and all three profit values should match.
-- هر سه مقدار درآمد و هر سه مقدار سود باید برابر باشند.
SELECT
    'Direct Calculation' AS calculation_source,
    ROUND(SUM(i.net_revenue), 2) AS completed_net_revenue,
    ROUND(SUM(i.estimated_gross_profit), 2)
        AS completed_estimated_gross_profit
FROM dbo.vw_order_items_enriched AS i
JOIN dbo.vw_orders_clean AS o
    ON o.order_id = i.order_id
WHERE o.status = 'completed'
UNION ALL
SELECT
    'Order View',
    ROUND(SUM(completed_net_revenue), 2),
    ROUND(SUM(completed_estimated_gross_profit), 2)
FROM dbo.vw_powerbi_orders
UNION ALL
SELECT
    'Item View',
    ROUND(SUM(completed_net_revenue), 2),
    ROUND(SUM(completed_estimated_gross_profit), 2)
FROM dbo.vw_powerbi_order_items;

-- =============================================================================
-- 6. Shipping Fee Reconciliation | تطبیق هزینه ارسال
-- =============================================================================
-- Shipping fee is summed only from order-level views to avoid double counting.
-- هزینه ارسال فقط از Viewهای سطح سفارش جمع می‌شود تا چندبار شمرده نشود.
SELECT
    ROUND((SELECT SUM(shipping_fee) FROM dbo.vw_orders_clean), 2)
        AS clean_order_shipping_fee,
    ROUND((SELECT SUM(shipping_fee) FROM dbo.vw_powerbi_orders), 2)
        AS powerbi_order_shipping_fee;
