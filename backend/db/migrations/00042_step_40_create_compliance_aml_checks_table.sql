-- +goose Up
-- +goose StatementBegin
CREATE TABLE IF NOT EXISTS compliance.aml_checks (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    client_id UUID,
    transaction_id UUID,
    check_type VARCHAR(50) NOT NULL,
    check_status VARCHAR(20) NOT NULL,
    risk_score INTEGER,
    risk_level VARCHAR(20),
    check_data JSONB,
    notes TEXT,
    resolved_at TIMESTAMPTZ,
    resolved_by UUID,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by UUID,
    updated_by UUID,
    version INTEGER NOT NULL DEFAULT 1
);
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP TABLE IF EXISTS compliance.aml_checks;
-- +goose StatementEnd
