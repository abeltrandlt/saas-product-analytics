-- SaaS Product Analytics Database Schema
-- Generated: 2026-03-05
-- Author: Alberto Beltran

-- ====================================
-- USERS TABLE
-- ====================================
-- Core user demographics and acquisition info

CREATE TABLE users (
    user_id VARCHAR(36) PRIMARY KEY,
    signup_date DATE NOT NULL,
    country VARCHAR(50),
    acquisition_channel VARCHAR(50),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Why VARCHAR(36)? UUID format (8-4-4-4-12 = 36 chars including hyphens)
-- Why allow NULL on country? Some users might not provide location
-- acquisition_channel examples: organic, paid_search, referral, affiliate, unknown


-- ====================================
-- EVENTS TABLE
-- ====================================
-- User activity log — tracks every action

CREATE TABLE events (
    event_id SERIAL PRIMARY KEY,
    user_id VARCHAR(36) NOT NULL,
    event_type VARCHAR(50) NOT NULL,
    event_timestamp TIMESTAMP NOT NULL,
    feature_used VARCHAR(50),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE
);

-- Why SERIAL for event_id? Auto-incrementing integer (simple, efficient)
-- event_type examples: login, feature_use, upgrade_click, settings_change, support_ticket
-- Why feature_used is nullable? Not all events involve a feature (e.g., login)
-- ON DELETE CASCADE: if user deleted, delete their events too


-- ====================================
-- SUBSCRIPTIONS TABLE
-- ====================================
-- Plan lifecycle tracking

CREATE TABLE subscriptions (
    subscription_id VARCHAR(36) PRIMARY KEY,
    user_id VARCHAR(36) NOT NULL,
    plan_type VARCHAR(50) NOT NULL,
    start_date DATE NOT NULL,
    end_date DATE,
    status VARCHAR(20) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE
);

-- plan_type examples: free, starter, professional, enterprise
-- status examples: active, churned, upgraded, downgraded
-- Why end_date is nullable? Active subscriptions have no end date
-- A user can have multiple subscriptions over time (lifecycle tracking)


-- ====================================
-- PAYMENTS TABLE
-- ====================================
-- Revenue transactions

CREATE TABLE payments (
    payment_id SERIAL PRIMARY KEY,
    subscription_id VARCHAR(36) NOT NULL,
    payment_date DATE NOT NULL,
    amount DECIMAL(10,2) NOT NULL,
    status VARCHAR(20) DEFAULT 'successful',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (subscription_id) REFERENCES subscriptions(subscription_id) ON DELETE CASCADE
);

-- status examples: successful, failed, refunded
-- Why DECIMAL(10,2)? Precise for currency (10 digits total, 2 after decimal)
-- amount can be negative (refunds)


-- ====================================
-- EXPERIMENTS TABLE (Optional)
-- ====================================
-- A/B test assignments

CREATE TABLE experiments (
    experiment_id SERIAL PRIMARY KEY,
    user_id VARCHAR(36) NOT NULL,
    experiment_name VARCHAR(100) NOT NULL,
    variant VARCHAR(50) NOT NULL,
    assignment_date DATE NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE
);

-- experiment_name examples: onboarding_v2, pricing_test_2024, feature_rollout_q1
-- variant examples: control, treatment_a, treatment_b
-- Users can be in multiple experiments simultaneously


-- ====================================
-- INDEXES (for query performance)
-- ====================================
-- Add indexes on frequently queried columns

CREATE INDEX idx_events_user_timestamp ON events(user_id, event_timestamp);
CREATE INDEX idx_events_timestamp ON events(event_timestamp);
CREATE INDEX idx_subscriptions_user ON subscriptions(user_id);
CREATE INDEX idx_subscriptions_status ON subscriptions(status);
CREATE INDEX idx_payments_subscription ON payments(subscription_id);
CREATE INDEX idx_payments_date ON payments(payment_date);

-- Why these indexes?
-- - user_id + timestamp: fast cohort retention queries
-- - timestamp: fast time-series aggregations (DAU, MRR)
-- - status: fast filtering (active subscriptions, churned users)