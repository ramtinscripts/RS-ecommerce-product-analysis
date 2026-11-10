/*
===============================================================================
Customer Performance Analysis | تحلیل عملکرد مشتری
===============================================================================
Purpose | هدف:
    - Measure customer value, repeat behavior, and recency.
      سنجش ارزش مشتری، خرید تکراری و تازگی خرید.
    - Compare acquisition channels and states.
      مقایسه کانال‌های جذب و ایالت‌ها.

Business note | نکته کسب‌وکاری:
    Acquisition results show revenue performance, not marketing ROI,
    because campaign cost is not available.
    نتایج کانال جذب عملکرد درآمدی را نشان می‌دهد، نه بازگشت سرمایه تبلیغات؛
    زیرا هزینه بازاریابی در دیتاست وجود ندارد.
===============================================================================
*/

-- =============================================================================
-- 1. Customer-Level Metrics | شاخص‌های سطح مشتری
-- =============================================================================
-- The dataset end date is used for recency instead of today's date.
-- برای Recency از آخرین تاریخ دیتاست استفاده می‌شود، نه تاریخ امروز.
WITH customer_metrics AS (
    SELECT
        c.customer_id,
        c.signup_date,
        c.state,
        c.acquisition_channel,
        (SELECT MAX(order_date) FROM dbo.vw_orders_clean)
            AS last_dataset_date,
        COUNT(DISTINCT CASE WHEN o.status = 'completed' THEN o.order_id END)
            AS completed_orders,
        MAX(CASE WHEN o.status = 'completed' THEN o.order_date END)
            AS last_completed_order,
        SUM(CASE WHEN o.status = 'completed' THEN i.quantity ELSE 0 END)
            AS units_purchased,
        SUM(CASE WHEN o.status = 'completed' THEN i.net_revenue ELSE 0 END)
            AS completed_net_revenue,
        SUM(CASE WHEN o.status = 'completed'
                 THEN i.estimated_gross_profit ELSE 0 END)
            AS estimated_gross_profit
    FROM dbo.customers AS c
    LEFT JOIN dbo.vw_orders_clean AS o
        ON o.customer_id = c.customer_id
    LEFT JOIN dbo.vw_order_items_enriched AS i
        ON i.order_id = o.order_id
    GROUP BY
        c.customer_id,
        c.signup_date,
        c.state,
        c.acquisition_channel
)
SELECT
    m.customer_id,
    m.signup_date,
    m.state,
    m.acquisition_channel,
    m.completed_orders,
    m.units_purchased,
    ROUND(m.completed_net_revenue, 2) AS completed_net_revenue,
    ROUND(m.estimated_gross_profit, 2) AS estimated_gross_profit,
    m.last_completed_order,
    DATEDIFF(
        DAY, m.last_completed_order, m.last_dataset_date
    ) AS recency_days,
    ROUND(
        m.completed_net_revenue / NULLIF(m.completed_orders, 0), 2
    ) AS average_order_value
FROM customer_metrics AS m
ORDER BY completed_net_revenue DESC;

-- =============================================================================
-- 2. Repeat Customer Analysis | تحلیل مشتری تکراری
-- =============================================================================
-- Customers with no completed purchase are excluded from the repeat rate.
-- مشتریان بدون خرید تکمیل‌شده در مخرج نرخ تکرار قرار نمی‌گیرند.
WITH customer_orders AS (
    SELECT
        customer_id,
        COUNT(*) AS completed_orders
    FROM dbo.vw_orders_clean
    WHERE status = 'completed'
    GROUP BY customer_id
)
SELECT
    CASE
        WHEN completed_orders = 1 THEN 'One-time Customer'
        ELSE 'Repeat Customer'
    END AS customer_type,
    COUNT(*) AS customer_count,
    ROUND(
        100.0 * COUNT(*) / NULLIF(SUM(COUNT(*)) OVER (), 0), 2
    ) AS customer_share_pct
FROM customer_orders
GROUP BY
    CASE
        WHEN completed_orders = 1 THEN 'One-time Customer'
        ELSE 'Repeat Customer'
    END
