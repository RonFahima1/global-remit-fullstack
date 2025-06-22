-- +goose Up
-- +goose StatementBegin
CREATE TABLE IF NOT EXISTS core.account_holders (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    account_id UUID NOT NULL,
    client_id UUID NOT NULL,
    holder_type VARCHAR(20) NOT NULL DEFAULT 'PRIMARY',
    added_date DATE NOT NULL DEFAULT CURRENT_DATE,
    removed_date DATE,
    permissions JSONB NOT NULL DEFAULT '{"view": true, "transact": true, "manage": false}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by UUID,
    updated_by UUID,
    version INTEGER NOT NULL DEFAULT 1
);
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP TABLE IF EXISTS core.account_holders;
-- +goose StatementEnd
