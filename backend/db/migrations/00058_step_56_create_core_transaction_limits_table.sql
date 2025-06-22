-- +goose Up
CREATE SCHEMA IF NOT EXISTS core;
CREATE TABLE IF NOT EXISTS core.transaction_limits (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    transaction_type_id UUID,
    client_id UUID,
    account_id UUID,
    limit_type VARCHAR(50) NOT NULL, -- e.g., 'per_transaction', 'daily', 'monthly', etc.
    currency_code CHAR(3) NOT NULL,
    limit_value NUMERIC(20, 4) NOT NULL,
    period VARCHAR(20) NOT NULL, -- e.g., 'per_transaction', 'daily', 'monthly', 'yearly'
    effective_date DATE NOT NULL DEFAULT CURRENT_DATE,
    expiry_date DATE,
    status VARCHAR(20) NOT NULL DEFAULT 'active', -- 'active', 'inactive', 'expired'
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_by UUID,
    updated_by UUID,
    version INTEGER NOT NULL DEFAULT 1
);

CREATE INDEX IF NOT EXISTS idx_transaction_limits_type ON core.transaction_limits(limit_type);
CREATE INDEX IF NOT EXISTS idx_transaction_limits_status ON core.transaction_limits(status);
CREATE INDEX IF NOT EXISTS idx_transaction_limits_client_id ON core.transaction_limits(client_id);
CREATE INDEX IF NOT EXISTS idx_transaction_limits_account_id ON core.transaction_limits(account_id);
CREATE INDEX IF NOT EXISTS idx_transaction_limits_transaction_type_id ON core.transaction_limits(transaction_type_id);

-- +goose Down
DROP TABLE IF EXISTS core.transaction_limits CASCADE; 