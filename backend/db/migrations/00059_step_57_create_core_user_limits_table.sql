-- +goose Up
CREATE SCHEMA IF NOT EXISTS core;
CREATE TABLE IF NOT EXISTS core.user_limits (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL,
    limit_type VARCHAR(50) NOT NULL, -- e.g., 'daily_approval', 'transaction_approval', etc.
    currency_code CHAR(3) NOT NULL,
    limit_value NUMERIC(20, 4) NOT NULL,
    period VARCHAR(20) NOT NULL, -- e.g., 'daily', 'monthly', 'per_transaction'
    effective_date DATE NOT NULL DEFAULT CURRENT_DATE,
    expiry_date DATE,
    status VARCHAR(20) NOT NULL DEFAULT 'active', -- 'active', 'inactive', 'expired'
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_by UUID,
    updated_by UUID,
    version INTEGER NOT NULL DEFAULT 1
);

CREATE INDEX IF NOT EXISTS idx_user_limits_user_id ON core.user_limits(user_id);
CREATE INDEX IF NOT EXISTS idx_user_limits_limit_type ON core.user_limits(limit_type);
CREATE INDEX IF NOT EXISTS idx_user_limits_status ON core.user_limits(status);

-- +goose Down
DROP TABLE IF EXISTS core.user_limits CASCADE; 