-- +goose Up
-- +goose StatementBegin
CREATE TABLE IF NOT EXISTS core.clients (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    client_number VARCHAR(20) UNIQUE NOT NULL,
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP TABLE IF EXISTS core.clients;
-- +goose StatementEnd
