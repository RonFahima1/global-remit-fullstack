-- +goose Up
-- +goose StatementBegin
ALTER TABLE core.accounts ADD COLUMN IF NOT EXISTS current_balance DECIMAL(19, 4) NOT NULL DEFAULT 0;
ALTER TABLE core.accounts ADD COLUMN IF NOT EXISTS available_balance DECIMAL(19, 4) NOT NULL DEFAULT 0;
ALTER TABLE core.accounts ADD COLUMN IF NOT EXISTS hold_balance DECIMAL(19, 4) NOT NULL DEFAULT 0;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
ALTER TABLE core.accounts DROP COLUMN IF EXISTS current_balance;
ALTER TABLE core.accounts DROP COLUMN IF EXISTS available_balance;
ALTER TABLE core.accounts DROP COLUMN IF EXISTS hold_balance;
-- +goose StatementEnd
