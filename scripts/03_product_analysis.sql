/*
===============================================================================
Product Performance Analysis | تحلیل عملکرد محصول
===============================================================================
Purpose | هدف:
    - Compare products and categories by revenue, profit, margin, and returns.
      مقایسه محصول‌ها و دسته‌ها براساس درآمد، سود، حاشیه سود و مرجوعی.
    - Find strong products and products that need investigation.
      شناسایی محصولات موفق و محصولات نیازمند بررسی.

Business note | نکته کسب‌وکاری:
    Only completed orders are included in revenue and profit.
    فقط سفارش‌های تکمیل‌شده در درآمد و سود محاسبه می‌شوند.
===============================================================================
*/

-- =============================================================================
-- 1. Product Performance | عملکرد محصول
-- =============================================================================
-- One row per product with commercial and operational indicators.
-- یک ردیف برای هر محصول همراه با شاخص‌های تجاری و عملیاتی.
SELECT
    i.product_id,
    i.product_name,
    i.category_clean,
    COUNT(DISTINCT CASE WHEN o.status = 'completed' THEN o.order_id END)
        AS completed_orders,
    COUNT(DISTINCT CASE WHEN o.status = 'returned' THEN o.order_id END)
        AS returned_orders,
    COUNT(DISTINCT CASE WHEN o.status = 'canceled' THEN o.order_id END)
        AS canceled_orders,
    COUNT(DISTINCT CASE WHEN o.status = 'completed' THEN o.customer_id END)
        AS customers,
    SUM(CASE WHEN o.status = 'completed' THEN i.quantity ELSE 0 END)
        AS units_sold,
    ROUND(SUM(CASE WHEN o.status = 'completed' THEN i.net_revenue ELSE 0 END), 2)
        AS completed_net_revenue,
    ROUND(SUM(CASE WHEN o.status = 'completed'
                   THEN i.estimated_gross_profit ELSE 0 END), 2)
        AS estimated_gross_profit,
    ROUND(
        100.0 * SUM(CASE WHEN o.status = 'completed'
                         THEN i.estimated_gross_profit ELSE 0 END)
        / NULLIF(SUM(CASE WHEN o.status = 'completed'
                          THEN i.net_revenue ELSE 0 END), 0), 2
    ) AS gross_margin_pct,
    ROUND(
        100.0 * COUNT(DISTINCT CASE WHEN o.status = 'returned' THEN o.order_id END)
        / NULLIF(
            COUNT(DISTINCT CASE WHEN o.status IN ('completed', 'returned')
                                THEN o.order_id END), 0
        ), 2
    ) AS return_rate_pct
FROM dbo.vw_order_items_enriched AS i
JOIN dbo.vw_orders_clean AS o
    ON o.order_id = i.order_id
GROUP BY
    i.product_id,
    i.product_name,
    i.category_clean
ORDER BY completed_net_revenue DESC;

-- =============================================================================
-- 2. Category Performance | عملکرد دسته‌بندی
-- =============================================================================
-- category_clean is used so Kitchen, kitchen, and KITCHEN are one category.
-- از category_clean استفاده می‌شود تا شکل‌های مختلف Kitchen یک دسته باشند.
SELECT
    i.category_clean,
    COUNT(DISTINCT CASE WHEN o.status = 'completed' THEN o.order_id END)
        AS completed_orders,
    COUNT(DISTINCT CASE WHEN o.status = 'completed' THEN o.customer_id END)
        AS customers,
    SUM(CASE WHEN o.status = 'completed' THEN i.quantity ELSE 0 END)
        AS units_sold,
    ROUND(SUM(CASE WHEN o.status = 'completed' THEN i.net_revenue ELSE 0 END), 2)
        AS completed_net_revenue,
    ROUND(SUM(CASE WHEN o.status = 'completed'
                   THEN i.estimated_gross_profit ELSE 0 END), 2)
        AS estimated_gross_profit,
    ROUND(
        100.0 * SUM(CASE WHEN o.status = 'completed'
                         THEN i.estimated_gross_profit ELSE 0 END)
        / NULLIF(SUM(CASE WHEN o.status = 'completed'
                          THEN i.net_revenue ELSE 0 END), 0), 2
    ) AS gross_margin_pct,
    ROUND(
        100.0 * COUNT(DISTINCT CASE WHEN o.status = 'returned' THEN o.order_id END)
        / NULLIF(
            COUNT(DISTINCT CASE WHEN o.status IN ('completed', 'returned')
                                THEN o.order_id END), 0
        ), 2
    ) AS return_rate_pct
FROM dbo.vw_order_items_enriched AS i
JOIN dbo.vw_orders_clean AS o
    ON o.order_id = i.order_id
GROUP BY i.category_clean
ORDER BY completed_net_revenue DESC;

-- =============================================================================
-- 3. Top and Bottom Products | محصولات برتر و ضعیف‌تر
-- =============================================================================
-- Highest-revenue products.
-- محصولات با بیشترین درآمد.
SELECT TOP 5
    i.product_name,
    ROUND(SUM(i.net_revenue), 2) AS completed_net_revenue
FROM dbo.vw_order_items_enriched AS i
JOIN dbo.vw_orders_clean AS o
    ON o.order_id = i.order_id
WHERE o.status = 'completed'
GROUP BY i.product_name
ORDER BY completed_net_revenue DESC;

