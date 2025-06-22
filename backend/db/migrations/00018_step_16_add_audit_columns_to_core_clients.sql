-- +goose Up
-- +goose StatementBegin
ALTER TABLE core.clients ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ;
ALTER TABLE core.clients ADD COLUMN IF NOT EXISTS created_by UUID;
ALTER TABLE core.clients ADD COLUMN IF NOT EXISTS updated_by UUID;
ALTER TABLE core.clients ADD COLUMN IF NOT EXISTS version INTEGER DEFAULT 1;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
ALTER TABLE core.clients DROP COLUMN IF EXISTS deleted_at;
ALTER TABLE core.clients DROP COLUMN IF EXISTS created_by;
ALTER TABLE core.clients DROP COLUMN IF EXISTS updated_by;
ALTER TABLE core.clients DROP COLUMN IF EXISTS version;
-- +goose StatementEnd
