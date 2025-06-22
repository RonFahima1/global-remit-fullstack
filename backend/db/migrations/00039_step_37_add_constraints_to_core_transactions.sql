-- +goose Up
-- +goose StatementBegin
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.table_constraints
        WHERE constraint_name = 'uq_transactions_reference' AND table_name = 'transactions' AND table_schema = 'core'
    ) THEN
        ALTER TABLE core.transactions ADD CONSTRAINT uq_transactions_reference UNIQUE (transaction_reference);
    END IF;
END$$;
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.table_constraints
        WHERE constraint_name = 'chk_transaction_amount' AND table_name = 'transactions' AND table_schema = 'core'
    ) THEN
        ALTER TABLE core.transactions ADD CONSTRAINT chk_transaction_amount CHECK (amount > 0);
    END IF;
END$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
ALTER TABLE core.transactions DROP CONSTRAINT IF EXISTS uq_transactions_reference;
ALTER TABLE core.transactions DROP CONSTRAINT IF EXISTS chk_transaction_amount;
-- +goose StatementEnd
