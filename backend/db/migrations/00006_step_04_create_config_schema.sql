-- +goose Up
-- +goose StatementBegin
CREATE SCHEMA IF NOT EXISTS config;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP SCHEMA IF EXISTS config CASCADE;
-- +goose StatementEnd
