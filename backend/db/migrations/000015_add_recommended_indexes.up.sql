-- Auth Schema
CREATE INDEX IF NOT EXISTS idx_users_created_at ON auth.users(created_at);
CREATE INDEX IF NOT EXISTS idx_users_last_login ON auth.users(last_login_at);
CREATE INDEX IF NOT EXISTS idx_sessions_expires ON auth.sessions(expires_at);
CREATE INDEX IF NOT EXISTS idx_sessions_user ON auth.sessions(user_id);

-- Core Schema
CREATE INDEX IF NOT EXISTS idx_clients_status ON core.clients(status);
CREATE INDEX IF NOT EXISTS idx_clients_created_at ON core.clients(created_at);
CREATE INDEX IF NOT EXISTS idx_accounts_status ON core.accounts(status);

-- Transactions table does not have a balance column.
-- CREATE INDEX IF NOT EXISTS idx_accounts_balance ON core.accounts(balance) WHERE balance > 0;
CREATE INDEX IF NOT EXISTS idx_transactions_type_status ON core.transactions(transaction_type_id, status);

-- Transactions table does not have an amount column.
-- CREATE INDEX IF NOT EXISTS idx_transactions_amount ON core.transactions(amount) WHERE amount > 10000;

-- Compliance Schema
CREATE INDEX IF NOT EXISTS idx_audit_logs_composite ON compliance.audit_logs(event_type, event_time);
-- CREATE INDEX IF NOT EXISTS idx_kyc_expiration ON compliance.kyc_verifications(expiration_date);

-- Config Schema
-- This unique index conflicts with an existing constraint.
-- CREATE UNIQUE INDEX IF NOT EXISTS idx_exchange_rates_unique ON config.exchange_rates(from_currency, to_currency, effective_date) WHERE is_active = true;
