-- +goose Up
-- Add missing foreign key constraints for limits tables

-- core.account_limits
-- +goose StatementBegin
ALTER TABLE core.account_limits ADD CONSTRAINT fk_account_limits_account FOREIGN KEY (account_id) REFERENCES core.accounts(id) ON DELETE CASCADE;
-- +goose StatementEnd

-- core.transaction_limits
-- +goose StatementBegin
ALTER TABLE core.transaction_limits ADD CONSTRAINT fk_transaction_limits_account FOREIGN KEY (account_id) REFERENCES core.accounts(id) ON DELETE CASCADE;
-- +goose StatementEnd
-- +goose StatementBegin
ALTER TABLE core.transaction_limits ADD CONSTRAINT fk_transaction_limits_client FOREIGN KEY (client_id) REFERENCES core.clients(id) ON DELETE CASCADE;
-- +goose StatementEnd
-- +goose StatementBegin
ALTER TABLE core.transaction_limits ADD CONSTRAINT fk_transaction_limits_type FOREIGN KEY (transaction_type_id) REFERENCES core.transaction_types(id) ON DELETE CASCADE;
-- +goose StatementEnd

-- core.user_limits
-- +goose StatementBegin
ALTER TABLE core.user_limits ADD CONSTRAINT fk_user_limits_user FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;
-- +goose StatementEnd

-- +goose Down
-- Remove the added foreign key constraints
-- +goose StatementBegin
ALTER TABLE core.account_limits DROP CONSTRAINT IF EXISTS fk_account_limits_account;
-- +goose StatementEnd
-- +goose StatementBegin
ALTER TABLE core.transaction_limits DROP CONSTRAINT IF EXISTS fk_transaction_limits_account;
-- +goose StatementEnd
-- +goose StatementBegin
ALTER TABLE core.transaction_limits DROP CONSTRAINT IF EXISTS fk_transaction_limits_client;
-- +goose StatementEnd
-- +goose StatementBegin
ALTER TABLE core.transaction_limits DROP CONSTRAINT IF EXISTS fk_transaction_limits_type;
-- +goose StatementEnd
-- +goose StatementBegin
ALTER TABLE core.user_limits DROP CONSTRAINT IF EXISTS fk_user_limits_user;
-- +goose StatementEnd 