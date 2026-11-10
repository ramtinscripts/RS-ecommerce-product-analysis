/*
===============================================================================
Data Quality and Cleaning | بررسی کیفیت و تمیزسازی داده
===============================================================================
Purpose | هدف:
    - Check the three known data-quality problems.
      بررسی سه مشکل شناخته‌شده کیفیت داده.
    - Create simple clean views without changing the raw tables.
      ساخت Viewهای تمیز بدون تغییر جدول‌های خام.
===============================================================================
*/

-- =============================================================================
-- 1. Raw Row Counts | تعداد ردیف‌های خام
-- =============================================================================
SELECT 'customers' AS table_name, COUNT(*) AS row_count FROM dbo.customers
UNION ALL
SELECT 'orders', COUNT(*) FROM dbo.orders
UNION ALL
SELECT 'order_items', COUNT(*) FROM dbo.order_items
UNION ALL
SELECT 'products', COUNT(*) FROM dbo.products;

-- =============================================================================
-- 2. Duplicate Orders | سفارش‌های تکراری
-- =============================================================================
/*
Problem | مشکل:
    The raw orders table contains 38 completely duplicated rows.
    جدول خام سفارش‌ها ۳۸ ردیف کاملاً تکراری دارد.

Business risk | ریسک کسب‌وکاری:
    If a duplicated order is joined to order_items, its items, revenue, and
    profit are repeated. COUNT(DISTINCT order_id) alone does not fix revenue.
    اگر سفارش تکراری به اقلام سفارش Join شود، اقلام، درآمد و سود آن تکرار
    می‌شوند. COUNT(DISTINCT order_id) به‌تنهایی Revenue را اصلاح نمی‌کند.

Fix | راه‌حل:
    First confirm that the duplicates are identical. Then use SELECT DISTINCT
    in vw_orders_clean before any analytical join. Raw data stays unchanged.
    ابتدا یکسان‌بودن نسخه‌های تکراری بررسی می‌شود. سپس پیش از هر Join تحلیلی،
    با SELECT DISTINCT در vw_orders_clean حذف می‌شوند و داده خام حفظ می‌شود.
*/
-- Show completely duplicated order rows.
-- نمایش ردیف‌های کاملاً تکراری سفارش.
SELECT
    order_id,
    customer_id,
    order_date,
    status,
    payment_method,
    discount_code,
    shipping_fee,
    COUNT(*) AS duplicate_count
FROM dbo.orders
GROUP BY
    order_id,
    customer_id,
    order_date,
    status,
    payment_method,
    discount_code,
    shipping_fee
HAVING COUNT(*) > 1
ORDER BY order_id;

-- Show order IDs that have more than one different version.
-- نمایش شناسه‌هایی که بیش از یک نسخه متفاوت دارند.
WITH order_versions AS (
    SELECT
        order_id,
        customer_id,
        order_date,
        status,
        payment_method,
        discount_code,
        shipping_fee
    FROM dbo.orders
    GROUP BY
        order_id,
        customer_id,
        order_date,
        status,
        payment_method,
        discount_code,
        shipping_fee
)
SELECT
    order_id,
    COUNT(*) AS different_versions
FROM order_versions
GROUP BY order_id
HAVING COUNT(*) > 1
ORDER BY order_id;

-- =============================================================================
-- 3. Missing Prices | قیمت‌های خالی
-- =============================================================================
/*
Problem | مشکل:
    199 order-item rows have no unit_price.
    در ۱۹۹ ردیف قلم سفارش، unit_price خالی است.

Business risk | ریسک کسب‌وکاری:
    Replacing them with zero understates revenue; deleting them loses sold
    units and orders; using list_price directly may ignore actual sale prices.
    صفرکردن قیمت، درآمد را کمتر نشان می‌دهد؛ حذف ردیف، فروش واقعی را از بین
    می‌برد؛ و استفاده مستقیم از list_price ممکن است قیمت واقعی فروش را نادیده بگیرد.

Fix | راه‌حل:
    Use the average observed unit_price of the same product. list_price is only
    the final fallback. Every replaced price is flagged for transparency.
    میانگین قیمت واقعی همان محصول استفاده می‌شود. list_price فقط جایگزین نهایی
    است و هر قیمت جایگزین‌شده برای شفافیت علامت‌گذاری می‌شود.
*/
SELECT
    COUNT(*) AS missing_unit_prices
FROM dbo.order_items
WHERE unit_price IS NULL;

