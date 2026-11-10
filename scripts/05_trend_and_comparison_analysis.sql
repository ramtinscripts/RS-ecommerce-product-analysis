/*
===============================================================================
Trend and Comparison Analysis | تحلیل روند و مقایسه
===============================================================================
Purpose | هدف:
    - Track orders, revenue, profit, returns, and cancellations over time.
      بررسی روند سفارش، درآمد، سود، مرجوعی و لغو در طول زمان.
    - Compare discount, shipping, and payment groups.
      مقایسه گروه‌های تخفیف، ارسال و روش پرداخت.

Business note | نکته کسب‌وکاری:
    Group comparisons are descriptive and do not prove causality.
    مقایسه گروه‌ها توصیفی است و رابطه علت و معلولی را ثابت نمی‌کند.
===============================================================================
*/

-- =============================================================================
-- 1. Monthly Performance | عملکرد ماهانه
-- =============================================================================
SELECT
    --DATETRUNC(month,o.order_date) as date,
    YEAR(o.order_date) AS order_year,
    MONTH(o.order_date) AS order_month,
    COUNT(DISTINCT o.order_id) AS all_orders,
    COUNT(DISTINCT CASE WHEN o.status = 'completed' THEN o.order_id END)
        AS completed_orders,
    COUNT(DISTINCT CASE WHEN o.status = 'returned' THEN o.order_id END)
        AS returned_orders,
    COUNT(DISTINCT CASE WHEN o.status = 'canceled' THEN o.order_id END)
        AS canceled_orders,
    ROUND(SUM(CASE WHEN o.status = 'completed' THEN i.net_revenue ELSE 0 END), 2)
        AS completed_net_revenue,
    ROUND(SUM(CASE WHEN o.status = 'completed'
                   THEN i.estimated_gross_profit ELSE 0 END), 2)
        AS estimated_gross_profit
FROM dbo.vw_orders_clean AS o
JOIN dbo.vw_order_items_enriched AS i
    ON i.order_id = o.order_id

--GROUP BY DATETRUNC(month,o.order_date)
--ORDER BY DATETRUNC(month,o.order_date);

GROUP BY YEAR(o.order_date), MONTH(o.order_date)
ORDER BY order_year, order_month;

-- =============================================================================
-- 2. Year-over-Year Performance | مقایسه سال‌به‌سال
-- =============================================================================
-- LAG brings the previous year's value beside the current year.
-- LAG مقدار سال قبل را کنار سال جاری قرار می‌دهد.
WITH yearly_performance AS (
    SELECT
        YEAR(o.order_date) AS order_year,
        COUNT(DISTINCT CASE WHEN o.status = 'completed' THEN o.order_id END)
            AS completed_orders,
        SUM(CASE WHEN o.status = 'completed' THEN i.net_revenue ELSE 0 END)
            AS completed_net_revenue,
        SUM(CASE WHEN o.status = 'completed'
                 THEN i.estimated_gross_profit ELSE 0 END)
            AS estimated_gross_profit
    FROM dbo.vw_orders_clean AS o
    JOIN dbo.vw_order_items_enriched AS i
        ON i.order_id = o.order_id
    GROUP BY YEAR(o.order_date)
),
yearly_comparison AS (
    SELECT
        order_year,
        completed_orders,
        completed_net_revenue,
        estimated_gross_profit,
        LAG(completed_orders) OVER (ORDER BY order_year) AS previous_orders,
        LAG(completed_net_revenue) OVER (ORDER BY order_year) AS previous_revenue,
        LAG(estimated_gross_profit) OVER (ORDER BY order_year) AS previous_profit
    FROM yearly_performance
)
SELECT
    order_year,
    completed_orders,
    ROUND(completed_net_revenue, 2) AS completed_net_revenue,
    ROUND(estimated_gross_profit, 2) AS estimated_gross_profit,
    ROUND(
        100.0 * (completed_orders - previous_orders)
        / NULLIF(previous_orders, 0), 2
    ) AS yoy_orders_pct,
    ROUND(
        100.0 * (completed_net_revenue - previous_revenue)
        / NULLIF(previous_revenue, 0), 2
    ) AS yoy_revenue_pct,
    ROUND(
        100.0 * (estimated_gross_profit - previous_profit)
        / NULLIF(previous_profit, 0), 2
    ) AS yoy_profit_pct
FROM yearly_comparison
ORDER BY order_year;

