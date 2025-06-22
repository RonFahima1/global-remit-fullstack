-- +goose Up
-- +goose StatementBegin
SELECT 'up SQL query';
ALTER TABLE core.transactions ADD COLUMN IF NOT EXISTS branch_id UUID;
ALTER TABLE core.transactions ADD COLUMN IF NOT EXISTS teller_id UUID;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
SELECT 'down SQL query';
ALTER TABLE core.transactions DROP COLUMN IF EXISTS branch_id;
ALTER TABLE core.transactions DROP COLUMN IF EXISTS teller_id;
-- +goose StatementEnd
