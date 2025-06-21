-- Auth Schema
DROP INDEX IF EXISTS auth.idx_users_created_at;
DROP INDEX IF EXISTS auth.idx_users_last_login;
DROP INDEX IF EXISTS auth.idx_sessions_expires;
DROP INDEX IF EXISTS auth.idx_sessions_user;

-- Core Schema
DROP INDEX IF EXISTS core.idx_clients_status;
DROP INDEX IF EXISTS core.idx_clients_created_at;
DROP INDEX IF EXISTS core.idx_accounts_status;
DROP INDEX IF EXISTS core.idx_transactions_type_status;

-- Compliance Schema
DROP INDEX IF EXISTS compliance.idx_audit_logs_composite;
-- DROP INDEX IF EXISTS compliance.idx_kyc_expiration;

-- Config Schema
