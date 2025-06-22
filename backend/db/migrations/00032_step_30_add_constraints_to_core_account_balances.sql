-- +goose Up
-- +goose StatementBegin
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.table_constraints
        WHERE constraint_name = 'uq_daily_balance' AND table_name = 'account_balances' AND table_schema = 'core'
    ) THEN
        ALTER TABLE core.account_balances ADD CONSTRAINT uq_daily_balance UNIQUE (account_id, balance_date);
    END IF;
END$$;
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.table_constraints
        WHERE constraint_name = 'chk_positive_balances' AND table_name = 'account_balances' AND table_schema = 'core'
    ) THEN
        ALTER TABLE core.account_balances ADD CONSTRAINT chk_positive_balances CHECK (opening_balance >= 0 AND closing_balance >= 0 AND total_credits >= 0 AND total_debits >= 0);
    END IF;
END$$;
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.table_constraints
        WHERE constraint_name = 'fk_account_balances_account' AND table_name = 'account_balances' AND table_schema = 'core'
    ) THEN
        ALTER TABLE core.account_balances ADD CONSTRAINT fk_account_balances_account FOREIGN KEY (account_id) REFERENCES core.accounts(id);
    END IF;
END$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
ALTER TABLE core.account_balances DROP CONSTRAINT IF EXISTS uq_daily_balance;
ALTER TABLE core.account_balances DROP CONSTRAINT IF EXISTS chk_positive_balances;
ALTER TABLE core.account_balances DROP CONSTRAINT IF EXISTS fk_account_balances_account;
-- +goose StatementEnd
