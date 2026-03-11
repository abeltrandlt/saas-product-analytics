# Data Dictionary — SaaS Product Analytics

## users

| Column | Type | Description | Example Values | Constraints |
|--------|------|-------------|---------------|-------------|
| user_id | VARCHAR(36) | Unique identifier (UUID format) | `a1b2c3d4-e5f6-...` | PRIMARY KEY, NOT NULL |
| signup_date | DATE | Date user created account | `2024-03-15` | NOT NULL |
| country | VARCHAR(50) | User's country (ISO code or name) | `US`, `UK`, `Canada` | Nullable (~2% NULL) |
| acquisition_channel | VARCHAR(50) | How user discovered product | `organic`, `paid_search`, `referral`, `affiliate`, `unknown` | Nullable |
| created_at | TIMESTAMP | Record creation timestamp | `2024-03-15 14:23:01` | DEFAULT CURRENT_TIMESTAMP |

**Business Logic:**
- `country` may be NULL if user didn't provide location
- `acquisition_channel = 'unknown'` indicates missing attribution data

---

## events

| Column | Type | Description | Example Values | Constraints |
|--------|------|-------------|---------------|-------------|
| event_id | SERIAL | Auto-incrementing event ID | `1`, `2`, `3`, ... | PRIMARY KEY |
| user_id | VARCHAR(36) | User who triggered event | `a1b2c3d4-e5f6-...` | FOREIGN KEY → users.user_id |
| event_type | VARCHAR(50) | Type of action | `login`, `feature_use`, `upgrade_click`, `settings_change` | NOT NULL |
| event_timestamp | TIMESTAMP | When event occurred | `2024-03-15 14:23:01` | NOT NULL |
| feature_used | VARCHAR(50) | Feature accessed (if applicable) | `dashboard`, `reporting`, `integrations`, `api_access` | Nullable |
| created_at | TIMESTAMP | Record creation timestamp | `2024-03-15 14:23:01` | DEFAULT CURRENT_TIMESTAMP |

**Business Logic:**
- `feature_used` is NULL for events that don't involve features (e.g., `login`, `support_ticket`)
- `event_timestamp` should be >= user's `signup_date` (data quality check)

---

## subscriptions

| Column | Type | Description | Example Values | Constraints |
|--------|------|-------------|---------------|-------------|
| subscription_id | VARCHAR(36) | Unique subscription ID (UUID) | `b2c3d4e5-f6a7-...` | PRIMARY KEY |
| user_id | VARCHAR(36) | User who owns subscription | `a1b2c3d4-e5f6-...` | FOREIGN KEY → users.user_id |
| plan_type | VARCHAR(50) | Subscription tier | `free`, `starter`, `professional`, `enterprise` | NOT NULL |
| start_date | DATE | Subscription start date | `2024-03-15` | NOT NULL |
| end_date | DATE | Subscription end date | `2024-09-15` or NULL | Nullable (NULL = active) |
| status | VARCHAR(20) | Current status | `active`, `churned`, `upgraded`, `downgraded` | NOT NULL |
| created_at | TIMESTAMP | Record creation timestamp | `2024-03-15 14:23:01` | DEFAULT CURRENT_TIMESTAMP |

**Business Logic:**
- `end_date = NULL` indicates subscription is currently active
- Users can have multiple subscriptions over time (lifecycle: free → starter → churned → starter)
- `status = 'upgraded'` means this subscription was upgraded to a higher-tier plan (check for newer subscription with same user_id)

---

## payments

| Column | Type | Description | Example Values | Constraints |
|--------|------|-------------|---------------|-------------|
| payment_id | SERIAL | Auto-incrementing payment ID | `1`, `2`, `3`, ... | PRIMARY KEY |
| subscription_id | VARCHAR(36) | Subscription being paid for | `b2c3d4e5-f6a7-...` | FOREIGN KEY → subscriptions.subscription_id |
| payment_date | DATE | Date payment processed | `2024-03-15` | NOT NULL |
| amount | DECIMAL(10,2) | Payment amount (USD) | `29.99`, `-29.99` (refund) | NOT NULL |
| status | VARCHAR(20) | Payment status | `successful`, `failed`, `refunded` | DEFAULT 'successful' |
| created_at | TIMESTAMP | Record creation timestamp | `2024-03-15 14:23:01` | DEFAULT CURRENT_TIMESTAMP |

**Business Logic:**
- Negative `amount` indicates refunds
- `status = 'failed'` means payment attempt failed (subscription may still be active during grace period)
- Monthly subscriptions generate payments on the same day each month

---

## experiments

| Column | Type | Description | Example Values | Constraints |
|--------|------|-------------|---------------|-------------|
| experiment_id | SERIAL | Auto-incrementing experiment ID | `1`, `2`, `3`, ... | PRIMARY KEY |
| user_id | VARCHAR(36) | User assigned to experiment | `a1b2c3d4-e5f6-...` | FOREIGN KEY → users.user_id |
| experiment_name | VARCHAR(100) | Name of A/B test | `onboarding_v2`, `pricing_test_2024` | NOT NULL |
| variant | VARCHAR(50) | Which variant user saw | `control`, `treatment_a`, `treatment_b` | NOT NULL |
| assignment_date | DATE | Date user entered experiment | `2024-03-15` | NOT NULL |
| created_at | TIMESTAMP | Record creation timestamp | `2024-03-15 14:23:01` | DEFAULT CURRENT_TIMESTAMP |

**Business Logic:**
- Users can be in multiple experiments simultaneously
- `variant = 'control'` is the baseline (no changes)
- Assignment should occur around signup_date for onboarding experiments