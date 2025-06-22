-- +goose Up
-- +goose StatementBegin
CREATE TABLE IF NOT EXISTS compliance.kyc_verifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    client_id UUID NOT NULL,
    verification_type VARCHAR(50) NOT NULL,
    verification_status VARCHAR(20) NOT NULL,
    verified_at TIMESTAMPTZ,
    verified_by UUID,
    expiration_date TIMESTAMPTZ,
    verification_data JSONB,
    rejection_reason TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by UUID,
    updated_by UUID,
    version INTEGER NOT NULL DEFAULT 1
);
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP TABLE IF EXISTS compliance.kyc_verifications;
-- +goose StatementEnd
