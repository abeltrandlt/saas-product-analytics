-- ============================================
-- Churn Prediction with Leading Indicators
-- ============================================
-- Business Question: What signals predict churn before it happens?
-- Analysis: Behavioral patterns, engagement trends, churn risk scoring
-- Author: Alberto Beltran
-- Date: 2026-03-21
-- ============================================

-- STEP 1: Define user status (churned vs retained)
WITH dataset_context AS (
    SELECT MAX(DATE(event_timestamp)) AS dataset_end_date
    FROM events
),

user_status AS (
    SELECT 
        u.user_id,
        u.signup_date,
        u.acquisition_channel,
        MAX(DATE(e.event_timestamp)) AS last_active_date,
        (SELECT dataset_end_date FROM dataset_context) AS dataset_end_date,
        (SELECT dataset_end_date FROM dataset_context) - MAX(DATE(e.event_timestamp)) AS days_since_last_active,
        -- Define churn: inactive 90+ days
        CASE 
            WHEN (SELECT dataset_end_date FROM dataset_context) - MAX(DATE(e.event_timestamp)) > 90 
            THEN 1 
            ELSE 0 
        END AS is_churned
    FROM users u
    LEFT JOIN events e ON u.user_id = e.user_id
    WHERE e.event_type IN ('login', 'feature_use')
    GROUP BY u.user_id, u.signup_date, u.acquisition_channel
),

-- STEP 2: Calculate engagement metrics for all users
user_engagement_metrics AS (
    SELECT 
        u.user_id,
        COUNT(e.event_id) AS total_events,
        COUNT(DISTINCT DATE(e.event_timestamp)) AS days_active,
        COUNT(DISTINCT e.feature_used) AS unique_features_used,
        -- Calculate engagement trend (last 30 days vs previous 30 days)
        COUNT(CASE 
            WHEN e.event_timestamp >= (SELECT dataset_end_date FROM dataset_context) - INTERVAL '30 days' 
            THEN 1 
        END) AS events_last_30d,
        COUNT(CASE 
            WHEN e.event_timestamp >= (SELECT dataset_end_date FROM dataset_context) - INTERVAL '60 days' 
                 AND e.event_timestamp < (SELECT dataset_end_date FROM dataset_context) - INTERVAL '30 days'
            THEN 1 
        END) AS events_30_60d_ago,
        -- Session frequency (avg days between sessions)
        ROUND(
            EXTRACT(EPOCH FROM (MAX(e.event_timestamp) - MIN(e.event_timestamp))) / 86400 / 
            NULLIF(COUNT(DISTINCT DATE(e.event_timestamp)), 1),
            2
        ) AS avg_days_between_sessions
    FROM users u
    LEFT JOIN events e ON u.user_id = e.user_id
    WHERE e.event_type IN ('login', 'feature_use')
    GROUP BY u.user_id
),

-- STEP 3: Calculate subscription metrics
user_subscription_metrics AS (
    SELECT 
        u.user_id,
        COUNT(s.subscription_id) AS total_subscriptions,
        MAX(CASE WHEN s.plan_type != 'free' THEN 1 ELSE 0 END) AS has_paid_subscription,
        MAX(CASE WHEN s.status = 'churned' THEN 1 ELSE 0 END) AS has_churned_subscription,
        -- Days on current plan
        MAX(
            CASE 
                WHEN s.status = 'active' 
                THEN (SELECT dataset_end_date FROM dataset_context) - s.start_date 
            END
        ) AS days_on_current_plan
    FROM users u
    LEFT JOIN subscriptions s ON u.user_id = s.user_id
    GROUP BY u.user_id
),

-- STEP 4: Combine all metrics
user_churn_features AS (
    SELECT 
        us.user_id,
        us.signup_date,
        us.acquisition_channel,
        us.is_churned,
        us.days_since_last_active,
        uem.total_events,
        uem.days_active,
        uem.unique_features_used,
        uem.events_last_30d,
        uem.events_30_60d_ago,
        uem.avg_days_between_sessions,
        usm.total_subscriptions,
        usm.has_paid_subscription,
        usm.has_churned_subscription,
        usm.days_on_current_plan,
        -- Engagement trend (declining if last 30d < previous 30d)
        CASE 
            WHEN uem.events_last_30d < uem.events_30_60d_ago THEN 1 
            ELSE 0 
        END AS declining_engagement,
        -- Low engagement flag
        CASE 
            WHEN uem.total_events < 50 THEN 1 
            ELSE 0 
        END AS low_engagement,
        -- Feature breadth (using <3 features = narrow usage)
        CASE 
            WHEN uem.unique_features_used < 3 THEN 1 
            ELSE 0 
        END AS narrow_feature_usage
    FROM user_status us
    LEFT JOIN user_engagement_metrics uem ON us.user_id = uem.user_id
    LEFT JOIN user_subscription_metrics usm ON us.user_id = usm.user_id
)

