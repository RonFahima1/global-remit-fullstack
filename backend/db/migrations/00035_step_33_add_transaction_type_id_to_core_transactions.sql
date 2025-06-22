-- +goose Up
-- +goose StatementBegin
ALTER TABLE core.transactions ADD COLUMN IF NOT EXISTS transaction_type_id UUID NOT NULL;
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.table_constraints
        WHERE constraint_name = 'fk_transactions_type' AND table_name = 'transactions' AND table_schema = 'core'
    ) THEN
        ALTER TABLE core.transactions ADD CONSTRAINT fk_transactions_type FOREIGN KEY (transaction_type_id) REFERENCES core.transaction_types(id);
    END IF;
END$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
ALTER TABLE core.transactions DROP CONSTRAINT IF EXISTS fk_transactions_type;
ALTER TABLE core.transactions DROP COLUMN IF EXISTS transaction_type_id;
-- +goose StatementEnd
