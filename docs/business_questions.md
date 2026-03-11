# SaaS Product Analytics — Business Questions

## Project Objective
Understand what drives user engagement, retention, and revenue growth in a SaaS platform to inform product and growth strategy.

---

## Core Analytical Questions

### 1. User Engagement
**Q1.1:** What is our daily active user (DAU) count over time?  
**Q1.2:** What is our monthly active user (MAU) count over time?  
**Q1.3:** What is our stickiness ratio (DAU/MAU)?  
**Q1.4:** Which features are most frequently used?  
**Q1.5:** What is the distribution of user activity levels (power users vs. casual users)?

**Why these matter:** Engagement metrics show whether users find the product valuable. High stickiness (>20%) indicates product-market fit.

---

### 2. User Retention
**Q2.1:** How do signup cohorts retain over time (30-day, 60-day, 90-day retention)?  
**Q2.2:** Which acquisition channels have the highest retention rates?  
**Q2.3:** How does feature adoption in the first week correlate with long-term retention?  
**Q2.4:** How long does it take users to reach their first "aha moment" (first feature use)?

**Why these matter:** Retention is THE key SaaS metric. A 5% improvement in retention can double company value.

---

### 3. Churn Analysis
**Q3.1:** What is our overall churn rate (monthly, quarterly)?  
**Q3.2:** What are the leading indicators of churn? (declining usage, failed payments, low feature adoption)  
**Q3.3:** How does churn vary by plan type (free, starter, professional, enterprise)?  
**Q3.4:** What is the average customer lifetime before churn?

**Why these matter:** Understanding churn drivers allows proactive intervention (e.g., automated emails to at-risk users).

---

### 4. Revenue & Growth
**Q4.1:** What is our Monthly Recurring Revenue (MRR) trend?  
**Q4.2:** What is our Annual Recurring Revenue (ARR)?  
**Q4.3:** What is our expansion revenue (upgrades from Starter → Professional)?  
**Q4.4:** What is our net revenue retention rate?  
**Q4.5:** How does average revenue per user (ARPU) vary by cohort?

**Why these matter:** Revenue metrics determine business health. Expansion revenue (>0% net retention) indicates product growth within existing customer base.

---

### 5. Experimentation (Optional)
**Q5.1:** Did the new onboarding flow (A/B test) improve activation rates?  
**Q5.2:** Which experiment variant had better 30-day retention?

**Why this matters:** Demonstrates ability to measure product experiments — critical for product analyst roles.

---

## Success Metrics Summary

| Category | Key Metric | Target (Industry Benchmark) |
|----------|-----------|---------------------------|
| Engagement | Stickiness (DAU/MAU) | >20% |
| Retention | 90-day retention | >40% |
| Churn | Monthly churn rate | <5% |
| Revenue | Net revenue retention | >100% |

---

## Data Requirements

To answer these questions, we need:
- **User data:** signup date, acquisition channel
- **Event data:** user actions over time (logins, feature usage)
- **Subscription data:** plan type, status changes (upgrades, churn)
- **Payment data:** revenue transactions
- **Experiment data:** A/B test assignments (optional)