-- =============================================
-- PART 1: Churn Rate Overview
-- =============================================
SELECT 
    COUNT(*) AS total_users,
    SUM(is_churned) AS churned_users,
    COUNT(*) - SUM(is_churned) AS retained_users,
    ROUND(100.0 * SUM(is_churned) / COUNT(*), 2) AS churn_rate_pct
FROM user_churn_features;


-- =============================================
-- PART 2: Leading Indicators Comparison
-- =============================================
-- Compare churned vs retained users on key metrics
SELECT 
    'Churned Users' AS user_group,
    COUNT(*) AS user_count,
    ROUND(AVG(total_events), 2) AS avg_total_events,
    ROUND(AVG(days_active), 2) AS avg_days_active,
    ROUND(AVG(unique_features_used), 2) AS avg_features_used,
    ROUND(AVG(events_last_30d), 2) AS avg_events_last_30d,
    ROUND(AVG(avg_days_between_sessions), 2) AS avg_session_gap,
    ROUND(100.0 * SUM(declining_engagement) / COUNT(*), 2) AS pct_declining_engagement,
    ROUND(100.0 * SUM(low_engagement) / COUNT(*), 2) AS pct_low_engagement,
    ROUND(100.0 * SUM(narrow_feature_usage) / COUNT(*), 2) AS pct_narrow_usage,
    ROUND(100.0 * SUM(has_paid_subscription) / COUNT(*), 2) AS pct_paid
FROM user_churn_features
WHERE is_churned = 1

UNION ALL

SELECT 
    'Retained Users',
    COUNT(*),
    ROUND(AVG(total_events), 2),
    ROUND(AVG(days_active), 2),
    ROUND(AVG(unique_features_used), 2),
    ROUND(AVG(events_last_30d), 2),
    ROUND(AVG(avg_days_between_sessions), 2),
    ROUND(100.0 * SUM(declining_engagement) / COUNT(*), 2),
    ROUND(100.0 * SUM(low_engagement) / COUNT(*), 2),
    ROUND(100.0 * SUM(narrow_feature_usage) / COUNT(*), 2),
    ROUND(100.0 * SUM(has_paid_subscription) / COUNT(*), 2)
FROM user_churn_features
WHERE is_churned = 0;


-- =============================================
-- PART 3: Churn Risk Scoring
-- =============================================
-- Assign risk scores based on leading indicators
WITH risk_scores AS (
    SELECT 
        user_id,
        signup_date,
        acquisition_channel,
        is_churned,
        days_since_last_active,
        -- Risk score: sum of risk factors (0-7 scale)
        (
            declining_engagement +
            low_engagement +
            narrow_feature_usage +
            CASE WHEN events_last_30d = 0 THEN 1 ELSE 0 END +
            CASE WHEN avg_days_between_sessions > 7 THEN 1 ELSE 0 END +
            CASE WHEN has_paid_subscription = 0 THEN 1 ELSE 0 END +
            CASE WHEN days_on_current_plan > 330 THEN 1 ELSE 0 END  -- Approaching renewal
        ) AS churn_risk_score
    FROM user_churn_features
)

SELECT 
    churn_risk_score,
    COUNT(*) AS users,
    SUM(is_churned) AS churned,
    ROUND(100.0 * SUM(is_churned) / COUNT(*), 2) AS churn_rate_pct,
    CASE 
        WHEN churn_risk_score <= 2 THEN 'Low Risk'
        WHEN churn_risk_score <= 4 THEN 'Medium Risk'
        ELSE 'High Risk'
    END AS risk_category
FROM risk_scores
GROUP BY churn_risk_score
ORDER BY churn_risk_score;


-- =============================================
-- PART 4: At-Risk User Identification
-- =============================================
-- Flag current users at high risk of churning
WITH risk_scores AS (
    SELECT 
        user_id,
        acquisition_channel,
        total_events,
        days_active,
        events_last_30d,
        events_30_60d_ago,
        days_since_last_active,
        (
            declining_engagement +
            low_engagement +
            narrow_feature_usage +
            CASE WHEN events_last_30d = 0 THEN 1 ELSE 0 END +
            CASE WHEN avg_days_between_sessions > 7 THEN 1 ELSE 0 END +
            CASE WHEN has_paid_subscription = 0 THEN 1 ELSE 0 END +
            CASE WHEN days_on_current_plan > 330 THEN 1 ELSE 0 END
        ) AS churn_risk_score
    FROM user_churn_features
    WHERE is_churned = 0  -- Only look at current users
)

SELECT 
    user_id,
    acquisition_channel,
    total_events,
    days_active,
    events_last_30d,
    events_30_60d_ago,
    days_since_last_active,
    churn_risk_score,
    CASE 
        WHEN churn_risk_score >= 5 THEN 'URGENT: Immediate intervention needed'
        WHEN churn_risk_score >= 3 THEN 'WARNING: Proactive outreach recommended'
        ELSE 'HEALTHY: Monitor'
    END AS intervention_recommendation
FROM risk_scores
WHERE churn_risk_score >= 3  -- Only show at-risk users
ORDER BY churn_risk_score DESC, days_since_last_active DESC
LIMIT 50;  -- Top 50 at-risk users