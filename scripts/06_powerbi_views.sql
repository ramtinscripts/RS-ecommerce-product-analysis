/*
===============================================================================
Power BI Views | ویوهای پاور بی‌آی
===============================================================================
Purpose | هدف:
    - Prepare two simple views for Power BI Import Mode.
      آماده‌سازی دو View ساده برای Import Mode پاور بی‌آی.
    - Keep order-level and item-level data separate to prevent double counting.
      جداسازی داده‌های صرفا در سطحِ سفارش، و داده‌های در سطحِ قلم سفارش، برای جلوگیری از شمارش تکراری.

Model design | طراحی مدل:
    vw_powerbi_orders: one row per order | یک ردیف برای هر سفارش
    vw_powerbi_order_items: one row per order-product | یک ردیف برای هر محصول سفارش
===============================================================================
*/

-- =============================================================================
-- 1. Order-Level View | ویوی سطحِ سفارش
-- =============================================================================
-- Use this view for order counts, customer counts, AOV, and shipping fee.
-- از این View برای تعداد سفارش، مشتری، AOV و هزینه ارسال استفاده شود.
-- LEFT JOIN keeps every order: missing customer details remain NULL, and missing item totals become zero.
-- LEFT JOIN همه سفارش‌ها را حفظ می‌کند: اطلاعات مشتری ناموجود NULL و مجموع اقلام ناموجود صفر می‌شود.
CREATE OR ALTER VIEW dbo.vw_powerbi_orders
AS
SELECT
    o.order_id,
    o.customer_id,
    c.signup_date,
    c.state,
    c.acquisition_channel,
    o.order_date,
    YEAR(o.order_date) AS order_year,
    MONTH(o.order_date) AS order_month,
    o.status,
    o.payment_method,
    o.discount_code,
    o.shipping_fee,
    CASE
        WHEN o.discount_code IS NOT NULL OR SUM(i.discount_amount) > 0 THEN 1
        ELSE 0
    END AS has_discount,
    COUNT(i.product_id) AS item_line_count,
    COUNT(DISTINCT i.product_id) AS distinct_products,
    COALESCE(SUM(i.quantity), 0) AS total_units,
    COALESCE(SUM(i.discount_amount), 0) AS order_discount_amount,
    COALESCE(SUM(i.net_revenue), 0) AS order_net_revenue,
    COALESCE(SUM(i.estimated_gross_profit), 0)
        AS order_estimated_gross_profit,
    CASE
        WHEN o.status = 'completed' THEN COALESCE(SUM(i.net_revenue), 0)
        ELSE 0
    END AS completed_net_revenue,
    CASE
        WHEN o.status = 'completed'
            THEN COALESCE(SUM(i.estimated_gross_profit), 0)
        ELSE 0
    END AS completed_estimated_gross_profit,
    SUM(CASE WHEN i.is_price_imputed = 1 THEN 1 ELSE 0 END)
        AS imputed_item_count
FROM dbo.vw_orders_clean AS o
LEFT JOIN dbo.customers AS c
    ON c.customer_id = o.customer_id
LEFT JOIN dbo.vw_order_items_enriched AS i
    ON i.order_id = o.order_id
GROUP BY
    o.order_id,
    o.customer_id,
    c.signup_date,
    c.state,
    c.acquisition_channel,
    o.order_date,
    o.status,
    o.payment_method,
    o.discount_code,
    o.shipping_fee;
GO

-- =============================================================================
-- 2. Order-Item-Level View | ویوی سطحِ قلم سفارش
-- =============================================================================
-- Use this view for product, category, revenue, profit, and discount visuals.
-- از این View برای نمودارهای محصول، دسته، درآمد، سود و تخفیف استفاده شود.
-- Shipping fee is excluded because it belongs to the order and would repeat for every item.
-- هزینه ارسال در این View استفاده نمی‌شود، چون متعلق به کل سفارش است و برای هر قلم تکرار می‌شود.
CREATE OR ALTER VIEW dbo.vw_powerbi_order_items
AS
SELECT
    i.order_id,
    o.customer_id,
    c.signup_date,
    c.state,
    c.acquisition_channel,
    o.order_date,
    YEAR(o.order_date) AS order_year,
    MONTH(o.order_date) AS order_month,
    o.status,
    o.payment_method,
    o.discount_code,
    i.product_id,
    i.product_name,
    i.category_clean,
    i.quantity,
    i.valid_unit_price,
    i.product_average_unit_price,
    i.effective_unit_price,
    i.is_price_imputed,
    i.price_imputation_method,
    i.discount_amount,
    i.net_revenue,
    i.estimated_cost,
    i.estimated_gross_profit,
    CASE WHEN o.status = 'completed' THEN i.net_revenue ELSE 0 END
        AS completed_net_revenue,
    CASE WHEN o.status = 'completed' THEN i.estimated_gross_profit ELSE 0 END
        AS completed_estimated_gross_profit
FROM dbo.vw_order_items_enriched AS i
JOIN dbo.vw_orders_clean AS o
    ON o.order_id = i.order_id
JOIN dbo.customers AS c
    ON c.customer_id = o.customer_id;
GO
