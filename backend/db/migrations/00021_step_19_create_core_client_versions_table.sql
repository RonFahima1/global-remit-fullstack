-- +goose Up
-- +goose StatementBegin
CREATE TABLE IF NOT EXISTS core.client_versions (
    version_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    client_id UUID NOT NULL,
    version INTEGER NOT NULL,
    data JSONB NOT NULL,
    modified_by UUID,
    modified_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    reason_for_change TEXT
);
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP TABLE IF EXISTS core.client_versions;
-- +goose StatementEnd
