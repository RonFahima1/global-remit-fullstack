-- +goose Up
-- +goose StatementBegin
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.table_constraints
        WHERE constraint_name = 'fk_kyc_client' AND table_name = 'kyc_verifications' AND table_schema = 'compliance'
    ) THEN
        ALTER TABLE compliance.kyc_verifications ADD CONSTRAINT fk_kyc_client FOREIGN KEY (client_id) REFERENCES core.clients(id) ON DELETE CASCADE;
    END IF;
END$$;
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.table_constraints
        WHERE constraint_name = 'chk_verification_status' AND table_name = 'kyc_verifications' AND table_schema = 'compliance'
    ) THEN
        ALTER TABLE compliance.kyc_verifications ADD CONSTRAINT chk_verification_status CHECK (verification_status IN ('pending', 'approved', 'rejected', 'expired'));
    END IF;
END$$;
CREATE INDEX IF NOT EXISTS idx_kyc_client_id ON compliance.kyc_verifications(client_id);
CREATE INDEX IF NOT EXISTS idx_kyc_status ON compliance.kyc_verifications(verification_status);
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
ALTER TABLE compliance.kyc_verifications DROP CONSTRAINT IF EXISTS fk_kyc_client;
ALTER TABLE compliance.kyc_verifications DROP CONSTRAINT IF EXISTS chk_verification_status;
DROP INDEX IF EXISTS compliance.idx_kyc_client_id;
DROP INDEX IF EXISTS compliance.idx_kyc_status;
-- +goose StatementEnd
