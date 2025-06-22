-- +goose Up
-- +goose StatementBegin
ALTER TABLE core.accounts ADD COLUMN IF NOT EXISTS account_type_id UUID NOT NULL;
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.table_constraints
        WHERE constraint_name = 'fk_accounts_account_type' AND table_name = 'accounts' AND table_schema = 'core'
    ) THEN
        ALTER TABLE core.accounts ADD CONSTRAINT fk_accounts_account_type FOREIGN KEY (account_type_id) REFERENCES core.account_types(id);
    END IF;
END$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
ALTER TABLE core.accounts DROP CONSTRAINT IF EXISTS fk_accounts_account_type;
ALTER TABLE core.accounts DROP COLUMN IF EXISTS account_type_id;
-- +goose StatementEnd
