-- +goose Up
-- +goose StatementBegin
ALTER TABLE core.accounts ADD COLUMN IF NOT EXISTS open_date DATE DEFAULT CURRENT_DATE;
ALTER TABLE core.accounts ADD COLUMN IF NOT EXISTS last_activity_date DATE;
ALTER TABLE core.accounts ADD COLUMN IF NOT EXISTS close_date DATE;
ALTER TABLE core.accounts ADD COLUMN IF NOT EXISTS metadata JSONB;
ALTER TABLE core.accounts ADD COLUMN IF NOT EXISTS created_by UUID;
ALTER TABLE core.accounts ADD COLUMN IF NOT EXISTS updated_by UUID;
ALTER TABLE core.accounts ADD COLUMN IF NOT EXISTS version INTEGER DEFAULT 1;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
ALTER TABLE core.accounts DROP COLUMN IF EXISTS open_date;
ALTER TABLE core.accounts DROP COLUMN IF EXISTS last_activity_date;
ALTER TABLE core.accounts DROP COLUMN IF EXISTS close_date;
ALTER TABLE core.accounts DROP COLUMN IF EXISTS metadata;
ALTER TABLE core.accounts DROP COLUMN IF EXISTS created_by;
ALTER TABLE core.accounts DROP COLUMN IF EXISTS updated_by;
ALTER TABLE core.accounts DROP COLUMN IF EXISTS version;
-- +goose StatementEnd
