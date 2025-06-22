-- +goose Up
-- +goose StatementBegin
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'user_status') THEN
        CREATE TYPE user_status AS ENUM (
            'PENDING_VERIFICATION', 'ACTIVE', 'DISABLED', 'SUSPENDED', 'LOCKED', 'DELETED', 'INVITED', 'PASSWORD_EXPIRED'
        );
    END IF;
END$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_type WHERE typname = 'user_status') THEN
        DROP TYPE user_status;
    END IF;
END$$;
-- +goose StatementEnd
