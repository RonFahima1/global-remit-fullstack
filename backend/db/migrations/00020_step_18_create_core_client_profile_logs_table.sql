-- +goose Up
-- +goose StatementBegin
CREATE TABLE IF NOT EXISTS core.client_profile_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    client_id UUID NOT NULL,
    changed_by UUID,
    change_type VARCHAR(50),
    old_values JSONB,
    new_values JSONB,
    changed_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    reason TEXT,
    version INTEGER
);
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP TABLE IF EXISTS core.client_profile_logs;
-- +goose StatementEnd
