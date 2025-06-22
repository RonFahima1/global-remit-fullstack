-- +goose Up
-- Add all missing, business-logic-driven indexes for core and compliance tables

-- core.accounts
-- +goose StatementBegin
CREATE INDEX idx_accounts_client_id ON core.accounts (client_id);
-- +goose StatementEnd
-- +goose StatementBegin
CREATE INDEX idx_accounts_account_type_id ON core.accounts (account_type_id);
-- +goose StatementEnd
-- +goose StatementBegin
CREATE INDEX idx_accounts_status ON core.accounts (status);
-- +goose StatementEnd
-- +goose StatementBegin
CREATE INDEX idx_accounts_status_type ON core.accounts (status, account_type_id);
-- +goose StatementEnd
-- +goose StatementBegin
CREATE INDEX idx_accounts_created_by ON core.accounts (created_by);
-- +goose StatementEnd
-- +goose StatementBegin
CREATE INDEX idx_accounts_updated_by ON core.accounts (updated_by);
-- +goose StatementEnd
-- +goose StatementBegin
CREATE INDEX idx_accounts_created_at_desc ON core.accounts (created_at DESC);
-- +goose StatementEnd

-- core.clients
-- +goose StatementBegin
CREATE INDEX idx_clients_status ON core.clients (status);
-- +goose StatementEnd
-- +goose StatementBegin
CREATE INDEX idx_clients_kyc_status ON core.clients (kyc_status);
-- +goose StatementEnd
-- +goose StatementBegin
CREATE INDEX idx_clients_branch_id ON core.clients (branch_id);
-- +goose StatementEnd
-- +goose StatementBegin
CREATE INDEX idx_clients_created_by ON core.clients (created_by);
-- +goose StatementEnd
-- +goose StatementBegin
CREATE INDEX idx_clients_updated_by ON core.clients (updated_by);
-- +goose StatementEnd
-- +goose StatementBegin
CREATE INDEX idx_clients_created_at_desc ON core.clients (created_at DESC);
-- +goose StatementEnd
-- +goose StatementBegin
CREATE INDEX idx_clients_relationship_manager_id ON core.clients (relationship_manager_id);
-- +goose StatementEnd

-- compliance.kyc_verifications
-- +goose StatementBegin
CREATE INDEX idx_kyc_verified_by ON compliance.kyc_verifications (verified_by);
-- +goose StatementEnd
-- +goose StatementBegin
CREATE INDEX idx_kyc_created_by ON compliance.kyc_verifications (created_by);
-- +goose StatementEnd
-- +goose StatementBegin
CREATE INDEX idx_kyc_updated_by ON compliance.kyc_verifications (updated_by);
-- +goose StatementEnd
-- +goose StatementBegin
CREATE INDEX idx_kyc_created_at_desc ON compliance.kyc_verifications (created_at DESC);
-- +goose StatementEnd
-- +goose StatementBegin
CREATE INDEX idx_kyc_status_verified_at ON compliance.kyc_verifications (verification_status, verified_at DESC);
-- +goose StatementEnd

-- compliance.aml_checks
-- +goose StatementBegin
CREATE INDEX idx_aml_check_status ON compliance.aml_checks (check_status);
-- +goose StatementEnd
-- +goose StatementBegin
CREATE INDEX idx_aml_risk_level ON compliance.aml_checks (risk_level);
-- +goose StatementEnd
-- +goose StatementBegin
CREATE INDEX idx_aml_created_by ON compliance.aml_checks (created_by);
-- +goose StatementEnd
-- +goose StatementBegin
CREATE INDEX idx_aml_updated_by ON compliance.aml_checks (updated_by);
-- +goose StatementEnd
-- +goose StatementBegin
CREATE INDEX idx_aml_created_at_desc ON compliance.aml_checks (created_at DESC);
-- +goose StatementEnd
-- +goose StatementBegin
CREATE INDEX idx_aml_status_risk_level ON compliance.aml_checks (check_status, risk_level);
-- +goose StatementEnd

-- compliance.sanctions_matches
-- +goose StatementBegin
CREATE INDEX idx_sanctions_matches_resolved_by ON compliance.sanctions_matches (resolved_by);
-- +goose StatementEnd
-- +goose StatementBegin
CREATE INDEX idx_sanctions_matches_created_at_desc ON compliance.sanctions_matches (created_at DESC);
-- +goose StatementEnd
-- +goose StatementBegin
CREATE INDEX idx_sanctions_matches_resolved_date ON compliance.sanctions_matches (resolved, match_date DESC);
-- +goose StatementEnd

