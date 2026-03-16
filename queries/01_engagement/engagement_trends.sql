-- ============================================
-- Engagement Trends Over Time
-- ============================================
-- Business Question: How has engagement changed over time?
-- Analysis: Weekly trends, day-of-week patterns, month-over-month growth
-- Author: Alberto Beltran
-- Date: 2026-03-16
-- ============================================

-- =============================================
-- PART 1: Weekly Engagement Trends
-- =============================================

WITH weekly_engagement AS (
    SELECT 
        DATE_TRUNC('week', event_timestamp)::DATE AS week_start,
        COUNT(DISTINCT user_id) AS weekly_active_users,
        COUNT(*) AS total_events,
        COUNT(DISTINCT DATE(event_timestamp)) AS active_days_in_week
    FROM events
    WHERE event_type IN ('login', 'feature_use')
    GROUP BY DATE_TRUNC('week', event_timestamp)::DATE
)

SELECT 
    week_start,
    weekly_active_users,
    total_events,
    ROUND(total_events::NUMERIC / NULLIF(weekly_active_users, 0), 2) AS events_per_user,
    -- 4-week moving average to smooth volatility
    ROUND(AVG(weekly_active_users) OVER (
        ORDER BY week_start 
        ROWS BETWEEN 3 PRECEDING AND CURRENT ROW
    ), 2) AS wau_4week_avg,
    -- Week-over-week growth rate
    ROUND(100.0 * (weekly_active_users - LAG(weekly_active_users) OVER (ORDER BY week_start)) 
          / NULLIF(LAG(weekly_active_users) OVER (ORDER BY week_start), 0), 2) AS wow_growth_pct
FROM weekly_engagement
ORDER BY week_start;


-- =============================================
-- PART 2: Day-of-Week Patterns
-- =============================================

WITH daily_events AS (
    SELECT 
        DATE(event_timestamp) AS event_date,
        TO_CHAR(event_timestamp, 'Day') AS day_of_week,
        EXTRACT(DOW FROM event_timestamp) AS day_num,  -- 0=Sunday, 6=Saturday
        COUNT(DISTINCT user_id) AS daily_active_users,
        COUNT(*) AS total_events
    FROM events
    WHERE event_type IN ('login', 'feature_use')
    GROUP BY DATE(event_timestamp), TO_CHAR(event_timestamp, 'Day'), EXTRACT(DOW FROM event_timestamp)
)

SELECT 
    day_of_week,
    day_num,
    COUNT(*) AS total_days,
    ROUND(AVG(daily_active_users), 2) AS avg_dau,
    ROUND(AVG(total_events), 2) AS avg_daily_events,
    MIN(daily_active_users) AS min_dau,
    MAX(daily_active_users) AS max_dau
FROM daily_events
GROUP BY day_of_week, day_num
ORDER BY day_num;


-- =============================================
-- PART 3: Month-over-Month Growth Analysis
-- =============================================

WITH monthly_metrics AS (
    SELECT 
        DATE_TRUNC('month', event_timestamp) AS activity_month,
        COUNT(DISTINCT user_id) AS mau,
        COUNT(*) AS total_events,
        COUNT(DISTINCT DATE(event_timestamp)) AS active_days
    FROM events
    WHERE event_type IN ('login', 'feature_use')
    GROUP BY DATE_TRUNC('month', event_timestamp)
)

SELECT 
    activity_month,
    mau,
    total_events,
    -- Month-over-month growth
    LAG(mau, 1) OVER (ORDER BY activity_month) AS prev_month_mau,
    mau - LAG(mau, 1) OVER (ORDER BY activity_month) AS mau_change,
    ROUND(100.0 * (mau - LAG(mau, 1) OVER (ORDER BY activity_month)) 
          / NULLIF(LAG(mau, 1) OVER (ORDER BY activity_month), 0), 2) AS mom_growth_pct,
    -- 3-month moving average
    ROUND(AVG(mau) OVER (
        ORDER BY activity_month 
        ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
    ), 2) AS mau_3month_avg
FROM monthly_metrics
ORDER BY activity_month;


-- =============================================
-- PART 4: Cohort Engagement Trends
-- =============================================

WITH user_cohorts AS (
    SELECT 
        user_id,
        DATE_TRUNC('month', signup_date) AS signup_cohort
    FROM users
),

cohort_activity AS (
    SELECT 
        uc.signup_cohort,
        DATE_TRUNC('month', e.event_timestamp) AS activity_month,
        COUNT(DISTINCT e.user_id) AS active_users,
        COUNT(*) AS total_events
    FROM user_cohorts uc
    JOIN events e ON uc.user_id = e.user_id
    WHERE e.event_type IN ('login', 'feature_use')
    GROUP BY uc.signup_cohort, DATE_TRUNC('month', e.event_timestamp)
),

cohort_sizes AS (
    SELECT 
        signup_cohort,
        COUNT(*) AS cohort_size
    FROM user_cohorts
    GROUP BY signup_cohort
)

SELECT 
    ca.signup_cohort,
    cs.cohort_size,
    ca.activity_month,
    ca.active_users,
    ROUND(100.0 * ca.active_users / cs.cohort_size, 2) AS retention_pct,
    ca.total_events,
    ROUND(ca.total_events::NUMERIC / ca.active_users, 2) AS events_per_active_user
FROM cohort_activity ca
JOIN cohort_sizes cs ON ca.signup_cohort = cs.signup_cohort
WHERE ca.signup_cohort >= '2022-01-01'  -- Focus on cohorts with enough history
ORDER BY ca.signup_cohort, ca.activity_month;