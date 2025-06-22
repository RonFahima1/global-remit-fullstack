-- +goose Up
-- +goose StatementBegin
ALTER TABLE config.fee_structures ADD CONSTRAINT uq_fee_structures_name UNIQUE (name);
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
ALTER TABLE config.fee_structures DROP CONSTRAINT IF EXISTS uq_fee_structures_name;
-- +goose StatementEnd 