-- core.account_holders
-- +goose StatementBegin
CREATE INDEX idx_account_holders_account_id ON core.account_holders (account_id);
-- +goose StatementEnd
-- +goose StatementBegin
CREATE INDEX idx_account_holders_client_id ON core.account_holders (client_id);
-- +goose StatementEnd
-- +goose StatementBegin
CREATE INDEX idx_account_holders_holder_type ON core.account_holders (holder_type);
-- +goose StatementEnd
-- +goose StatementBegin
CREATE INDEX idx_account_holders_created_by ON core.account_holders (created_by);
-- +goose StatementEnd
-- +goose StatementBegin
CREATE INDEX idx_account_holders_updated_by ON core.account_holders (updated_by);
-- +goose StatementEnd
-- +goose StatementBegin
CREATE INDEX idx_account_holders_created_at_desc ON core.account_holders (created_at DESC);
-- +goose StatementEnd

-- core.account_balances
-- +goose StatementBegin
CREATE INDEX idx_account_balances_account_id ON core.account_balances (account_id);
-- +goose StatementEnd
-- +goose StatementBegin
CREATE INDEX idx_account_balances_balance_date_desc ON core.account_balances (balance_date DESC);
-- +goose StatementEnd
-- +goose StatementBegin
CREATE INDEX idx_account_balances_created_by ON core.account_balances (created_by);
-- +goose StatementEnd
-- +goose StatementBegin
CREATE INDEX idx_account_balances_updated_by ON core.account_balances (updated_by);
-- +goose StatementEnd
-- +goose StatementBegin
CREATE INDEX idx_account_balances_created_at_desc ON core.account_balances (created_at DESC);
-- +goose StatementEnd

-- compliance.audit_logs
-- +goose StatementBegin
CREATE INDEX idx_audit_logs_event_time_desc ON compliance.audit_logs (event_time DESC);
-- +goose StatementEnd
-- +goose StatementBegin
CREATE INDEX idx_audit_logs_user_id ON compliance.audit_logs (user_id);
-- +goose StatementEnd
-- +goose StatementBegin
CREATE INDEX idx_audit_logs_table_name ON compliance.audit_logs (table_name);
-- +goose StatementEnd
-- +goose StatementBegin
CREATE INDEX idx_audit_logs_record_id ON compliance.audit_logs (record_id);
-- +goose StatementEnd
-- +goose StatementBegin
CREATE INDEX idx_audit_logs_action ON compliance.audit_logs (action);
-- +goose StatementEnd
-- +goose StatementBegin
CREATE INDEX idx_audit_logs_user_event_time ON compliance.audit_logs (user_id, event_time DESC);
-- +goose StatementEnd
-- +goose StatementBegin
CREATE INDEX idx_audit_logs_table_record ON compliance.audit_logs (table_name, record_id);
-- +goose StatementEnd

