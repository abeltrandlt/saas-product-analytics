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
- 10,000 users
- 100,000+ user events
- 12,000 subscriptions
- 50,000+ payments
- Simulated using Python (realistic behavioral patterns)

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
- [ ] Day 2: Data generation + import
- [ ] Day 3: Core SQL queries (engagement)
- [ ] Day 4: Retention + cohort analysis
- [ ] Day 5: Revenue metrics
- [ ] Day 6: Tableau dashboard
- [ ] Day 7: Documentation + LinkedIn post

---

## SQL Techniques Demonstrated

- Complex JOINs (4+ table joins)
- Common Table Expressions (CTEs)
- Window functions (LAG, LEAD, ROW_NUMBER, RANK)
- Cohort retention analysis
- Date calculations and time-series aggregations

---

## Key Insights

*(To be updated as analysis progresses)*

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