ORDER BY customer_count DESC;

-- =============================================================================
-- 3. Acquisition Channel Performance | عملکرد کانال جذب
-- =============================================================================
SELECT
    c.acquisition_channel,
    COUNT(DISTINCT CASE WHEN o.status = 'completed' THEN c.customer_id END)
        AS purchasing_customers,
    COUNT(DISTINCT CASE WHEN o.status = 'completed' THEN o.order_id END)
        AS completed_orders,
    ROUND(SUM(CASE WHEN o.status = 'completed' THEN i.net_revenue ELSE 0 END), 2)
        AS completed_net_revenue,
    ROUND(SUM(CASE WHEN o.status = 'completed'
                   THEN i.estimated_gross_profit ELSE 0 END), 2)
        AS estimated_gross_profit,
    ROUND(
        SUM(CASE WHEN o.status = 'completed' THEN i.net_revenue ELSE 0 END)
        / NULLIF(
            COUNT(DISTINCT CASE WHEN o.status = 'completed' THEN o.order_id END),
            0
        ), 2
    ) AS average_order_value
FROM dbo.customers AS c
LEFT JOIN dbo.vw_orders_clean AS o
    ON o.customer_id = c.customer_id
LEFT JOIN dbo.vw_order_items_enriched AS i
    ON i.order_id = o.order_id
GROUP BY c.acquisition_channel
ORDER BY completed_net_revenue DESC;

-- =============================================================================
-- 4. State Performance | عملکرد ایالت
-- =============================================================================
SELECT
    c.state,
    COUNT(DISTINCT CASE WHEN o.status = 'completed' THEN c.customer_id END)
        AS purchasing_customers,
    COUNT(DISTINCT CASE WHEN o.status = 'completed' THEN o.order_id END)
        AS completed_orders,
    ROUND(SUM(CASE WHEN o.status = 'completed' THEN i.net_revenue ELSE 0 END), 2)
        AS completed_net_revenue,
    ROUND(SUM(CASE WHEN o.status = 'completed'
                   THEN i.estimated_gross_profit ELSE 0 END), 2)
        AS estimated_gross_profit
FROM dbo.customers AS c
LEFT JOIN dbo.vw_orders_clean AS o
    ON o.customer_id = c.customer_id
LEFT JOIN dbo.vw_order_items_enriched AS i
    ON i.order_id = o.order_id
GROUP BY c.state
ORDER BY completed_net_revenue DESC;

-- =============================================================================
-- 5. Customer Segmentation | بخش‌بندی مشتریان
-- =============================================================================
-- A simple rule-based segmentation makes the result easy to explain to HR.
-- بخش‌بندی قاعده‌محور ساده، نتیجه را برای HR قابل‌فهم نگه می‌دارد.
WITH customer_metrics AS (
    SELECT
        c.customer_id,
        COUNT(DISTINCT CASE WHEN o.status = 'completed' THEN o.order_id END)
            AS completed_orders,
        SUM(CASE WHEN o.status = 'completed' THEN i.net_revenue ELSE 0 END)
            AS completed_net_revenue
    FROM dbo.customers AS c
    LEFT JOIN dbo.vw_orders_clean AS o
        ON o.customer_id = c.customer_id
    LEFT JOIN dbo.vw_order_items_enriched AS i
        ON i.order_id = o.order_id
    GROUP BY c.customer_id
),
customer_segments AS (
    SELECT
        customer_id,
        completed_orders,
        completed_net_revenue,
        CASE
            WHEN completed_orders = 0 THEN 'No Completed Purchase'
            WHEN completed_orders >= 5 AND completed_net_revenue >= 1000
                THEN 'High Value'
            WHEN completed_orders >= 2 THEN 'Repeat'
            ELSE 'One-time'
        END AS customer_segment
    FROM customer_metrics
)
SELECT
    customer_segment,
    COUNT(*) AS customer_count,
    ROUND(SUM(completed_net_revenue), 2) AS completed_net_revenue
FROM customer_segments
GROUP BY customer_segment
ORDER BY completed_net_revenue DESC;