-- +goose Down
-- Remove all added indexes
-- core.accounts
-- +goose StatementBegin
DROP INDEX IF EXISTS core.idx_accounts_client_id;
-- +goose StatementEnd
-- +goose StatementBegin
DROP INDEX IF EXISTS core.idx_accounts_account_type_id;
-- +goose StatementEnd
-- +goose StatementBegin
DROP INDEX IF EXISTS core.idx_accounts_status;
-- +goose StatementEnd
-- +goose StatementBegin
DROP INDEX IF EXISTS core.idx_accounts_status_type;
-- +goose StatementEnd
-- +goose StatementBegin
DROP INDEX IF EXISTS core.idx_accounts_created_by;
-- +goose StatementEnd
-- +goose StatementBegin
DROP INDEX IF EXISTS core.idx_accounts_updated_by;
-- +goose StatementEnd
-- +goose StatementBegin
DROP INDEX IF EXISTS core.idx_accounts_created_at_desc;
-- +goose StatementEnd
-- core.clients
-- +goose StatementBegin
DROP INDEX IF EXISTS core.idx_clients_status;
-- +goose StatementEnd
-- +goose StatementBegin
DROP INDEX IF EXISTS core.idx_clients_kyc_status;
-- +goose StatementEnd
-- +goose StatementBegin
DROP INDEX IF EXISTS core.idx_clients_branch_id;
-- +goose StatementEnd
-- +goose StatementBegin
DROP INDEX IF EXISTS core.idx_clients_created_by;
-- +goose StatementEnd
-- +goose StatementBegin
DROP INDEX IF EXISTS core.idx_clients_updated_by;
-- +goose StatementEnd
-- +goose StatementBegin
DROP INDEX IF EXISTS core.idx_clients_created_at_desc;
-- +goose StatementEnd
-- +goose StatementBegin
DROP INDEX IF EXISTS core.idx_clients_relationship_manager_id;
-- +goose StatementEnd
-- compliance.kyc_verifications
-- +goose StatementBegin
DROP INDEX IF EXISTS compliance.idx_kyc_verified_by;
-- +goose StatementEnd
-- +goose StatementBegin
DROP INDEX IF EXISTS compliance.idx_kyc_created_by;
-- +goose StatementEnd
-- +goose StatementBegin
DROP INDEX IF EXISTS compliance.idx_kyc_updated_by;
-- +goose StatementEnd
-- +goose StatementBegin
DROP INDEX IF EXISTS compliance.idx_kyc_created_at_desc;
-- +goose StatementEnd
-- +goose StatementBegin
DROP INDEX IF EXISTS compliance.idx_kyc_status_verified_at;
-- +goose StatementEnd
-- compliance.aml_checks
-- +goose StatementBegin
DROP INDEX IF EXISTS compliance.idx_aml_check_status;
-- +goose StatementEnd
-- +goose StatementBegin
DROP INDEX IF EXISTS compliance.idx_aml_risk_level;
-- +goose StatementEnd
-- +goose StatementBegin
DROP INDEX IF EXISTS compliance.idx_aml_created_by;
-- +goose StatementEnd
-- +goose StatementBegin
DROP INDEX IF EXISTS compliance.idx_aml_updated_by;
-- +goose StatementEnd
-- +goose StatementBegin
DROP INDEX IF EXISTS compliance.idx_aml_created_at_desc;
-- +goose StatementEnd
-- +goose StatementBegin
DROP INDEX IF EXISTS compliance.idx_aml_status_risk_level;
-- +goose StatementEnd
-- compliance.sanctions_matches
-- +goose StatementBegin
DROP INDEX IF EXISTS compliance.idx_sanctions_matches_resolved_by;
-- +goose StatementEnd
-- +goose StatementBegin
DROP INDEX IF EXISTS compliance.idx_sanctions_matches_created_at_desc;
-- +goose StatementEnd
-- +goose StatementBegin
DROP INDEX IF EXISTS compliance.idx_sanctions_matches_resolved_date;
-- +goose StatementEnd
-- core.account_holders
-- +goose StatementBegin
DROP INDEX IF EXISTS core.idx_account_holders_account_id;
-- +goose StatementEnd
-- +goose StatementBegin
DROP INDEX IF EXISTS core.idx_account_holders_client_id;
-- +goose StatementEnd
-- +goose StatementBegin
DROP INDEX IF EXISTS core.idx_account_holders_holder_type;
-- +goose StatementEnd
-- +goose StatementBegin
DROP INDEX IF EXISTS core.idx_account_holders_created_by;
-- +goose StatementEnd
-- +goose StatementBegin
DROP INDEX IF EXISTS core.idx_account_holders_updated_by;
-- +goose StatementEnd
-- +goose StatementBegin
DROP INDEX IF EXISTS core.idx_account_holders_created_at_desc;
-- +goose StatementEnd
-- core.account_balances
-- +goose StatementBegin
DROP INDEX IF EXISTS core.idx_account_balances_account_id;
-- +goose StatementEnd
-- +goose StatementBegin
DROP INDEX IF EXISTS core.idx_account_balances_balance_date_desc;
-- +goose StatementEnd
-- +goose StatementBegin
DROP INDEX IF EXISTS core.idx_account_balances_created_by;
-- +goose StatementEnd
-- +goose StatementBegin
DROP INDEX IF EXISTS core.idx_account_balances_updated_by;
-- +goose StatementEnd
-- +goose StatementBegin
DROP INDEX IF EXISTS core.idx_account_balances_created_at_desc;
-- +goose StatementEnd
-- compliance.audit_logs
-- +goose StatementBegin
DROP INDEX IF EXISTS compliance.idx_audit_logs_event_time_desc;
-- +goose StatementEnd
-- +goose StatementBegin
DROP INDEX IF EXISTS compliance.idx_audit_logs_user_id;
-- +goose StatementEnd
-- +goose StatementBegin
DROP INDEX IF EXISTS compliance.idx_audit_logs_table_name;
-- +goose StatementEnd
-- +goose StatementBegin
DROP INDEX IF EXISTS compliance.idx_audit_logs_record_id;
-- +goose StatementEnd
-- +goose StatementBegin
DROP INDEX IF EXISTS compliance.idx_audit_logs_action;
-- +goose StatementEnd
-- +goose StatementBegin
DROP INDEX IF EXISTS compliance.idx_audit_logs_user_event_time;
-- +goose StatementEnd
-- +goose StatementBegin
DROP INDEX IF EXISTS compliance.idx_audit_logs_table_record;
-- +goose StatementEnd 