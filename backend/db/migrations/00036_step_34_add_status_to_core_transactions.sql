-- +goose Up
-- +goose StatementBegin
ALTER TABLE core.transactions ADD COLUMN IF NOT EXISTS status transaction_status DEFAULT 'pending';
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.table_constraints
        WHERE constraint_name = 'chk_transaction_status' AND table_name = 'transactions' AND table_schema = 'core'
    ) THEN
        ALTER TABLE core.transactions ADD CONSTRAINT chk_transaction_status CHECK (status IN ('pending', 'completed', 'failed', 'cancelled', 'reversed', 'hold'));
    END IF;
END$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
ALTER TABLE core.transactions DROP CONSTRAINT IF EXISTS chk_transaction_status;
ALTER TABLE core.transactions DROP COLUMN IF EXISTS status;
-- +goose StatementEnd
