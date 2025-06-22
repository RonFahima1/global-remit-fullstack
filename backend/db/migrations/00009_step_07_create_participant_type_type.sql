-- +goose Up
-- +goose StatementBegin
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'participant_type') THEN
        CREATE TYPE participant_type AS ENUM (
            'sender', 'receiver', 'fee', 'tax', 'commission', 'adjustment', 'system'
        );
    END IF;
END$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_type WHERE typname = 'participant_type') THEN
        DROP TYPE participant_type;
    END IF;
END$$;
-- +goose StatementEnd
