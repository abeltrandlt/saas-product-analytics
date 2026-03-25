-- ============================================
-- Time-to-Value (Activation Analysis)
-- ============================================
-- Business Question: How fast do users activate? Does speed predict retention?
-- Analysis: Activation milestones, time to value, retention correlation
-- Author: Alberto Beltran
-- Date: 2026-03-21
-- ============================================

-- STEP 1: Calculate activation milestones for each user
WITH user_activation_milestones AS (
    SELECT 
        u.user_id,
        u.signup_date,
        u.acquisition_channel,
        -- Time to first event
        MIN(e.event_timestamp::date) - u.signup_date AS days_to_first_event,
        -- Time to first feature use
        MIN(CASE 
            WHEN e.event_type = 'feature_use' 
            THEN e.event_timestamp::date 
        END) - u.signup_date AS days_to_first_feature,
        -- Count events in first 7 days
        COUNT(CASE 
            WHEN e.event_timestamp::date <= u.signup_date + 7 
            THEN 1 
        END) AS events_first_7d,
        -- Count events in first 30 days
        COUNT(CASE 
            WHEN e.event_timestamp::date <= u.signup_date + 30 
            THEN 1 
        END) AS events_first_30d,
        -- Count unique features used in first 30 days
        COUNT(DISTINCT CASE 
            WHEN e.event_timestamp::date <= u.signup_date + 30 
                 AND e.feature_used IS NOT NULL
            THEN e.feature_used 
        END) AS unique_features_first_30d
    FROM users u
    LEFT JOIN events e ON u.user_id = e.user_id
    GROUP BY u.user_id, u.signup_date, u.acquisition_channel
),

-- STEP 2: Define activation status
user_activation_status AS (
    SELECT 
        *,
        -- Activation flag: 3+ features AND 10+ events in first 30 days
        CASE 
            WHEN unique_features_first_30d >= 3 
                 AND events_first_30d >= 10 
            THEN 1 
            ELSE 0 
        END AS is_activated,
        -- Activation speed category
        CASE 
            WHEN unique_features_first_30d >= 3 AND events_first_7d >= 10
                THEN 'Fast (0-7 days)'
            WHEN unique_features_first_30d >= 3 AND events_first_30d >= 10
                THEN 'Medium (8-30 days)'
            WHEN unique_features_first_30d >= 3 
                THEN 'Slow (30+ days)'
            ELSE 'Never Activated'
        END AS activation_speed
    FROM user_activation_milestones
),

-- STEP 3: Calculate retention for activation analysis
user_retention_status AS (
    SELECT 
        uas.*,
        MAX(e.event_timestamp::date) AS last_active_date,
        (SELECT MAX(event_timestamp::date) FROM events) AS dataset_end_date,
        (SELECT MAX(event_timestamp::date) FROM events) - MAX(e.event_timestamp::date) AS days_since_last_active,
        -- Retained if active within 90 days of dataset end
        CASE 
            WHEN (SELECT MAX(event_timestamp::date) FROM events) - MAX(e.event_timestamp::date) <= 90 
            THEN 1 
            ELSE 0 
        END AS is_retained
    FROM user_activation_status uas
    LEFT JOIN events e ON uas.user_id = e.user_id
    GROUP BY uas.user_id, uas.signup_date, uas.acquisition_channel, 
             uas.days_to_first_event, uas.days_to_first_feature, 
             uas.events_first_7d, uas.events_first_30d, 
             uas.unique_features_first_30d,
             uas.is_activated, uas.activation_speed
)

-- =============================================
-- PART 1: Overall Activation Metrics
-- =============================================
SELECT 
    COUNT(*) AS total_users,
    COUNT(CASE WHEN days_to_first_event IS NOT NULL THEN 1 END) AS users_with_events,
    SUM(is_activated) AS activated_users,
    ROUND(100.0 * SUM(is_activated) / COUNT(*), 2) AS activation_rate_pct,
    ROUND(AVG(days_to_first_event), 2) AS avg_days_to_first_event,
    ROUND(PERCENTILE_CONT(0.50) WITHIN GROUP (ORDER BY days_to_first_event)::NUMERIC, 2) AS median_days_to_first_event,
    ROUND(AVG(days_to_first_feature), 2) AS avg_days_to_first_feature,
    ROUND(AVG(events_first_7d), 2) AS avg_events_first_7d,
    ROUND(AVG(events_first_30d), 2) AS avg_events_first_30d
