-- +goose Up
-- +goose StatementBegin
ALTER TABLE core.clients ADD COLUMN IF NOT EXISTS status VARCHAR(20) DEFAULT 'PENDING';
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.table_constraints
        WHERE constraint_name = 'chk_client_status' AND table_name = 'clients' AND table_schema = 'core'
    ) THEN
        ALTER TABLE core.clients ADD CONSTRAINT chk_client_status CHECK (status IN ('PENDING', 'ACTIVE', 'SUSPENDED', 'CLOSED', 'DECEASED'));
    END IF;
END$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
ALTER TABLE core.clients DROP CONSTRAINT IF EXISTS chk_client_status;
ALTER TABLE core.clients DROP COLUMN IF EXISTS status;
-- +goose StatementEnd