-- Lowest-revenue products. Low revenue is a signal for review, not proof of failure.
-- کم‌درآمدترین محصولات؛ درآمد کم نشانه بررسی است، نه اثبات شکست محصول.
SELECT TOP 5
    i.product_name,
    ROUND(SUM(i.net_revenue), 2) AS completed_net_revenue
FROM dbo.vw_order_items_enriched AS i
JOIN dbo.vw_orders_clean AS o
    ON o.order_id = i.order_id
WHERE o.status = 'completed'
GROUP BY i.product_name
ORDER BY completed_net_revenue;

-- =============================================================================
-- 4. Revenue and Margin Comparison | مقایسه درآمد و حاشیه سود
-- =============================================================================
-- High revenue with a weak margin can indicate pricing or cost pressure.
-- درآمد بالا همراه با حاشیه سود ضعیف می‌تواند نشانه فشار قیمت یا هزینه باشد.
WITH product_metrics AS (
    SELECT
        i.product_id,
        i.product_name,
        SUM(i.net_revenue) AS completed_net_revenue,
        SUM(i.estimated_gross_profit) AS estimated_gross_profit
    FROM dbo.vw_order_items_enriched AS i
    JOIN dbo.vw_orders_clean AS o
        ON o.order_id = i.order_id
    WHERE o.status = 'completed'
    GROUP BY i.product_id, i.product_name
)
SELECT
    product_id,
    product_name,
    ROUND(completed_net_revenue, 2) AS completed_net_revenue,
    ROUND(estimated_gross_profit, 2) AS estimated_gross_profit,
    ROUND(
        100.0 * estimated_gross_profit / NULLIF(completed_net_revenue, 0), 2
    ) AS gross_margin_pct
FROM product_metrics
ORDER BY completed_net_revenue DESC, gross_margin_pct;

-- =============================================================================
-- 5. High-Return Products | محصولات با مرجوعی بالا
-- =============================================================================
-- The minimum of 20 eligible orders avoids ranking products with tiny samples.
-- حداقل ۲۰ سفارش، اثر نمونه‌های بسیار کوچک را کاهش می‌دهد.
SELECT
    i.product_id,
    i.product_name,
    COUNT(DISTINCT CASE WHEN o.status = 'returned' THEN o.order_id END)
        AS returned_orders,
    COUNT(DISTINCT CASE WHEN o.status IN ('completed', 'returned')
                        THEN o.order_id END) AS eligible_orders,
    ROUND(
        100.0 * COUNT(DISTINCT CASE WHEN o.status = 'returned' THEN o.order_id END)
        / NULLIF(
            COUNT(DISTINCT CASE WHEN o.status IN ('completed', 'returned')
                                THEN o.order_id END), 0
        ), 2
    ) AS return_rate_pct
FROM dbo.vw_order_items_enriched AS i
JOIN dbo.vw_orders_clean AS o
    ON o.order_id = i.order_id
GROUP BY i.product_id, i.product_name
HAVING COUNT(DISTINCT CASE WHEN o.status IN ('completed', 'returned')
                           THEN o.order_id END) >= 20
ORDER BY return_rate_pct DESC;

-- =============================================================================
-- 6. Category Contribution | سهم هر دسته از کل
-- =============================================================================
-- Part-to-whole analysis shows how much each category contributes.
-- تحلیل جزء به کل سهم هر دسته از درآمد و سود را نشان می‌دهد.
WITH category_totals AS (
    SELECT
        i.category_clean,
        SUM(i.net_revenue) AS completed_net_revenue,
        SUM(i.estimated_gross_profit) AS estimated_gross_profit
    FROM dbo.vw_order_items_enriched AS i
    JOIN dbo.vw_orders_clean AS o
        ON o.order_id = i.order_id
    WHERE o.status = 'completed'
    GROUP BY i.category_clean
)
SELECT
    category_clean,
    ROUND(completed_net_revenue, 2) AS completed_net_revenue,
    ROUND(
        100.0 * completed_net_revenue
        / NULLIF(SUM(completed_net_revenue) OVER (), 0), 2
    ) AS revenue_share_pct,
    ROUND(estimated_gross_profit, 2) AS estimated_gross_profit,
    ROUND(
        100.0 * estimated_gross_profit
        / NULLIF(SUM(estimated_gross_profit) OVER (), 0), 2
    ) AS profit_share_pct
FROM category_totals
ORDER BY completed_net_revenue DESC;

-- =============================================================================
-- 7. Product Segmentation | بخش‌بندی محصولات
-- =============================================================================
-- Thresholds are simple business rules and can be changed by the company.
-- آستانه‌ها قواعد ساده کسب‌وکاری‌اند و شرکت می‌تواند آن‌ها را تغییر دهد.
WITH product_revenue AS (
    SELECT
        i.product_id,
        i.product_name,
        SUM(i.net_revenue) AS completed_net_revenue
    FROM dbo.vw_order_items_enriched AS i
    JOIN dbo.vw_orders_clean AS o
        ON o.order_id = i.order_id
    WHERE o.status = 'completed'
    GROUP BY i.product_id, i.product_name
)
SELECT
    product_id,
    product_name,
    ROUND(completed_net_revenue, 2) AS completed_net_revenue,
    CASE
        WHEN completed_net_revenue >= 50000 THEN 'High Performer'
        WHEN completed_net_revenue >= 20000 THEN 'Mid Performer'
        ELSE 'Low Performer'
    END AS product_segment
FROM product_revenue
ORDER BY completed_net_revenue DESC;
