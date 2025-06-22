-- +goose Up
-- +goose StatementBegin
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.table_constraints
        WHERE constraint_name = 'fk_aml_client' AND table_name = 'aml_checks' AND table_schema = 'compliance'
    ) THEN
        ALTER TABLE compliance.aml_checks ADD CONSTRAINT fk_aml_client FOREIGN KEY (client_id) REFERENCES core.clients(id) ON DELETE SET NULL;
    END IF;
END$$;
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.table_constraints
        WHERE constraint_name = 'fk_aml_transaction' AND table_name = 'aml_checks' AND table_schema = 'compliance'
    ) THEN
        ALTER TABLE compliance.aml_checks ADD CONSTRAINT fk_aml_transaction FOREIGN KEY (transaction_id) REFERENCES core.transactions(id) ON DELETE SET NULL;
    END IF;
END$$;
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.table_constraints
        WHERE constraint_name = 'chk_aml_status' AND table_name = 'aml_checks' AND table_schema = 'compliance'
    ) THEN
        ALTER TABLE compliance.aml_checks ADD CONSTRAINT chk_aml_status CHECK (check_status IN ('pending', 'passed', 'failed', 'manual_review'));
    END IF;
END$$;
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.table_constraints
        WHERE constraint_name = 'chk_risk_level' AND table_name = 'aml_checks' AND table_schema = 'compliance'
    ) THEN
        ALTER TABLE compliance.aml_checks ADD CONSTRAINT chk_risk_level CHECK (risk_level IN ('low', 'medium', 'high', 'critical'));
    END IF;
END$$;
CREATE INDEX IF NOT EXISTS idx_aml_client_id ON compliance.aml_checks(client_id);
CREATE INDEX IF NOT EXISTS idx_aml_transaction_id ON compliance.aml_checks(transaction_id);
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
ALTER TABLE compliance.aml_checks DROP CONSTRAINT IF EXISTS fk_aml_client;
ALTER TABLE compliance.aml_checks DROP CONSTRAINT IF EXISTS fk_aml_transaction;
ALTER TABLE compliance.aml_checks DROP CONSTRAINT IF EXISTS chk_aml_status;
ALTER TABLE compliance.aml_checks DROP CONSTRAINT IF EXISTS chk_risk_level;
DROP INDEX IF EXISTS compliance.idx_aml_client_id;
DROP INDEX IF EXISTS compliance.idx_aml_transaction_id;
-- +goose StatementEnd