-- =============================================================================
-- 4. Category Variants | شکل‌های مختلف دسته‌بندی
-- =============================================================================
/*
Problem | مشکل:
    Values such as Kitchen, kitchen, KITCHEN, and values with extra spaces
    represent the same category but appear as different groups.
    مقادیری مانند Kitchen، kitchen و KITCHEN یا مقادیر دارای فاصله اضافه،
    یک دسته‌اند اما در تحلیل به‌صورت گروه‌های جدا دیده می‌شوند.

Business risk | ریسک کسب‌وکاری:
    Revenue and profit for one category are split across several dashboard rows.
    درآمد و سود یک دسته در چند ردیف یا نمودار داشبورد تقسیم می‌شود.

Fix | راه‌حل:
    TRIM removes extra spaces and the letter functions create one consistent
    category_clean value. category_raw is retained for auditability.
    TRIM فاصله‌های اضافه را حذف می‌کند و توابع حروف یک category_clean یکسان
    می‌سازند. category_raw برای امکان بررسی حفظ می‌شود.
*/
SELECT
    category,
    COUNT(*) AS product_count
FROM dbo.products
GROUP BY category
ORDER BY TRIM(category), category;



SELECT    
    category COLLATE Latin1_General_100_CS_AI AS category_variant,
    DATALENGTH(category) AS stored_bytes,
    COUNT(*) AS product_count
FROM dbo.products
GROUP BY
    category COLLATE Latin1_General_100_CS_AI,
    DATALENGTH(category)
ORDER BY category_variant, stored_bytes;


-- =============================================================================
-- 5. Clean Orders View | ویوی تمیز سفارش‌ها
-- =============================================================================
-- DISTINCT removes the 38 completely duplicated rows before any join.
-- DISTINCT سی‌وهشت ردیف کاملاً تکراری را پیش از هر Join حذف می‌کند.
GO

CREATE OR ALTER VIEW dbo.vw_orders_clean
AS
SELECT DISTINCT
    order_id,
    customer_id,
    order_date,
    LOWER(TRIM(status)) AS status,
    LOWER(TRIM(payment_method)) AS payment_method,
    NULLIF(UPPER(TRIM(discount_code)), '') AS discount_code,
    shipping_fee
FROM dbo.orders;
GO

-- =============================================================================
-- 6. Clean Products View | ویوی تمیز محصولات
-- =============================================================================
CREATE OR ALTER VIEW dbo.vw_products_clean
AS
SELECT
    product_id,
    TRIM(product_name) AS product_name,
    category AS category_raw,
    CONCAT(
        UPPER(LEFT(TRIM(category), 1)),
        LOWER(SUBSTRING(TRIM(category), 2, 100))
    ) AS category_clean,
    list_price,
    unit_cost
FROM dbo.products;
GO

-- =============================================================================
-- 7. Enriched Order Items View | ویوی تکمیل‌شده اقلام سفارش
-- =============================================================================
-- Missing price: product average first, then list price as the final fallback.
-- قیمت خالی: ابتدا میانگین همان محصول و سپس قیمت لیست به‌عنوان جایگزین نهایی.
CREATE OR ALTER VIEW dbo.vw_order_items_enriched
AS
WITH product_average_prices AS (
    SELECT
        product_id,
        AVG(unit_price) AS product_average_unit_price
    FROM dbo.order_items
    WHERE unit_price IS NOT NULL
    GROUP BY product_id
)
SELECT
    oi.order_id,
    oi.product_id,
    p.product_name,
    p.category_raw,
    p.category_clean,
    oi.quantity,
    oi.unit_price AS valid_unit_price,
    a.product_average_unit_price,
    COALESCE(oi.unit_price, a.product_average_unit_price, p.list_price)
        AS effective_unit_price,
    CASE WHEN oi.unit_price IS NULL THEN 1 ELSE 0 END AS is_price_imputed,
    CASE
        WHEN oi.unit_price IS NOT NULL THEN 'original'
        WHEN a.product_average_unit_price IS NOT NULL THEN 'product_average'
        ELSE 'list_price_fallback'
    END AS price_imputation_method,
    p.list_price,
    p.unit_cost,
    oi.discount_amount,
    oi.quantity * COALESCE(oi.unit_price, a.product_average_unit_price, p.list_price)
        - oi.discount_amount AS net_revenue,
    oi.quantity * p.unit_cost AS estimated_cost,
    oi.quantity * COALESCE(oi.unit_price, a.product_average_unit_price, p.list_price)
        - oi.discount_amount
        - oi.quantity * p.unit_cost AS estimated_gross_profit
FROM dbo.order_items AS oi
LEFT JOIN product_average_prices AS a
    ON a.product_id = oi.product_id
LEFT JOIN dbo.vw_products_clean AS p
    ON p.product_id = oi.product_id;
GO

-- =============================================================================
-- 8. Cleaning Results | نتیجه تمیزسازی
-- =============================================================================
SELECT
    COUNT(*) AS clean_order_rows,
    COUNT(DISTINCT order_id) AS unique_orders
FROM dbo.vw_orders_clean;

SELECT
    category_clean,
    COUNT(*) AS product_count
FROM dbo.vw_products_clean
GROUP BY category_clean
ORDER BY category_clean;

SELECT
    price_imputation_method,
    COUNT(*) AS order_item_count
FROM dbo.vw_order_items_enriched
GROUP BY price_imputation_method
ORDER BY order_item_count DESC;
