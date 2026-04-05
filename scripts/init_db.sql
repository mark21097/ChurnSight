-- Manual init (same as data/sql/schema.sql). Prefer: psql -f data/sql/schema.sql

CREATE TABLE IF NOT EXISTS subscribers (
    id SERIAL PRIMARY KEY,
    subscriber_id VARCHAR(36) NOT NULL UNIQUE,
    tenure_months INTEGER NOT NULL CHECK (tenure_months >= 0),
    monthly_charges DOUBLE PRECISION NOT NULL,
    total_charges DOUBLE PRECISION NOT NULL,
    subscription_plan VARCHAR(32) NOT NULL,
    contract_type VARCHAR(32) NOT NULL,
    num_support_tickets INTEGER NOT NULL DEFAULT 0 CHECK (num_support_tickets >= 0),
    avg_monthly_usage DOUBLE PRECISION NOT NULL,
    last_login_at TIMESTAMP NULL,
    account_created_at TIMESTAMP NOT NULL,
    had_plan_change SMALLINT NOT NULL DEFAULT 0 CHECK (had_plan_change IN (0, 1)),
    churned SMALLINT NOT NULL CHECK (churned IN (0, 1))
);

CREATE INDEX IF NOT EXISTS idx_subscribers_churned ON subscribers (churned);
