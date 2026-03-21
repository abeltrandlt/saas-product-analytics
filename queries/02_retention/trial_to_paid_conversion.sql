-- ============================================
-- Trial-to-Paid Conversion Analysis
-- ============================================
-- Business Question: What % of free users convert to paid? How fast?
-- Analysis: Conversion funnel, time to conversion, plan distribution
-- Author: Alberto Beltran
-- Date: 2026-03-21
-- ============================================

-- STEP 1: Identify users and their subscription journey
WITH user_subscriptions AS (
    SELECT 
        u.user_id,
        u.signup_date,
        u.acquisition_channel,
        s.subscription_id,
        s.plan_type,
        s.start_date,
        s.end_date,
        s.status,
        -- Rank subscriptions by start date (1 = first subscription)
        ROW_NUMBER() OVER (PARTITION BY u.user_id ORDER BY s.start_date) AS subscription_rank
    FROM users u
    LEFT JOIN subscriptions s ON u.user_id = s.user_id
),

-- STEP 2: Get first subscription for each user
first_subscription AS (
    SELECT 
        user_id,
        signup_date,
        acquisition_channel,
        plan_type AS first_plan,
        start_date AS first_sub_start,
        status AS first_sub_status
    FROM user_subscriptions
    WHERE subscription_rank = 1
),

-- STEP 3: Get first PAID subscription for each user
first_paid_subscription AS (
    SELECT 
        user_id,
        plan_type AS first_paid_plan,
        start_date AS first_paid_start,
        status AS paid_sub_status,
        ROW_NUMBER() OVER (PARTITION BY user_id ORDER BY start_date) AS paid_rank
    FROM user_subscriptions
    WHERE plan_type != 'free'
),

-- STEP 4: Combine to create conversion data
conversion_data AS (
    SELECT 
        fs.user_id,
        fs.signup_date,
        fs.acquisition_channel,
        fs.first_plan,
        fs.first_sub_start,
        fp.first_paid_plan,
        fp.first_paid_start,
        -- Calculate time to conversion
        CASE 
            WHEN fp.first_paid_start IS NOT NULL 
            THEN fp.first_paid_start::date - fs.signup_date::date 
            ELSE NULL 
        END AS days_to_conversion,
        -- Conversion flag
        CASE 
            WHEN fp.first_paid_plan IS NOT NULL THEN 1 
            ELSE 0 
        END AS converted
    FROM first_subscription fs
    LEFT JOIN (
        SELECT * FROM first_paid_subscription WHERE paid_rank = 1
    ) fp ON fs.user_id = fp.user_id
    WHERE fs.first_plan = 'free'  -- Only analyze users who started on free
)

-- =============================================
-- PART 1: Overall Conversion Metrics
-- =============================================
SELECT 
    COUNT(*) AS total_free_users,
    SUM(converted) AS converted_users,
    COUNT(*) - SUM(converted) AS still_free_or_churned,
    ROUND(100.0 * SUM(converted) / COUNT(*), 2) AS conversion_rate_pct,
    ROUND(AVG(days_to_conversion), 2) AS avg_days_to_conversion,
    PERCENTILE_CONT(0.50) WITHIN GROUP (ORDER BY days_to_conversion) AS median_days_to_conversion,
    MIN(days_to_conversion) AS fastest_conversion_days,
    MAX(days_to_conversion) AS slowest_conversion_days
FROM conversion_data;


-- =============================================
-- PART 2: Conversion Rate by Acquisition Channel
-- =============================================
SELECT 
    acquisition_channel,
    COUNT(*) AS total_free_users,
    SUM(converted) AS converted_users,
    ROUND(100.0 * SUM(converted) / COUNT(*), 2) AS conversion_rate_pct,
    ROUND(AVG(days_to_conversion), 2) AS avg_days_to_conversion
FROM conversion_data
GROUP BY acquisition_channel
ORDER BY conversion_rate_pct DESC;


-- =============================================
-- PART 3: Plan Distribution (What do converters choose?)
-- =============================================
SELECT 
    first_paid_plan,
    COUNT(*) AS conversions,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS pct_of_conversions,
    ROUND(AVG(days_to_conversion), 2) AS avg_days_to_conversion
FROM conversion_data
WHERE converted = 1
GROUP BY first_paid_plan
ORDER BY conversions DESC;


-- =============================================
-- PART 4: Time-to-Conversion Distribution
-- =============================================
SELECT 
    CASE 
        WHEN days_to_conversion <= 7 THEN '0-7 days'
        WHEN days_to_conversion <= 14 THEN '8-14 days'
        WHEN days_to_conversion <= 30 THEN '15-30 days'
        WHEN days_to_conversion <= 60 THEN '31-60 days'
        WHEN days_to_conversion <= 90 THEN '61-90 days'
        ELSE '90+ days'
    END AS conversion_window,
    COUNT(*) AS conversions,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS pct_of_conversions,
    ROUND(AVG(days_to_conversion), 2) AS avg_days_in_window
FROM conversion_data
WHERE converted = 1
GROUP BY 
    CASE 
        WHEN days_to_conversion <= 7 THEN '0-7 days'
        WHEN days_to_conversion <= 14 THEN '8-14 days'
        WHEN days_to_conversion <= 30 THEN '15-30 days'
        WHEN days_to_conversion <= 60 THEN '31-60 days'
        WHEN days_to_conversion <= 90 THEN '61-90 days'
        ELSE '90+ days'
    END
ORDER BY 
    CASE conversion_window
        WHEN '0-7 days' THEN 1
        WHEN '8-14 days' THEN 2
        WHEN '15-30 days' THEN 3
        WHEN '31-60 days' THEN 4
        WHEN '61-90 days' THEN 5
        ELSE 6
    END;


-- =============================================
-- PART 5: Non-Converters Analysis
-- =============================================
WITH non_converter_activity AS (
    SELECT 
        cd.user_id,
        cd.signup_date,
        cd.acquisition_channel,
        COUNT(e.event_id) AS total_events,
        MAX(e.event_timestamp::date) AS last_active_date,
        (SELECT MAX(event_timestamp::date) FROM events) - MAX(e.event_timestamp::date) AS days_since_last_active
    FROM conversion_data cd
    LEFT JOIN events e ON cd.user_id = e.user_id
    WHERE cd.converted = 0
    GROUP BY cd.user_id, cd.signup_date, cd.acquisition_channel
)

SELECT 
    'Total Non-Converters' AS metric,
    COUNT(*)::text AS value
FROM non_converter_activity

UNION ALL

SELECT 
    'Never Active (0 events)',
    COUNT(*)::text
FROM non_converter_activity
WHERE total_events = 0

UNION ALL

SELECT 
    'Low Activity (1-10 events)',
    COUNT(*)::text
FROM non_converter_activity
WHERE total_events BETWEEN 1 AND 10

UNION ALL

SELECT 
    'Active but not converted (10+ events)',
    COUNT(*)::text
FROM non_converter_activity
WHERE total_events > 10

UNION ALL

SELECT 
    'Avg Events per Non-Converter',
    ROUND(AVG(total_events), 2)::text
FROM non_converter_activity

UNION ALL

SELECT 
    'Avg Days Since Last Active',
    ROUND(AVG(days_since_last_active), 2)::text
FROM non_converter_activity;