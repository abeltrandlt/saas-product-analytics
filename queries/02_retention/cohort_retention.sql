-- ============================================
-- Monthly Cohort Retention Analysis
-- ============================================
-- Business Question: What % of users remain active after 1, 3, 6, 12 months?
-- Analysis: Cohort retention table, retention curves, drop-off timing
-- Author: Alberto Beltran
-- Date: 2026-03-18
-- ============================================

-- STEP 1: Define user cohorts by signup month
WITH user_cohorts AS (
    SELECT 
        user_id,
        DATE_TRUNC('month', signup_date) AS cohort_month,
        signup_date
    FROM users
),

-- STEP 2: Get cohort sizes
cohort_sizes AS (
    SELECT 
        cohort_month,
        COUNT(*) AS cohort_size
    FROM user_cohorts
    GROUP BY cohort_month
),

-- STEP 3: Calculate activity for each user in each month
user_activity_months AS (
    SELECT DISTINCT
        uc.user_id,
        uc.cohort_month,
        DATE_TRUNC('month', e.event_timestamp) AS activity_month
    FROM user_cohorts uc
    JOIN events e ON uc.user_id = e.user_id
    WHERE e.event_type IN ('login', 'feature_use')
),

-- STEP 4: Calculate months since signup
cohort_activity AS (
    SELECT 
        cohort_month,
        activity_month,
        -- Calculate month number (0 = signup month, 1 = first month after, etc.)
        EXTRACT(YEAR FROM AGE(activity_month, cohort_month)) * 12 + 
        EXTRACT(MONTH FROM AGE(activity_month, cohort_month)) AS months_since_signup,
        COUNT(DISTINCT user_id) AS active_users
    FROM user_activity_months
    GROUP BY cohort_month, activity_month
),

-- STEP 5: Calculate retention percentages
cohort_retention AS (
    SELECT 
        ca.cohort_month,
        ca.months_since_signup,
        ca.active_users,
        cs.cohort_size,
        ROUND(100.0 * ca.active_users / cs.cohort_size, 2) AS retention_pct
    FROM cohort_activity ca
    JOIN cohort_sizes cs ON ca.cohort_month = cs.cohort_month
)

-- STEP 6: Retention table (pivot-style view)
SELECT 
    cohort_month,
    cohort_size,
    MAX(CASE WHEN months_since_signup = 0 THEN retention_pct END) AS month_0,
    MAX(CASE WHEN months_since_signup = 1 THEN retention_pct END) AS month_1,
    MAX(CASE WHEN months_since_signup = 3 THEN retention_pct END) AS month_3,
    MAX(CASE WHEN months_since_signup = 6 THEN retention_pct END) AS month_6,
    MAX(CASE WHEN months_since_signup = 9 THEN retention_pct END) AS month_9,
    MAX(CASE WHEN months_since_signup = 12 THEN retention_pct END) AS month_12
FROM cohort_retention
WHERE cohort_month >= '2022-01-01'  -- Focus on cohorts with history
GROUP BY cohort_month, cohort_size
ORDER BY cohort_month;

-- Alternative: Full retention curve (not pivoted)
-- Useful for charting in Tableau
SELECT 
    cohort_month,
    months_since_signup,
    cohort_size,
    active_users,
    retention_pct
FROM cohort_retention
WHERE cohort_month >= '2022-01-01'
  AND months_since_signup <= 12
ORDER BY cohort_month, months_since_signup;