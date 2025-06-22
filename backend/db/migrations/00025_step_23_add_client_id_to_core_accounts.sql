-- +goose Up
-- +goose StatementBegin
ALTER TABLE core.accounts ADD COLUMN IF NOT EXISTS client_id UUID NOT NULL;
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.table_constraints
        WHERE constraint_name = 'fk_accounts_client' AND table_name = 'accounts' AND table_schema = 'core'
    ) THEN
        ALTER TABLE core.accounts ADD CONSTRAINT fk_accounts_client FOREIGN KEY (client_id) REFERENCES core.clients(id);
    END IF;
END$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
ALTER TABLE core.accounts DROP CONSTRAINT IF EXISTS fk_accounts_client;
ALTER TABLE core.accounts DROP COLUMN IF EXISTS client_id;
-- +goose StatementEnd