FROM user_retention_status;


-- =============================================
-- PART 2: Activation Speed Distribution
-- =============================================
SELECT 
    activation_speed,
    COUNT(*) AS users,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS pct_of_users,
    ROUND(AVG(events_first_30d), 2) AS avg_events_first_30d,
    ROUND(AVG(unique_features_first_30d), 2) AS avg_features_tried
FROM user_retention_status
GROUP BY activation_speed
ORDER BY 
    CASE activation_speed
        WHEN 'Fast (0-7 days)' THEN 1
        WHEN 'Medium (8-30 days)' THEN 2
        WHEN 'Slow (30+ days)' THEN 3
        WHEN 'Never Activated' THEN 4
    END;


-- =============================================
-- PART 3: Activation vs Retention Correlation
-- =============================================
SELECT 
    activation_speed,
    COUNT(*) AS total_users,
    SUM(is_retained) AS retained_users,
    ROUND(100.0 * SUM(is_retained) / COUNT(*), 2) AS retention_rate_pct,
    ROUND(AVG(days_since_last_active), 2) AS avg_days_since_last_active
FROM user_retention_status
GROUP BY activation_speed
ORDER BY 
    CASE activation_speed
        WHEN 'Fast (0-7 days)' THEN 1
        WHEN 'Medium (8-30 days)' THEN 2
        WHEN 'Slow (30+ days)' THEN 3
        WHEN 'Never Activated' THEN 4
    END;


-- =============================================
-- PART 4: Activation by Acquisition Channel
-- =============================================
SELECT 
    acquisition_channel,
    COUNT(*) AS total_users,
    SUM(is_activated) AS activated_users,
    ROUND(100.0 * SUM(is_activated) / COUNT(*), 2) AS activation_rate_pct,
    ROUND(AVG(days_to_first_event), 2) AS avg_days_to_first_event,
    ROUND(AVG(events_first_7d), 2) AS avg_events_first_7d
FROM user_retention_status
GROUP BY acquisition_channel
ORDER BY activation_rate_pct DESC;


-- =============================================
-- PART 5: Early Engagement Indicators
-- =============================================
-- Does activity in first week predict long-term retention?
SELECT 
    CASE 
        WHEN events_first_7d = 0 THEN '0 events'
        WHEN events_first_7d BETWEEN 1 AND 5 THEN '1-5 events'
        WHEN events_first_7d BETWEEN 6 AND 10 THEN '6-10 events'
        WHEN events_first_7d BETWEEN 11 AND 20 THEN '11-20 events'
        ELSE '20+ events'
    END AS first_week_activity,
    COUNT(*) AS users,
    ROUND(100.0 * SUM(is_activated) / COUNT(*), 2) AS activation_rate_pct,
    ROUND(100.0 * SUM(is_retained) / COUNT(*), 2) AS retention_rate_pct
FROM user_retention_status
GROUP BY 
    CASE 
        WHEN events_first_7d = 0 THEN '0 events'
        WHEN events_first_7d BETWEEN 1 AND 5 THEN '1-5 events'
        WHEN events_first_7d BETWEEN 6 AND 10 THEN '6-10 events'
        WHEN events_first_7d BETWEEN 11 AND 20 THEN '11-20 events'
        ELSE '20+ events'
    END
ORDER BY 
    CASE 'first_week_activity'
        WHEN '0 events' THEN 1
        WHEN '1-5 events' THEN 2
        WHEN '6-10 events' THEN 3
        WHEN '11-20 events' THEN 4
        ELSE 5
    END;