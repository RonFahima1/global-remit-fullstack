-- +goose Up
CREATE SCHEMA IF NOT EXISTS core;
CREATE TABLE IF NOT EXISTS core.account_limits (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    account_id UUID NOT NULL,
    limit_type VARCHAR(50) NOT NULL, -- e.g., 'daily_withdrawal', 'monthly_transfer', etc.
    currency_code CHAR(3) NOT NULL,
    limit_value NUMERIC(20, 4) NOT NULL,
    period VARCHAR(20) NOT NULL, -- e.g., 'daily', 'monthly', 'yearly', 'per_transaction'
    effective_date DATE NOT NULL DEFAULT CURRENT_DATE,
    expiry_date DATE,
    status VARCHAR(20) NOT NULL DEFAULT 'active', -- 'active', 'inactive', 'expired'
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_by UUID,
    updated_by UUID,
    version INTEGER NOT NULL DEFAULT 1
);

CREATE INDEX IF NOT EXISTS idx_account_limits_account_id ON core.account_limits(account_id);
CREATE INDEX IF NOT EXISTS idx_account_limits_limit_type ON core.account_limits(limit_type);
CREATE INDEX IF NOT EXISTS idx_account_limits_status ON core.account_limits(status);

-- +goose Down
DROP TABLE IF EXISTS core.account_limits CASCADE; 