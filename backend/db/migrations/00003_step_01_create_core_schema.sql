-- +goose Up
-- +goose StatementBegin
CREATE SCHEMA IF NOT EXISTS core;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP SCHEMA IF EXISTS core CASCADE;
-- +goose StatementEnd
