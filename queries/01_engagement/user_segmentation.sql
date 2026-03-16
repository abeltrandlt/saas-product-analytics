-- ============================================
-- User Activity Segmentation Analysis
-- ============================================
-- Business Question: How do users break down by engagement level?
-- Segments: Power, Casual, At-Risk, Dormant
-- Author: Alberto Beltran
-- Date: 2025-03-16
-- ============================================

-- STEP 0: Find the latest date in the dataset (our "analysis date")
WITH dataset_dates AS (
    SELECT 
        MAX(DATE(event_timestamp)) AS analysis_date
    FROM events
),

-- STEP 1: Calculate engagement metrics per user
user_activity AS (
    SELECT 
        u.user_id,
        u.signup_date,
        u.country,
        u.acquisition_channel,
        COUNT(e.event_id) AS total_events,
        COUNT(DISTINCT DATE(e.event_timestamp)) AS days_active,
        MIN(DATE(e.event_timestamp)) AS first_event_date,
        MAX(DATE(e.event_timestamp)) AS last_event_date,
        -- Use dataset max date instead of CURRENT_DATE
        (SELECT analysis_date FROM dataset_dates) - MAX(DATE(e.event_timestamp)) AS days_since_last_event
    FROM users u
    LEFT JOIN events e ON u.user_id = e.user_id
    WHERE e.event_type IN ('login', 'feature_use')  -- Active events only
    GROUP BY u.user_id, u.signup_date, u.country, u.acquisition_channel
),

-- STEP 2: Calculate percentiles for segmentation thresholds
activity_percentiles AS (
    SELECT 
        PERCENTILE_CONT(0.80) WITHIN GROUP (ORDER BY total_events) AS p80_events,
        PERCENTILE_CONT(0.20) WITHIN GROUP (ORDER BY total_events) AS p20_events
    FROM user_activity
),

-- STEP 3: Assign users to segments
user_segments AS (
    SELECT 
        ua.*,
        CASE 
            -- Power users: Top 20% by event count, active recently
            WHEN ua.total_events >= ap.p80_events 
                 AND ua.days_since_last_event <= 30 
            THEN 'Power'
            
            -- Dormant: Bottom 20% by event count
            WHEN ua.total_events <= ap.p20_events 
            THEN 'Dormant'
            
            -- At-risk: Haven't been active in 30+ days
            WHEN ua.days_since_last_event > 30 
            THEN 'At-Risk'
            
            -- Casual: Everyone else (middle 60%, active recently)
            ELSE 'Casual'
        END AS user_segment,
        
        -- Calculate events per active day (intensity)
        CASE 
            WHEN ua.days_active > 0 
            THEN ROUND(ua.total_events::NUMERIC / ua.days_active, 2)
            ELSE 0 
        END AS events_per_active_day
    FROM user_activity ua
    CROSS JOIN activity_percentiles ap
)

-- STEP 4: Segment summary statistics
SELECT 
    user_segment,
    COUNT(*) AS user_count,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS percentage_of_users,
    ROUND(AVG(total_events), 2) AS avg_total_events,
    ROUND(AVG(days_active), 2) AS avg_days_active,
    ROUND(AVG(events_per_active_day), 2) AS avg_event_intensity,
    ROUND(AVG(days_since_last_event), 2) AS avg_days_since_last_event,
    MIN(total_events) AS min_events,
    MAX(total_events) AS max_events
FROM user_segments
GROUP BY user_segment
ORDER BY 
    CASE user_segment
        WHEN 'Power' THEN 1
        WHEN 'Casual' THEN 2
        WHEN 'At-Risk' THEN 3
        WHEN 'Dormant' THEN 4
    END;

-- Add analysis date context
SELECT 
    'Analysis Date (Dataset End)' AS metric,
    TO_CHAR(analysis_date, 'YYYY-MM-DD') AS value
FROM dataset_dates;


-- (Optional Extension - Segment trends over time)
-- Add signup month to see if newer cohorts have better engagement
SELECT 
    DATE_TRUNC('month', signup_date) AS signup_month,
    user_segment,
    COUNT(*) AS user_count
FROM user_segments
GROUP BY DATE_TRUNC('month', signup_date), user_segment
ORDER BY signup_month, user_segment;


-- (Optional Extension - Segments by acquisition channel)
SELECT 
    acquisition_channel,
    user_segment,
    COUNT(*) AS user_count
FROM user_segments
GROUP BY acquisition_channel, user_segment
ORDER BY acquisition_channel, user_segment;