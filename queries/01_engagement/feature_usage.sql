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

-- Expected Output:
-- feature_used  | total_uses | unique_users | adoption_rate_pct | avg_uses_per_user | usage_rank
-- --------------|------------|--------------|-------------------|-------------------|------------
-- dashboard     | 32,456     | 782          | 78.2              | 41.51             | 1
-- reporting     | 20,312     | 654          | 65.4              | 31.06             | 2
-- integrations  | 16,248     | 521          | 52.1              | 31.19             | 3
-- api_access    | 8,124      | 289          | 28.9              | 28.11             | 4
-- analytics     | 4,062      | 178          | 17.8              | 22.82             | 5