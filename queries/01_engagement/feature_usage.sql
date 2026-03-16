-- ============================================
-- Feature Usage Ranking & Adoption Analysis
-- ============================================
-- Business Question: Which features drive the most engagement?
-- Metrics: Total uses, unique users, adoption rate, intensity
-- Author: Alberto Beltran
-- Date: 2026-03-12
-- ============================================

-- STEP 1: Get total user count for adoption rate calculation
WITH total_users AS (
    SELECT COUNT(DISTINCT user_id) AS total_user_count
    FROM users
),

-- STEP 2: Calculate feature usage metrics
feature_stats AS (
    SELECT 
        feature_used,
        COUNT(*) AS total_uses,
        COUNT(DISTINCT user_id) AS unique_users,
        ROUND(COUNT(*)::NUMERIC / COUNT(DISTINCT user_id), 2) AS avg_uses_per_user
    FROM events
    WHERE event_type = 'feature_use'
      AND feature_used IS NOT NULL  -- Exclude NULL features
    GROUP BY feature_used
)

-- STEP 3: Calculate adoption rate and rank features
SELECT 
    f.feature_used,
    f.total_uses,
    f.unique_users,
    ROUND(100.0 * f.unique_users / t.total_user_count, 2) AS adoption_rate_pct,
    f.avg_uses_per_user,
    RANK() OVER (ORDER BY f.total_uses DESC) AS usage_rank
FROM feature_stats f
CROSS JOIN total_users t
ORDER BY f.total_uses DESC;

-- Adding a time series analysis to see how feature usage evolves over time
SELECT 
    DATE_TRUNC('month', event_timestamp) AS month,
    feature_used,
    COUNT(*) AS monthly_uses
FROM events
WHERE event_type = 'feature_use'
  AND feature_used IS NOT NULL
GROUP BY DATE_TRUNC('month', event_timestamp), feature_used
ORDER BY month, monthly_uses DESC;