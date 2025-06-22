-- +goose Up
-- +goose StatementBegin
ALTER TABLE core.clients ADD COLUMN IF NOT EXISTS client_type VARCHAR(20);
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.table_constraints
        WHERE constraint_name = 'chk_client_type' AND table_name = 'clients' AND table_schema = 'core'
    ) THEN
        ALTER TABLE core.clients ADD CONSTRAINT chk_client_type CHECK (client_type IN ('INDIVIDUAL', 'BUSINESS', 'ORGANIZATION'));
    END IF;
END$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
ALTER TABLE core.clients DROP CONSTRAINT IF EXISTS chk_client_type;
ALTER TABLE core.clients DROP COLUMN IF EXISTS client_type;
-- +goose StatementEnd
