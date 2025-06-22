-- +goose Up
-- +goose StatementBegin
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'transaction_direction') THEN
        CREATE TYPE transaction_direction AS ENUM (
            'credit', 'debit'
        );
    END IF;
END$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_type WHERE typname = 'transaction_direction') THEN
        DROP TYPE transaction_direction;
    END IF;
END$$;
-- +goose StatementEnd
