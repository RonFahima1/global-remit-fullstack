-- +goose Up
-- +goose StatementBegin
ALTER TABLE core.transactions ADD COLUMN IF NOT EXISTS created_by UUID;
ALTER TABLE core.transactions ADD COLUMN IF NOT EXISTS updated_by UUID;
ALTER TABLE core.transactions ADD COLUMN IF NOT EXISTS version INTEGER DEFAULT 1;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
ALTER TABLE core.transactions DROP COLUMN IF EXISTS created_by;
ALTER TABLE core.transactions DROP COLUMN IF EXISTS updated_by;
ALTER TABLE core.transactions DROP COLUMN IF EXISTS version;
-- +goose StatementEnd
