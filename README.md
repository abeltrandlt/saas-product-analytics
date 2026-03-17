# SaaS Product Analytics: User Engagement, Retention, and Revenue Growth

**Author:** Alberto Beltran  
**Tools:** Python, PostgreSQL, Tableau  
**Project Timeline:** 7 days

---

## Project Overview

This project analyzes user engagement, retention, and revenue patterns in a simulated SaaS platform to answer key business questions:

- What drives user retention?
- Which features correlate with long-term engagement?
- What are the leading indicators of churn?
- How does revenue expand within customer cohorts?

**Status:** 🚧 In Progress — Day 1/7 Complete

---

## Business Questions

See [docs/business_questions.md](docs/business_questions.md) for full list of analytical questions.

**Core focus areas:**
1. User engagement (DAU, MAU, stickiness)
2. Cohort retention analysis
3. Churn prediction and prevention
4. Revenue metrics (MRR, ARR, net retention)

---

## Dataset

**Scope:**
- 1,015 users (includes 15 intentional duplicates)
- 173,364 user events (behavioral patterns: power/casual/at-risk/dormant)
- 1,786 subscriptions (free → paid → upgrades lifecycle)
- 19,332 payments (realistic failure/refund rates)
- Generated using Python with intentional quality issues for SQL practice

**Schema:** See [schema.sql](schema.sql) or [ERD diagram](docs/erd_diagram.png)

---

## Project Structure
```
saas-product-analytics/
├── data/                    # CSV data files (not committed)
├── docs/                    # Documentation
│   ├── business_questions.md
│   ├── data_dictionary.md
│   └── erd_diagram.png
├── queries/                 # SQL queries by topic
├── scripts/                 # Python data generation & analysis
├── visualizations/          # Tableau dashboard
├── README.md
└── schema.sql               # Database schema
```

---

## Progress Tracker

- [x] Day 1: Problem framing + schema design
- [x] Day 2: Data generation + export ✅ COMPLETE
- [x] Day 3: Core SQL queries (engagement)
- [ ] Day 4: Retention + cohort analysis
- [ ] Day 5: Revenue metrics
- [ ] Day 6: Tableau dashboard
- [ ] Day 7: Documentation + LinkedIn post

---

## SQL Queries

### Engagement Analysis (queries/01_engagement/)

**Purpose:** Understand user engagement patterns, feature adoption, and activity segmentation to identify product health and churn drivers.

**Queries (run in this order):**

#### 1. data_quality_checks.sql
**Purpose:** Validate data integrity before analysis

**SQL Techniques:**
- COUNT with FILTER clause for conditional aggregations
- COALESCE for NULL handling
- CASE statements for data standardization
- ROW_NUMBER() OVER (PARTITION BY) for deduplication logic

**Key Findings:**
- ✅ Data is clean: 0 duplicates, 0 orphaned events, 0 invalid timestamps
- ⚠️ 17 NULL countries (~2% of users) handled via COALESCE
- ✅ 1,000 users, 170,218 events, 1,786 subscriptions, 19,332 payments validated

---

#### 2. dau_mau_stickiness.sql
**Purpose:** Calculate core engagement metrics

**SQL Techniques:**
- CTEs (Common Table Expressions) for multi-step logic
- Window functions: AVG() OVER for 7-day moving average
- DATE functions: DATE(), DATE_TRUNC('month')
- Filtering active events (login, feature_use) vs passive events

**Key Findings:**
- **Growth Phase (2022):** MAU grew 50 → 796 (16x growth), stickiness improved 14% → 20%
- **Crossed healthy threshold:** Stickiness reached 20.38% in Nov 2022 (industry benchmark: 20%+)
- **Decline Phase (2023):** MAU collapsed 796 → 14 (98% decline), suggesting severe retention crisis
- **Plateau timing:** Growth stalled Q4 2022, decline accelerated throughout 2023

**Business Insight:** Product achieved product-market fit in 2022 but experienced catastrophic churn in 2023.

---

#### 3. feature_usage.sql
**Purpose:** Rank features by adoption and usage intensity

**SQL Techniques:**
- CROSS JOIN to attach total user count to all rows
- RANK() OVER (ORDER BY) for feature ranking
- Type casting (::NUMERIC) for decimal division
- NULL filtering (WHERE feature_used IS NOT NULL)

**Key Findings:**
- **Balanced adoption:** All features at 74-76% adoption (no clear winner or loser)
- **Top features:** integrations (4,223 uses), api_access (4,221), analytics (4,218)
- **Usage intensity:** ~5.5 events per user across all features (broad exploration)
- **Growth trend:** Feature usage increased Jan → Mar 2022, api_access spiked in March (101 uses)

**Business Insight:** Well-designed product with balanced feature set; no underperforming features to deprecate.

---

#### 4. user_segmentation.sql
**Purpose:** Segment users by activity level (Power/Casual/At-Risk/Dormant)

**SQL Techniques:**
- PERCENTILE_CONT for dynamic segmentation thresholds (80th/20th percentile)
- Complex CASE logic with multiple conditions
- CURRENT_DATE replaced with dataset max date for historical analysis
- Recency calculation: days_since_last_event
- Window functions for percentage calculations

**Key Findings:**
- **Power Users (2.4%):** Only 23 users highly engaged (179 avg events, active 142 days)
- **Casual Users (6.4%):** 62 users with moderate engagement (vs. healthy benchmark: 50-60%)
- **At-Risk (70.6%):** 686 users inactive 5+ months despite prior engagement (avg 85 events)
- **Dormant (20.6%):** 200 users never activated (2.5 events, inactive 8 months)

