-- +goose Up
-- +goose StatementBegin
CREATE SCHEMA IF NOT EXISTS compliance;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP SCHEMA IF EXISTS compliance CASCADE;
-- +goose StatementEnd
