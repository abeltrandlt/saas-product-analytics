-- ============================================
-- Retention by Acquisition Channel
-- ============================================
-- Business Question: Which channels bring the stickiest users?
-- Analysis: Channel retention rates, engagement quality, LTV drivers
-- Author: Alberto Beltran
-- Date: 2026-03-18
-- ============================================

-- STEP 1: Calculate user activity metrics by channel
WITH user_channel_activity AS (
    SELECT 
        u.user_id,
        u.acquisition_channel,
        u.signup_date,
        COUNT(e.event_id) AS total_events,
        COUNT(DISTINCT DATE(e.event_timestamp)) AS days_active,
        MIN(DATE(e.event_timestamp)) AS first_event_date,
        MAX(DATE(e.event_timestamp)) AS last_event_date,
        -- Get dataset max date for recency calculation
        (SELECT MAX(DATE(event_timestamp)) FROM events) AS dataset_end_date
    FROM users u
    LEFT JOIN events e ON u.user_id = e.user_id
    WHERE e.event_type IN ('login', 'feature_use')
    GROUP BY u.user_id, u.acquisition_channel, u.signup_date
),

-- STEP 2: Calculate retention flags (active at M1, M3, M6, M12)
user_retention_flags AS (
    SELECT 
        user_id,
        acquisition_channel,
        signup_date,
        total_events,
        days_active,
        last_event_date,
        dataset_end_date,
        -- 30-day retention (M1)
        CASE 
            WHEN last_event_date >= signup_date + INTERVAL '30 days' 
            THEN 1 ELSE 0 
        END AS retained_30d,
        -- 90-day retention (M3)
        CASE 
            WHEN last_event_date >= signup_date + INTERVAL '90 days' 
            THEN 1 ELSE 0 
        END AS retained_90d,
        -- 180-day retention (M6)
        CASE 
            WHEN last_event_date >= signup_date + INTERVAL '180 days' 
            THEN 1 ELSE 0 
        END AS retained_180d,
        -- 365-day retention (M12)
        CASE 
            WHEN last_event_date >= signup_date + INTERVAL '365 days' 
            THEN 1 ELSE 0 
        END AS retained_365d,
        -- Active in last 30 days of dataset
        CASE 
            WHEN dataset_end_date - last_event_date <= 30 
            THEN 1 ELSE 0 
        END AS currently_active
    FROM user_channel_activity
),

-- STEP 3: Calculate channel-level retention metrics
channel_retention AS (
    SELECT 
        acquisition_channel,
        COUNT(*) AS total_users,
        -- Retention rates
        ROUND(100.0 * SUM(retained_30d) / COUNT(*), 2) AS retention_30d_pct,
        ROUND(100.0 * SUM(retained_90d) / COUNT(*), 2) AS retention_90d_pct,
        ROUND(100.0 * SUM(retained_180d) / COUNT(*), 2) AS retention_180d_pct,
        ROUND(100.0 * SUM(retained_365d) / COUNT(*), 2) AS retention_365d_pct,
        ROUND(100.0 * SUM(currently_active) / COUNT(*), 2) AS currently_active_pct,
        -- Engagement quality
        ROUND(AVG(total_events), 2) AS avg_events_per_user,
        ROUND(AVG(days_active), 2) AS avg_days_active,
        -- Churn (users with 0 events or only activated once)
        ROUND(100.0 * SUM(CASE WHEN total_events <= 5 THEN 1 ELSE 0 END) / COUNT(*), 2) AS churn_pct
    FROM user_retention_flags
    GROUP BY acquisition_channel
)

-- STEP 4: Rank channels by 90-day retention (key metric)
SELECT 
    acquisition_channel,
    total_users,
    retention_30d_pct,
    retention_90d_pct,
    retention_180d_pct,
    retention_365d_pct,
    currently_active_pct,
    avg_events_per_user,
    avg_days_active,
    churn_pct,
    RANK() OVER (ORDER BY retention_90d_pct DESC) AS retention_rank
FROM channel_retention
ORDER BY retention_90d_pct DESC;

-- =============================================
-- BONUS: Cohort Retention Curves by Channel
-- =============================================
-- Shows how each channel's retention evolves over time

WITH user_cohorts AS (
    SELECT 
        user_id,
        acquisition_channel,
        DATE_TRUNC('month', signup_date) AS cohort_month,
        signup_date
    FROM users
    WHERE signup_date >= '2022-01-01'  -- Focus on 2022+ cohorts
),

user_activity_months AS (
    SELECT DISTINCT
        uc.user_id,
        uc.acquisition_channel,
        uc.cohort_month,
        DATE_TRUNC('month', e.event_timestamp) AS activity_month
    FROM user_cohorts uc
    JOIN events e ON uc.user_id = e.user_id
    WHERE e.event_type IN ('login', 'feature_use')
),

channel_cohort_activity AS (
    SELECT 
        acquisition_channel,
        cohort_month,
        activity_month,
        EXTRACT(YEAR FROM AGE(activity_month, cohort_month)) * 12 + 
        EXTRACT(MONTH FROM AGE(activity_month, cohort_month)) AS months_since_signup,
        COUNT(DISTINCT user_id) AS active_users
    FROM user_activity_months
    GROUP BY acquisition_channel, cohort_month, activity_month
),

channel_cohort_sizes AS (
    SELECT 
        acquisition_channel,
        cohort_month,
        COUNT(*) AS cohort_size
    FROM user_cohorts
    GROUP BY acquisition_channel, cohort_month
)

SELECT 
    cca.acquisition_channel,
    cca.cohort_month,
    ccs.cohort_size,
    cca.months_since_signup,
    cca.active_users,
    ROUND(100.0 * cca.active_users / ccs.cohort_size, 2) AS retention_pct
FROM channel_cohort_activity cca
JOIN channel_cohort_sizes ccs 
    ON cca.acquisition_channel = ccs.acquisition_channel 
    AND cca.cohort_month = ccs.cohort_month
WHERE cca.months_since_signup <= 12
ORDER BY cca.acquisition_channel, cca.cohort_month, cca.months_since_signup;