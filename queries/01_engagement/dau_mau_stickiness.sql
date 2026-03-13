-- ============================================
-- DAU, MAU, and Stickiness Analysis
-- ============================================
-- Business Question: What is our daily and monthly user engagement?
-- Metrics: Daily Active Users, Monthly Active Users, Stickiness Ratio
-- Author: Alberto Beltran
-- Date: 2026-03-12
-- ============================================

-- STEP 1: Calculate Daily Active Users (DAU)
WITH daily_active AS (
    SELECT 
        DATE(event_timestamp) AS activity_date,
        COUNT(DISTINCT user_id) AS dau
    FROM events
    WHERE event_type IN ('login', 'feature_use')  -- Only "active" events
    GROUP BY DATE(event_timestamp)
),

-- STEP 2: Add 7-day moving average to smooth volatility
daily_with_ma AS (
    SELECT 
        activity_date,
        dau,
        AVG(dau) OVER (
            ORDER BY activity_date 
            ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
        ) AS dau_7day_avg
    FROM daily_active
),

-- STEP 3: Calculate Monthly Active Users (MAU)
monthly_active AS (
    SELECT 
        DATE_TRUNC('month', event_timestamp) AS activity_month,
        COUNT(DISTINCT user_id) AS mau
    FROM events
    WHERE event_type IN ('login', 'feature_use')
    GROUP BY DATE_TRUNC('month', event_timestamp)
),

-- STEP 4: Calculate average DAU per month for stickiness
monthly_avg_dau AS (
    SELECT 
        DATE_TRUNC('month', activity_date) AS activity_month,
        AVG(dau) AS avg_dau
    FROM daily_active
    GROUP BY DATE_TRUNC('month', activity_date)
)

-- STEP 5: Combine MAU and average DAU to calculate stickiness
SELECT 
    m.activity_month,
    m.mau,
    ROUND(d.avg_dau, 2) AS avg_dau,
    ROUND(100.0 * d.avg_dau / m.mau, 2) AS stickiness_pct
FROM monthly_active m
JOIN monthly_avg_dau d ON m.activity_month = d.activity_month
ORDER BY m.activity_month;

-- Expected Output:
-- activity_month | mau  | avg_dau | stickiness_pct
-- ---------------|------|---------|---------------
-- 2022-01-01     | 45   | 8.32    | 18.49
-- 2022-02-01     | 112  | 23.14   | 20.66
-- ...