**Critical Finding:** **Retention crisis** — 71% of users are at-risk. Small power user base (2.4% vs. healthy 10-20%) and weak casual segment indicate severe churn problem, not acquisition problem.

**Business Recommendations:**
- Immediate: Win-back campaign for 686 at-risk users
- Short-term: Interview 23 power users to identify retention drivers
- Long-term: Improve activation (reduce 21% dormancy to <10%)

---

#### 5. engagement_trends.sql
**Purpose:** Analyze engagement patterns over time (weekly, daily, monthly, cohort)

**SQL Techniques:**
- LAG() window function for week-over-week and month-over-month growth
- NULLIF() to prevent division by zero errors
- TO_CHAR() for day-of-week extraction
- EXTRACT(DOW) for chronological day ordering
- Moving averages: ROWS BETWEEN n PRECEDING AND CURRENT ROW
- Cohort retention analysis with multi-table JOINs

**Part 1: Weekly Engagement Trends**
- **Growth Phase:** 12 WAU (Jan 2022) → 560 WAU (Oct 2022) = 47x growth
- **Peak:** October 2022 at 560 weekly active users
- **Decline:** 560 WAU → 12 WAU (98% decline over 12 months)
- **WoW growth:** +100%+ early 2022, stabilized to 5-10%, turned negative Nov 2022

**Part 2: Day-of-Week Patterns**
- **NO weekday effect:** All days average 88-91 DAU (only 2.5% variance)
- **Saturday highest:** 90.51 avg DAU (B2C product, not B2B)
- **Implication:** Product is "always on" — no work hours pattern

**Part 3: Month-over-Month Growth Analysis**
- **Inflection point:** Nov 2022 first MoM decline (-1.4%)
- **Acceleration:** Feb 2023 began double-digit declines (-11%)
- **Death spiral:** Jun-Oct 2023 losing 20-87% monthly
- **Final month:** Oct 2023 = -87% MoM (total collapse)

**Part 4: Cohort Retention Trends**
- **Excellent early retention:** Jan-Jul 2022 cohorts showed 75-85% retention after 12 months (world-class)
- **Synchronized churn:** All cohorts churned at exactly the 12-month mark
  - Jan 2022 cohort: Churned Jan 2023 (75% → 58%)
  - Feb 2022 cohort: Churned Feb 2023 (84% → 64%)
  - Pattern consistent across all cohorts

**Critical Discovery:** Churn is NOT gradual decay — it's a **lifecycle event at 12 months**.

**Root Cause Analysis:**
- **Most likely:** Annual subscription renewals (users signed up, stayed 12 months, didn't renew)
- **Supporting evidence:** Perfect 12-month offset, simultaneous churn across cohorts, 76% on paid plans
- **Secondary factor:** Possible competitor launch Q4 2022 (timing aligns with plateau)

**Business Insight:** Product had strong retention (75-85%) throughout the first year, then mass exodus at renewal. This suggests **pricing or competitive pressure at renewal**, not product quality issues during the user lifecycle.

---

## SQL Techniques Demonstrated

- Complex JOINs (4+ table joins)
- Common Table Expressions (CTEs)
- Window functions (LAG, LEAD, ROW_NUMBER, RANK)
- Cohort retention analysis
- Date calculations and time-series aggregations
- CTEs for readable multi-step queries
- Window functions (RANK, LAG, ROW_NUMBER, moving averages)
- Date manipulation (DATE_TRUNC, EXTRACT, date arithmetic)
- Aggregations with conditional logic (COUNT FILTER, CASE statements)
- JOINs across multiple tables (users, events, subscriptions)
- Percentile functions (PERCENTILE_CONT)
- Type casting and NULL handling (::NUMERIC, NULLIF, COALESCE)

---

## Key Insights

*(To be updated as analysis progresses)*
### Summary: The Complete Story

**2022 (Growth Year):**
- ✅ Explosive growth: 50 → 796 MAU (16x)
- ✅ Stickiness improved: 14% → 20% (crossed healthy threshold)
- ✅ Strong cohort retention: 75-85% after 12 months
- ✅ Balanced feature adoption: All features 74-76% usage

**Q4 2022 (Warning Signs):**
- ⚠️ First MoM decline: Nov 2022 (-1.4%)
- ⚠️ Growth plateau: MAU flat at ~780-800
- ⚠️ User segmentation worsening: Power users shrinking

**2023 (Collapse Year):**
- ❌ MAU declined 98% (796 → 14)
- ❌ 71% of users at-risk (inactive 5+ months)
- ❌ All cohorts churned at 12-month renewal
- ❌ Death spiral: -87% MoM in final month

**Key Takeaway:** Product achieved product-market fit in 2022 but failed at annual renewal in 2023, likely due to pricing issues or competitive pressure. The 23 remaining power users suggest a niche value proposition worth exploring for a focused pivot.

---

## How to Use This Repository

1. **Clone the repo:**
```bash
   git clone https://github.com/yourusername/saas-product-analytics.git
```

2. **Set up PostgreSQL database:**
```bash
   psql -U postgres -f schema.sql
```

3. **Generate data:**
```bash
   python scripts/generate_saas_data.py
```

4. **Run queries:**
```bash
   psql -U postgres -d saas_analytics -f queries/01_engagement/dau_mau.sql
```

---

## Contact

**Alberto Beltran**  
[LinkedIn](https://www.linkedin.com/in/alberto-beltran-analyst) | [GitHub](https://github.com/abeltrandlt)