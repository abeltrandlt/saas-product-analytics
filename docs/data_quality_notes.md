# Data Quality Issues — SaaS Analytics Dataset

## Overview
This dataset intentionally includes realistic data quality issues to demonstrate SQL cleaning skills.

---

## Known Issues & Resolutions

### 1. Duplicate User IDs (~1.5% of users)
**Issue:** Some user_id values appear multiple times in the users table  
**Root Cause:** Simulates data pipeline errors (retry logic, race conditions)  
**Impact:** ~15 duplicate records in the 1,015 user dataset  
**Resolution Strategy:**
```sql
-- Identify duplicates
SELECT user_id, COUNT(*) 
FROM users 
GROUP BY user_id 
HAVING COUNT(*) > 1;

-- Keep earliest signup (deduplicate)
WITH ranked_users AS (
  SELECT *, ROW_NUMBER() OVER (PARTITION BY user_id ORDER BY signup_date) AS rn
  FROM users
)
SELECT * FROM ranked_users WHERE rn = 1;
```

---

### 2. Events with Timestamps Before Signup Date (~1% of events)
**Issue:** Some events have event_timestamp < user's signup_date  
**Root Cause:** Clock skew, timezone issues, data pipeline bugs  
**Impact:** ~1,734 events in the 173K event dataset  
**Resolution Strategy:**
```sql
-- Identify invalid events
SELECT e.event_id, e.user_id, e.event_timestamp, u.signup_date
FROM events e
JOIN users u ON e.user_id = u.user_id
WHERE e.event_timestamp::date < u.signup_date;

-- Filter out in analysis
WHERE event_timestamp::date >= signup_date
```

---

### 3. Orphaned Events (~1% of events)
**Issue:** Events with user_id that doesn't exist in users table  
**Root Cause:** User deletion, data sync issues between systems  
**Impact:** ~1,734 orphaned events  
**Resolution Strategy:**
```sql
-- Identify orphaned events
SELECT e.* 
FROM events e
LEFT JOIN users u ON e.user_id = u.user_id
WHERE u.user_id IS NULL;

-- Exclude from user-level analysis
FROM events e
INNER JOIN users u ON e.user_id = u.user_id  -- Use INNER JOIN
```

---

### 4. Inconsistent Country Capitalization (~5% of records)
**Issue:** Country names have mixed capitalization ("US", "us", "United States")  
**Root Cause:** Manual data entry, inconsistent form validation  
**Impact:** Complicates grouping and aggregation  
**Resolution Strategy:**
```sql
-- Standardize capitalization
SELECT 
  CASE 
    WHEN LOWER(country) = 'us' THEN 'US'
    WHEN LOWER(country) = 'uk' THEN 'UK'
    WHEN LOWER(country) = 'canada' THEN 'Canada'
    ELSE INITCAP(country)
  END AS country_clean
FROM users;
```

---

### 5. NULL Country Values (~2% of users)
**Issue:** Some users have NULL country  
**Root Cause:** Optional field in signup form, users skipped  
**Impact:** ~20 NULL values in the 1,015 user dataset  
**Resolution Strategy:**
```sql
-- Handle NULLs in aggregation
SELECT 
  COALESCE(country, 'Unknown') AS country,
  COUNT(*) AS user_count
FROM users
GROUP BY country;
```

---

### 6. Inconsistent Feature Name Capitalization (~5% of feature_use events)
**Issue:** feature_used values have mixed case ("dashboard" vs "DASHBOARD")  
**Root Cause:** Inconsistent event logging across application versions  
**Impact:** Splits feature usage counts  
**Resolution Strategy:**
```sql
-- Standardize to lowercase
SELECT LOWER(feature_used) AS feature_clean
FROM events
WHERE feature_used IS NOT NULL;
```

---

### 7. Failed Payments (~3% of payments)
**Issue:** Some payments have status = 'failed'  
**Root Cause:** Expired credit cards, insufficient funds  
**Impact:** ~580 failed payments in the 19,332 payment dataset  
**Resolution Strategy:**
```sql
-- Exclude from MRR calculation
SELECT SUM(amount) AS mrr
FROM payments
WHERE status = 'successful'  -- Only count successful
  AND payment_date = '2024-12-01';
```

---

### 8. Refunded Payments (~1% of payments, negative amounts)
**Issue:** Some payments have negative amounts (refunds)  
**Root Cause:** Customer disputes, service issues  
**Impact:** ~193 refunds  
**Resolution Strategy:**
```sql
-- Net revenue (includes refunds)
SELECT SUM(amount) AS net_revenue
FROM payments
WHERE status IN ('successful', 'refunded');

-- Gross revenue (excludes refunds)
SELECT SUM(amount) AS gross_revenue
FROM payments
WHERE status = 'successful';
```

---

## Data Validation Queries

Run these to verify data quality after cleaning:
```sql
-- No duplicate user_ids
SELECT COUNT(*) = COUNT(DISTINCT user_id) FROM users_clean;

-- No events before signup
SELECT COUNT(*) FROM events e
JOIN users u ON e.user_id = u.user_id
WHERE e.event_timestamp::date < u.signup_date;
-- Should return 0

-- No orphaned events
SELECT COUNT(*) FROM events e
LEFT JOIN users u ON e.user_id = u.user_id
WHERE u.user_id IS NULL;
-- Should return 0

-- All countries standardized
SELECT DISTINCT country FROM users_clean ORDER BY country;
-- Should show consistent capitalization
```

---

## Summary Statistics

**Dataset:** 1,015 users  
**Total Events:** 173,364  
**Total Subscriptions:** 1,786  
**Total Payments:** 19,332  
**Total Quality Issues:** ~3,500 records affected (~2% of total dataset)  
**Most Common Issue:** Orphaned events (~1,734 records)

These issues mirror real-world SaaS data pipelines and provide opportunities to demonstrate:
- Data cleaning with SQL (CASE statements, deduplication, NULL handling)
- JOIN strategy (INNER vs LEFT to handle orphaned records)
- Data validation (constraint checking, referential integrity)