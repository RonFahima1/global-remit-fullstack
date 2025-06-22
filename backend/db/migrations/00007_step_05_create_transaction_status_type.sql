-- +goose Up
-- +goose StatementBegin
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'transaction_status') THEN
        CREATE TYPE transaction_status AS ENUM (
            'pending', 'completed', 'failed', 'cancelled', 'reversed', 'hold'
        );
    END IF;
END$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_type WHERE typname = 'transaction_status') THEN
        DROP TYPE transaction_status;
    END IF;
END$$;
-- +goose StatementEnd