-- =============================================================================
-- 3. Cumulative Revenue and Profit | درآمد و سود تجمعی
-- =============================================================================
-- First aggregate by month, then calculate the running total.
-- ابتدا داده در سطح ماه خلاصه و سپس جمع تجمعی محاسبه می‌شود.
WITH monthly_financials AS (
    SELECT
        YEAR(o.order_date) AS order_year,
        MONTH(o.order_date) AS order_month,
        SUM(i.net_revenue) AS monthly_revenue,
        SUM(i.estimated_gross_profit) AS monthly_profit
    FROM dbo.vw_orders_clean AS o
    JOIN dbo.vw_order_items_enriched AS i
        ON i.order_id = o.order_id
    WHERE o.status = 'completed'
    GROUP BY YEAR(o.order_date), MONTH(o.order_date)
)
SELECT
    order_year,
    order_month,
    ROUND(monthly_revenue, 2) AS monthly_revenue,
    ROUND(
        SUM(monthly_revenue) OVER (ORDER BY order_year, order_month), 2
    ) AS cumulative_revenue,
    ROUND(monthly_profit, 2) AS monthly_profit,
    ROUND(
        SUM(monthly_profit) OVER (ORDER BY order_year, order_month), 2
    ) AS cumulative_profit
FROM monthly_financials
ORDER BY order_year, order_month;

-- =============================================================================
-- 4. Discount Comparison | مقایسه سفارش تخفیف‌دار و بدون تخفیف
-- =============================================================================
-- Revenue is first aggregated to one row per order to calculate AOV correctly.
-- ابتدا درآمد در سطح هر سفارش جمع می‌شود تا میانگین ارزش سفارش درست باشد.
WITH order_financials AS (
    SELECT
        o.order_id,
        o.customer_id,
        CASE
            WHEN o.discount_code IS NOT NULL OR SUM(i.discount_amount) > 0
                THEN 'Discounted'
            ELSE 'Non-Discounted'
        END AS discount_group,
        SUM(i.discount_amount) AS total_discount,
        SUM(i.net_revenue) AS order_revenue,
        SUM(i.estimated_gross_profit) AS order_profit
    FROM dbo.vw_orders_clean AS o
    JOIN dbo.vw_order_items_enriched AS i
        ON i.order_id = o.order_id
    WHERE o.status = 'completed'
    GROUP BY o.order_id, o.customer_id, o.discount_code
)
SELECT
    discount_group,
    COUNT(*) AS completed_orders,
    COUNT(DISTINCT customer_id) AS customers,
    ROUND(SUM(total_discount), 2) AS total_discount,
    ROUND(SUM(order_revenue), 2) AS completed_net_revenue,
    ROUND(SUM(order_profit), 2) AS estimated_gross_profit,
    ROUND(SUM(order_revenue) / NULLIF(COUNT(*), 0), 2) AS average_order_value,
    ROUND(
        100.0 * SUM(order_profit) / NULLIF(SUM(order_revenue), 0), 2
    ) AS gross_margin_pct
FROM order_financials
GROUP BY discount_group
ORDER BY completed_net_revenue DESC;

-- =============================================================================
-- 5. Free Shipping Comparison | مقایسه ارسال رایگان و غیررایگان
-- =============================================================================
-- shipping_fee is read at order grain and is never summed after the item join.
-- هزینه ارسال در سطح سفارش خوانده می‌شود و بعد از Join اقلام جمع نمی‌شود.
WITH order_financials AS (
    SELECT
        o.order_id,
        CASE WHEN o.shipping_fee = 0 THEN 'Free Shipping' ELSE 'Paid Shipping' END
            AS shipping_group,
        SUM(i.net_revenue) AS order_revenue
    FROM dbo.vw_orders_clean AS o
    JOIN dbo.vw_order_items_enriched AS i
        ON i.order_id = o.order_id
    WHERE o.status = 'completed'
    GROUP BY o.order_id, o.shipping_fee
)
SELECT
    shipping_group,
    COUNT(*) AS completed_orders,
    ROUND(SUM(order_revenue), 2) AS completed_net_revenue,
    ROUND(SUM(order_revenue) / NULLIF(COUNT(*), 0), 2) AS average_order_value
FROM order_financials
GROUP BY shipping_group
ORDER BY completed_net_revenue DESC;

-- =============================================================================
-- 6. Payment Method Performance | عملکرد روش پرداخت
-- =============================================================================
SELECT
    o.payment_method,
    COUNT(DISTINCT o.order_id) AS completed_orders,
    COUNT(DISTINCT o.customer_id) AS customers,
    ROUND(SUM(i.net_revenue), 2) AS completed_net_revenue,
    ROUND(SUM(i.estimated_gross_profit), 2) AS estimated_gross_profit,
    ROUND(
        SUM(i.net_revenue) / NULLIF(COUNT(DISTINCT o.order_id), 0), 2
    ) AS average_order_value
FROM dbo.vw_orders_clean AS o
JOIN dbo.vw_order_items_enriched AS i
    ON i.order_id = o.order_id
WHERE o.status = 'completed'
GROUP BY o.payment_method
ORDER BY completed_net_revenue DESC;
