-- +goose Up
-- +goose StatementBegin
CREATE TABLE IF NOT EXISTS core.account_balances (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    account_id UUID NOT NULL,
    balance_date DATE NOT NULL,
    opening_balance DECIMAL(19, 4) NOT NULL,
    closing_balance DECIMAL(19, 4) NOT NULL,
    total_credits DECIMAL(19, 4) NOT NULL DEFAULT 0,
    total_debits DECIMAL(19, 4) NOT NULL DEFAULT 0,
    transaction_count INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by UUID,
    updated_by UUID,
    version INTEGER NOT NULL DEFAULT 1
);
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP TABLE IF EXISTS core.account_balances;
-- +goose StatementEnd
