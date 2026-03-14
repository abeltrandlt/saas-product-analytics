-- ============================================
-- Data Quality Validation & Cleaning
-- ============================================
-- Purpose: Validate data integrity and demonstrate cleaning techniques
-- Author: Alberto Beltran
-- Date: 2025-03-14
-- ============================================

-- =====================
-- SECTION 1: VALIDATION CHECKS
-- =====================

-- Check 1: Duplicate user_ids (should return 0 after our cleaning)
SELECT 
    'Duplicate Users' AS check_name,
    COUNT(*) AS issue_count
FROM (
    SELECT user_id, COUNT(*) as dupe_count
    FROM users
    GROUP BY user_id
    HAVING COUNT(*) > 1
) dupes;

-- Check 2: Orphaned events (should return 0)
SELECT 
    'Orphaned Events' AS check_name,
    COUNT(*) AS issue_count
FROM events e
LEFT JOIN users u ON e.user_id = u.user_id
WHERE u.user_id IS NULL;

-- Check 3: Events before signup date (should return 0)
SELECT 
    'Invalid Timestamps' AS check_name,
    COUNT(*) AS issue_count
FROM events e
JOIN users u ON e.user_id = u.user_id
WHERE e.event_timestamp::date < u.signup_date;

-- Check 4: NULL values in key fields
SELECT 
    'NULL Values' AS check_name,
    COUNT(*) FILTER (WHERE country IS NULL) AS null_countries,
    COUNT(*) FILTER (WHERE acquisition_channel IS NULL) AS null_channels,
    COUNT(*) AS total_users
FROM users;

-- Check 5: Payment integrity (subscriptions should have payments)
SELECT 
    'Subscriptions Without Payments' AS check_name,
    COUNT(DISTINCT s.subscription_id) AS issue_count
FROM subscriptions s
LEFT JOIN payments p ON s.subscription_id = p.subscription_id
WHERE s.plan_type != 'free'  -- Free plans shouldn't have payments
  AND p.payment_id IS NULL;


-- =====================
-- SECTION 2: DATA CLEANING DEMONSTRATIONS
-- =====================

-- Demo 1: Standardize country capitalization
SELECT 
    country AS original_country,
    CASE 
        WHEN LOWER(country) = 'us' THEN 'US'
        WHEN LOWER(country) = 'uk' THEN 'UK'
        WHEN LOWER(country) = 'canada' THEN 'Canada'
        WHEN LOWER(country) = 'germany' THEN 'Germany'
        WHEN LOWER(country) = 'france' THEN 'France'
        WHEN LOWER(country) = 'australia' THEN 'Australia'
        ELSE INITCAP(country)  -- Capitalize first letter
    END AS country_clean,
    COUNT(*) AS user_count
FROM users
WHERE country IS NOT NULL
GROUP BY country
ORDER BY user_count DESC;

-- Demo 2: Handle NULL countries
SELECT 
    COALESCE(country, 'Unknown') AS country_clean,
    COUNT(*) AS user_count,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS percentage
FROM users
GROUP BY country
ORDER BY user_count DESC;

-- Demo 3: Deduplication logic (demonstration, not needed for our clean data)
-- This shows HOW you would deduplicate if needed
WITH ranked_users AS (
    SELECT 
        *,
        ROW_NUMBER() OVER (
            PARTITION BY user_id 
            ORDER BY signup_date, created_at
        ) AS row_num
    FROM users
)
SELECT 
    'Total Users' AS metric,
    COUNT(*) AS value
FROM ranked_users
WHERE row_num = 1;  -- Keep only first occurrence


-- =====================
-- SECTION 3: DATA QUALITY SUMMARY
-- =====================

-- Comprehensive data quality report
SELECT 
    'Total Users' AS metric,
    COUNT(*) AS value
FROM users

UNION ALL

SELECT 
    'Total Events',
    COUNT(*)
FROM events

UNION ALL

SELECT 
    'Users with NULL Country',
    COUNT(*) FILTER (WHERE country IS NULL)
FROM users

UNION ALL

SELECT 
    'Users with Events',
    COUNT(DISTINCT user_id)
FROM events

UNION ALL

SELECT 
    'Paid Subscriptions',
    COUNT(*)
FROM subscriptions
WHERE plan_type != 'free'

UNION ALL

SELECT 
    'Failed Payments',
    COUNT(*)
FROM payments
WHERE status = 'failed'

ORDER BY metric;

-- =====================
-- SECTION 4: CREATE CLEAN VIEWS (OPTIONAL)
-- =====================

-- Drop views if they exist (for re-running script)
DROP VIEW IF EXISTS users_clean CASCADE;
DROP VIEW IF EXISTS events_clean CASCADE;

-- Create clean users view
CREATE VIEW users_clean AS
SELECT 
    user_id,
    signup_date,
    CASE 
        WHEN LOWER(country) = 'us' THEN 'US'
        WHEN LOWER(country) = 'uk' THEN 'UK'
        WHEN LOWER(country) = 'canada' THEN 'Canada'
        WHEN LOWER(country) = 'germany' THEN 'Germany'
        WHEN LOWER(country) = 'france' THEN 'France'
        WHEN LOWER(country) = 'australia' THEN 'Australia'
        WHEN LOWER(country) = 'other' THEN 'Other'
        ELSE INITCAP(country)
    END AS country,
    acquisition_channel,
    created_at
FROM users;

-- Create clean events view (removes orphaned events)
CREATE VIEW events_clean AS
SELECT 
    e.event_id,
    e.user_id,
    e.event_type,
    e.event_timestamp,
    LOWER(e.feature_used) AS feature_used,  -- Standardize to lowercase
    e.created_at
FROM events e
INNER JOIN users u ON e.user_id = u.user_id  -- Removes orphaned events
WHERE e.event_timestamp::date >= u.signup_date;  -- Removes invalid timestamps

-- Verify views were created
SELECT 
    table_name,
    CASE 
        WHEN table_type = 'VIEW' THEN 'Clean View Created ✓'
        ELSE table_type
    END as status
FROM information_schema.tables
WHERE table_schema = 'public' 
  AND table_name IN ('users_clean', 'events_clean')
ORDER BY table_name;