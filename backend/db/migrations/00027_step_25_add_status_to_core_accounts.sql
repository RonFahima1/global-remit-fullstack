-- +goose Up
-- +goose StatementBegin
ALTER TABLE core.accounts ADD COLUMN IF NOT EXISTS status VARCHAR(20) DEFAULT 'ACTIVE';
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.table_constraints
        WHERE constraint_name = 'chk_account_status' AND table_name = 'accounts' AND table_schema = 'core'
    ) THEN
        ALTER TABLE core.accounts ADD CONSTRAINT chk_account_status CHECK (status IN ('PENDING', 'ACTIVE', 'DORMANT', 'RESTRICTED', 'CLOSED'));
    END IF;
END$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
ALTER TABLE core.accounts DROP CONSTRAINT IF EXISTS chk_account_status;
ALTER TABLE core.accounts DROP COLUMN IF EXISTS status;
-- +goose StatementEnd
