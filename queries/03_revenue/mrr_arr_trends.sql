-- ============================================
-- MRR & ARR Trends Analysis
-- ============================================
-- Business Question: What is our monthly/annual recurring revenue?
-- Analysis: MRR growth, ARR calculation, revenue by plan type
-- Author: Alberto Beltran
-- Date: 2026-03-24
-- ============================================

-- STEP 1: Define pricing (you can adjust these based on actual prices)
WITH pricing AS (
    SELECT 
        'starter' AS plan_type, 29.00 AS monthly_price
    UNION ALL
    SELECT 'professional', 99.00
    UNION ALL
    SELECT 'enterprise', 499.00
),

-- STEP 2: Generate month series from first to last subscription
month_series AS (
    SELECT 
        DATE_TRUNC('month', generate_series(
            (SELECT MIN(start_date) FROM subscriptions),
            (SELECT MAX(COALESCE(end_date, CURRENT_DATE)) FROM subscriptions),
            '1 month'::interval
        )) AS month
),

-- STEP 3: Calculate active subscriptions per month
active_subs_per_month AS (
    SELECT 
        ms.month,
        s.subscription_id,
        s.user_id,
        s.plan_type,
        s.start_date,
        s.end_date,
        s.status,
        p.monthly_price
    FROM month_series ms
    CROSS JOIN subscriptions s
    LEFT JOIN pricing p ON s.plan_type = p.plan_type
    WHERE s.plan_type != 'free'  -- Exclude free plans
      AND s.start_date <= ms.month + INTERVAL '1 month' - INTERVAL '1 day'  -- Started before month end
      AND (s.end_date IS NULL OR s.end_date >= ms.month)  -- Active or ended after month start
      AND s.status IN ('active', 'churned')  -- Include both for full picture
),

-- STEP 4: Calculate MRR by month and plan
mrr_by_month AS (
    SELECT 
        month,
        plan_type,
        COUNT(DISTINCT subscription_id) AS active_subscriptions,
        COUNT(DISTINCT user_id) AS paying_customers,
        SUM(monthly_price) AS mrr
    FROM active_subs_per_month
    WHERE status = 'active'  -- Only active for current MRR
    GROUP BY month, plan_type
)

-- =============================================
-- PART 1: Overall MRR Trends
-- =============================================
SELECT 
    month,
    SUM(active_subscriptions) AS total_active_subs,
    SUM(paying_customers) AS total_paying_customers,
    SUM(mrr) AS total_mrr,
    SUM(mrr) * 12 AS arr,
    -- Month-over-month growth
    LAG(SUM(mrr)) OVER (ORDER BY month) AS prev_month_mrr,
    SUM(mrr) - LAG(SUM(mrr)) OVER (ORDER BY month) AS mrr_change,
    ROUND(
        100.0 * (SUM(mrr) - LAG(SUM(mrr)) OVER (ORDER BY month)) / 
        NULLIF(LAG(SUM(mrr)) OVER (ORDER BY month), 0), 
        2
    ) AS mrr_growth_pct
FROM mrr_by_month
GROUP BY month
ORDER BY month;


-- =============================================
-- PART 2: MRR by Plan Type
-- =============================================
SELECT 
    month,
    plan_type,
    active_subscriptions,
    paying_customers,
    mrr,
    ROUND(100.0 * mrr / SUM(mrr) OVER (PARTITION BY month), 2) AS pct_of_mrr
FROM mrr_by_month
ORDER BY month, plan_type;


-- =============================================
-- PART 3: MRR Summary Statistics
-- =============================================
monthly_mrr AS (
    SELECT 
        month,
        SUM(mrr) AS total_mrr
    FROM mrr_by_month
    GROUP BY month
)
SELECT 
    'Total Months' AS metric,
    COUNT(*)::TEXT AS value
FROM monthly_mrr

UNION ALL

-- Wrap in subselect to allow ORDER BY + LIMIT
SELECT 'Peak MRR Month', TO_CHAR(month, 'YYYY-MM')
FROM (
    SELECT month, total_mrr
    FROM monthly_mrr
    ORDER BY total_mrr DESC
    LIMIT 1
) peak_month

UNION ALL

SELECT 
    'Peak MRR Amount',
    '$' || ROUND(MAX(total_mrr), 2)::TEXT
FROM monthly_mrr

UNION ALL

-- Wrap in subselect to allow ORDER BY + LIMIT
SELECT 'Current MRR', '$' || ROUND(total_mrr, 2)::TEXT
FROM (
    SELECT month, total_mrr
    FROM monthly_mrr
    ORDER BY month DESC
    LIMIT 1
) current_mrr

UNION ALL

-- Wrap in subselect to allow ORDER BY + LIMIT
SELECT 'Current ARR', '$' || ROUND(total_mrr * 12, 2)::TEXT
FROM (
    SELECT month, total_mrr
    FROM monthly_mrr
    ORDER BY month DESC
    LIMIT 1
) current_arr

UNION ALL

SELECT 
    'Avg MoM Growth Rate',
    ROUND(AVG(growth_rate), 2)::TEXT || '%'
FROM (
    SELECT 
        100.0 * (total_mrr - LAG(total_mrr) OVER (ORDER BY month)) / 
        NULLIF(LAG(total_mrr) OVER (ORDER BY month), 0) AS growth_rate
    FROM monthly_mrr
) growth;