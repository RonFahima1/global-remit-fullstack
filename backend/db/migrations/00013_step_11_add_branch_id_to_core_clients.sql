-- +goose Up
-- +goose StatementBegin
ALTER TABLE core.clients ADD COLUMN IF NOT EXISTS branch_id UUID;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
ALTER TABLE core.clients DROP COLUMN IF EXISTS branch_id;
-- +goose StatementEnd
