-- +goose Up
-- +goose StatementBegin
ALTER TABLE core.clients ADD COLUMN IF NOT EXISTS kyc_status VARCHAR(20) DEFAULT 'NOT_VERIFIED';
ALTER TABLE core.clients ADD COLUMN IF NOT EXISTS kyc_verified_at TIMESTAMPTZ;
ALTER TABLE core.clients ADD COLUMN IF NOT EXISTS kyc_verified_by UUID;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
ALTER TABLE core.clients DROP COLUMN IF EXISTS kyc_status;
ALTER TABLE core.clients DROP COLUMN IF EXISTS kyc_verified_at;
ALTER TABLE core.clients DROP COLUMN IF EXISTS kyc_verified_by;
-- +goose StatementEnd
