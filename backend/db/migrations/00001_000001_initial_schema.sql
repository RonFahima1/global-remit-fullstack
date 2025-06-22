-- +goose Up
-- +goose StatementBegin

CREATE SCHEMA IF NOT EXISTS auth;
CREATE SCHEMA IF NOT EXISTS core;
CREATE SCHEMA IF NOT EXISTS compliance;
CREATE SCHEMA IF NOT EXISTS config;

CREATE TYPE transaction_status AS ENUM (
    'pending', 'completed', 'failed', 'cancelled', 'reversed', 'hold'
);

CREATE TYPE transaction_direction AS ENUM (
    'credit', 'debit'
);

CREATE TYPE participant_type AS ENUM (
    'sender', 'receiver', 'fee', 'tax', 'commission', 'adjustment', 'system'
);

CREATE TYPE user_status AS ENUM ('PENDING_VERIFICATION', 'ACTIVE', 'DISABLED', 'SUSPENDED', 'LOCKED', 'DELETED', 'INVITED', 'PASSWORD_EXPIRED');

CREATE TABLE IF NOT EXISTS auth.users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    username VARCHAR(50) UNIQUE NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    email_verified BOOLEAN NOT NULL DEFAULT false,
    password_hash VARCHAR(255) NOT NULL,
    password_changed_at TIMESTAMPTZ,
    password_reset_token VARCHAR(100),
    password_reset_expires_at TIMESTAMPTZ,
    mfa_enabled BOOLEAN NOT NULL DEFAULT false,
    mfa_secret VARCHAR(100),
    mfa_recovery_codes TEXT[],
    status user_status NOT NULL DEFAULT 'PENDING_VERIFICATION',
    failed_login_attempts INTEGER NOT NULL DEFAULT 0,
    locked_until TIMESTAMPTZ,
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    phone VARCHAR(20),
    phone_verified BOOLEAN NOT NULL DEFAULT false,
    last_login_at TIMESTAMPTZ,
    last_login_ip INET,
    last_login_user_agent TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at TIMESTAMPTZ,
    version INTEGER NOT NULL DEFAULT 1,
    employee_id VARCHAR(50) UNIQUE,
    hire_date DATE,
    termination_date DATE,
    manager_id UUID REFERENCES auth.users(id),
    department VARCHAR(100),
    position VARCHAR(100),
    branch_id UUID,
    address TEXT,
    city VARCHAR(100),
    state VARCHAR(100),
    postal_code VARCHAR(20),
    country CHAR(2),
    phone_verified_at TIMESTAMPTZ,
    email_verified_at TIMESTAMPTZ,
    password_expires_at TIMESTAMPTZ,
    last_password_change TIMESTAMPTZ,
    password_history TEXT[],
    login_count INTEGER NOT NULL DEFAULT 0,
    invitation_token VARCHAR(255),
    invitation_expires_at TIMESTAMPTZ,
    invitation_accepted_at TIMESTAMPTZ,
    invited_by UUID REFERENCES auth.users(id),
    status_reason TEXT,
    status_changed_at TIMESTAMPTZ,
    status_changed_by UUID REFERENCES auth.users(id),
    notes TEXT,
    metadata JSONB,
    must_change_password BOOLEAN NOT NULL DEFAULT FALSE,
    updated_by UUID REFERENCES auth.users(id),
    deleted_by UUID REFERENCES auth.users(id),
    lockout_until TIMESTAMPTZ
);

CREATE TABLE IF NOT EXISTS auth.roles (
    id SERIAL PRIMARY KEY,
    name VARCHAR(50) NOT NULL UNIQUE,
    description TEXT,
    is_system BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS auth.permissions (
    id SERIAL PRIMARY KEY,
    code VARCHAR(100) NOT NULL UNIQUE,
    name VARCHAR(100) NOT NULL,
    description TEXT,
    category VARCHAR(50) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS auth.role_permissions (
    role_id INTEGER NOT NULL REFERENCES auth.roles(id) ON DELETE CASCADE,
    permission_id INTEGER NOT NULL REFERENCES auth.permissions(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (role_id, permission_id)
);

CREATE TABLE IF NOT EXISTS auth.user_roles (
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    role_id INTEGER NOT NULL REFERENCES auth.roles(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by UUID REFERENCES auth.users(id),
    PRIMARY KEY (user_id, role_id)
);

CREATE TABLE IF NOT EXISTS auth.sessions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    token_hash TEXT NOT NULL,
    user_agent TEXT,
    ip_address INET,
    expires_at TIMESTAMPTZ NOT NULL,
    last_activity TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    is_revoked BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS auth.password_reset_tokens (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    token_hash TEXT NOT NULL,
    expires_at TIMESTAMPTZ NOT NULL,
    is_used BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS auth.user_activity_log (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    activity_type VARCHAR(50) NOT NULL,
    description TEXT,
    ip_address INET,
    user_agent TEXT,
    metadata JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS auth.user_sessions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    session_token VARCHAR(255) UNIQUE NOT NULL,
    refresh_token VARCHAR(255) UNIQUE,
    ip_address INET,
    user_agent TEXT,
    device_info JSONB,
    is_active BOOLEAN NOT NULL DEFAULT true,
    expires_at TIMESTAMPTZ NOT NULL,
    last_activity TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS auth.user_password_history (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    password_hash VARCHAR(255) NOT NULL,
    changed_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    changed_by UUID REFERENCES auth.users(id),
    is_temporary BOOLEAN NOT NULL DEFAULT false
);

CREATE TABLE IF NOT EXISTS auth.user_invitations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email VARCHAR(255) NOT NULL,
    token VARCHAR(255) UNIQUE NOT NULL,
    role_id INTEGER NOT NULL REFERENCES auth.roles(id),
    invited_by UUID NOT NULL REFERENCES auth.users(id),
    expires_at TIMESTAMPTZ NOT NULL,
    accepted_at TIMESTAMPTZ,
    accepted_by UUID REFERENCES auth.users(id),
    status VARCHAR(20) NOT NULL DEFAULT 'PENDING' CHECK (status IN ('PENDING', 'ACCEPTED', 'EXPIRED', 'CANCELLED')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS auth.user_verification_tokens (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    token VARCHAR(255) UNIQUE NOT NULL,
    token_type VARCHAR(20) NOT NULL CHECK (token_type IN ('EMAIL', 'PHONE', 'PASSWORD_RESET')),
    expires_at TIMESTAMPTZ NOT NULL,
    used_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS auth.user_preferences (
    user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    language VARCHAR(10) DEFAULT 'en',
    timezone VARCHAR(50) DEFAULT 'UTC',
    theme VARCHAR(20) DEFAULT 'light',
    notifications JSONB DEFAULT '{}',
    preferences JSONB DEFAULT '{}',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS core.clients (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    client_number VARCHAR(20) UNIQUE NOT NULL,
    client_type VARCHAR(20) NOT NULL CHECK (client_type IN ('INDIVIDUAL', 'BUSINESS', 'ORGANIZATION')),
    status VARCHAR(20) NOT NULL DEFAULT 'PENDING' CHECK (status IN ('PENDING', 'ACTIVE', 'SUSPENDED', 'CLOSED', 'DECEASED')),
    title VARCHAR(10),
    first_name VARCHAR(100) NOT NULL,
    middle_name VARCHAR(100),
    last_name VARCHAR(100) NOT NULL,
    date_of_birth DATE,
    gender VARCHAR(10) CHECK (gender IN ('MALE', 'FEMALE', 'OTHER', 'UNSPECIFIED')),
    marital_status VARCHAR(20),
    email VARCHAR(255),
    email_verified BOOLEAN NOT NULL DEFAULT false,
    phone VARCHAR(20),
    phone_verified BOOLEAN NOT NULL DEFAULT false,
    occupation VARCHAR(100),
    employer_name VARCHAR(200),
    employment_status VARCHAR(50),
    annual_income DECIMAL(15, 2),
    kyc_status VARCHAR(20) NOT NULL DEFAULT 'NOT_VERIFIED' CHECK (kyc_status IN ('NOT_VERIFIED', 'PENDING', 'VERIFIED', 'REJECTED', 'EXPIRED')),
    kyc_verified_at TIMESTAMPTZ,
    kyc_verified_by UUID,
    risk_level VARCHAR(20) NOT NULL DEFAULT 'LOW',
    relationship_manager_id UUID,
    referral_source VARCHAR(100),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at TIMESTAMPTZ,
    created_by UUID,
    updated_by UUID,
    version INTEGER NOT NULL DEFAULT 1,
    CONSTRAINT chk_phone_format CHECK (phone IS NULL OR phone ~* '^\\+?[0-9\\s-]+$')
);

CREATE TABLE IF NOT EXISTS core.account_types (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    type_code VARCHAR(20) UNIQUE NOT NULL,
    name VARCHAR(100) NOT NULL,
    description TEXT,
    features JSONB NOT NULL DEFAULT '{}'::jsonb,
    restrictions JSONB NOT NULL DEFAULT '{}'::jsonb,
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by UUID,
    updated_by UUID,
    version INTEGER NOT NULL DEFAULT 1
);

CREATE TABLE IF NOT EXISTS core.accounts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    account_number VARCHAR(20) UNIQUE NOT NULL,
    account_name VARCHAR(255) NOT NULL,
    account_type_id UUID NOT NULL,
    currency_code CHAR(3) NOT NULL,
    current_balance DECIMAL(19, 4) NOT NULL DEFAULT 0,
    available_balance DECIMAL(19, 4) NOT NULL DEFAULT 0,
    hold_balance DECIMAL(19, 4) NOT NULL DEFAULT 0,
    status VARCHAR(20) NOT NULL DEFAULT 'ACTIVE' CHECK (status IN ('PENDING', 'ACTIVE', 'DORMANT', 'RESTRICTED', 'CLOSED')),
    open_date DATE NOT NULL DEFAULT CURRENT_DATE,
    last_activity_date DATE,
    close_date DATE,
    metadata JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by UUID,
    updated_by UUID,
    version INTEGER NOT NULL DEFAULT 1,
    CONSTRAINT chk_balance_non_negative CHECK (current_balance >= 0),
    CONSTRAINT chk_available_balance CHECK (available_balance <= current_balance),
    CONSTRAINT chk_hold_balance CHECK (hold_balance <= current_balance),
    CONSTRAINT chk_dates CHECK ((close_date IS NULL) OR (close_date IS NOT NULL AND close_date >= open_date))
);

CREATE TABLE IF NOT EXISTS core.account_holders (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    account_id UUID NOT NULL,
    client_id UUID NOT NULL,
    holder_type VARCHAR(20) NOT NULL DEFAULT 'PRIMARY' CHECK (holder_type IN ('PRIMARY', 'JOINT', 'AUTHORIZED', 'BENEFICIARY', 'POWER_OF_ATTORNEY')),
    added_date DATE NOT NULL DEFAULT CURRENT_DATE,
    removed_date DATE,
    permissions JSONB NOT NULL DEFAULT '{"view": true, "transact": true, "manage": false}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by UUID,
    updated_by UUID,
    version INTEGER NOT NULL DEFAULT 1,
    CONSTRAINT chk_removal_date CHECK ((removed_date IS NULL) OR (removed_date IS NOT NULL AND removed_date >= added_date)),
    CONSTRAINT uq_account_holder UNIQUE (account_id, client_id, holder_type)
);

CREATE TABLE IF NOT EXISTS core.account_balances (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    account_id UUID NOT NULL,
    balance_date DATE NOT NULL,
    opening_balance DECIMAL(19, 4) NOT NULL,
    closing_balance DECIMAL(19, 4) NOT NULL,
    total_credits DECIMAL(19, 4) NOT NULL DEFAULT 0,
    total_debits DECIMAL(19, 4) NOT NULL DEFAULT 0,
    transaction_count INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by UUID,
    updated_by UUID,
    version INTEGER NOT NULL DEFAULT 1,
    CONSTRAINT chk_positive_balances CHECK (opening_balance >= 0 AND closing_balance >= 0 AND total_credits >= 0 AND total_debits >= 0),
    CONSTRAINT uq_daily_balance UNIQUE (account_id, balance_date)
);

CREATE TABLE IF NOT EXISTS core.transaction_types (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code VARCHAR(50) NOT NULL,
    name VARCHAR(100) NOT NULL,
    description TEXT,
    direction transaction_direction NOT NULL,
    affects_balance BOOLEAN NOT NULL DEFAULT true,
    requires_approval BOOLEAN NOT NULL DEFAULT false,
    approval_threshold DECIMAL(20, 4),
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by UUID,
    updated_by UUID,
    version INTEGER NOT NULL DEFAULT 1,
    CONSTRAINT uq_transaction_types_code UNIQUE (code)
);

CREATE TABLE IF NOT EXISTS core.transactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    transaction_reference VARCHAR(50) NOT NULL,
    transaction_type_id UUID NOT NULL,
    status transaction_status NOT NULL DEFAULT 'pending',
    amount DECIMAL(20, 4) NOT NULL,
    currency_code CHAR(3) NOT NULL,
    exchange_rate NUMERIC(20, 10) DEFAULT 1,
    fee_amount DECIMAL(20, 4) DEFAULT 0,
    tax_amount DECIMAL(20, 4) DEFAULT 0,
    net_amount DECIMAL(20, 4) NOT NULL,
    transaction_date TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    value_date DATE,
    parent_transaction_id UUID,
    related_transaction_id UUID,
    branch_id UUID,
    teller_id UUID,
    description TEXT,
    notes TEXT,
    metadata JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by UUID,
    updated_by UUID,
    version INTEGER NOT NULL DEFAULT 1,
    CONSTRAINT uq_transactions_reference UNIQUE (transaction_reference),
    CONSTRAINT fk_transactions_type FOREIGN KEY (transaction_type_id) REFERENCES core.transaction_types(id) ON DELETE RESTRICT,
    CONSTRAINT chk_transaction_amount CHECK (amount > 0),
    CONSTRAINT chk_net_amount CHECK (net_amount > 0)
);

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
    version INTEGER NOT NULL DEFAULT 1,
    CONSTRAINT fk_kyc_client FOREIGN KEY (client_id) REFERENCES core.clients(id) ON DELETE CASCADE,
    CONSTRAINT chk_verification_status CHECK (verification_status IN ('pending', 'approved', 'rejected', 'expired'))
);

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
    version INTEGER NOT NULL DEFAULT 1,
    CONSTRAINT fk_aml_client FOREIGN KEY (client_id) REFERENCES core.clients(id) ON DELETE SET NULL,
    CONSTRAINT fk_aml_transaction FOREIGN KEY (transaction_id) REFERENCES core.transactions(id) ON DELETE SET NULL,
    CONSTRAINT chk_aml_status CHECK (check_status IN ('pending', 'passed', 'failed', 'manual_review')),
    CONSTRAINT chk_risk_level CHECK (risk_level IN ('low', 'medium', 'high', 'critical'))
);

CREATE TABLE IF NOT EXISTS compliance.sanctions_matches (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    client_id UUID,
    transaction_id UUID,
    list_name VARCHAR(100) NOT NULL,
    matched_name TEXT NOT NULL,
    match_score NUMERIC(5, 2) NOT NULL,
    match_data JSONB,
    status VARCHAR(20) NOT NULL DEFAULT 'pending',
    reviewed_at TIMESTAMPTZ,
    reviewed_by UUID,
    review_notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by UUID,
    updated_by UUID,
    version INTEGER NOT NULL DEFAULT 1,
    CONSTRAINT fk_sanctions_client FOREIGN KEY (client_id) REFERENCES core.clients(id) ON DELETE SET NULL,
    CONSTRAINT fk_sanctions_transaction FOREIGN KEY (transaction_id) REFERENCES core.transactions(id) ON DELETE SET NULL,
    CONSTRAINT chk_sanctions_status CHECK (status IN ('pending', 'false_positive', 'confirmed', 'resolved'))
);

CREATE TABLE IF NOT EXISTS compliance.audit_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    event_time TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    event_type VARCHAR(50) NOT NULL,
    table_name VARCHAR(100),
    record_id UUID,
    user_id UUID,
    user_ip INET,
    user_agent TEXT,
    action VARCHAR(20) NOT NULL,
    old_values JSONB,
    new_values JSONB,
    CONSTRAINT chk_audit_action CHECK (action IN ('INSERT', 'UPDATE', 'DELETE', 'LOGIN', 'LOGOUT', 'AUTH_FAILED'))
);

CREATE TABLE IF NOT EXISTS config.settings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    setting_key VARCHAR(100) NOT NULL,
    setting_value TEXT,
    data_type VARCHAR(20) NOT NULL,
    description TEXT,
    is_encrypted BOOLEAN NOT NULL DEFAULT false,
    is_sensitive BOOLEAN NOT NULL DEFAULT false,
    min_value TEXT,
    max_value TEXT,
    allowed_values JSONB,
    category VARCHAR(50) NOT NULL,
    subcategory VARCHAR(50),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by UUID,
    updated_by UUID,
    version INTEGER NOT NULL DEFAULT 1,
    CONSTRAINT uq_setting_key UNIQUE (setting_key),
    CONSTRAINT chk_data_type CHECK (data_type IN ('string', 'number', 'boolean', 'json', 'date', 'datetime'))
);

CREATE TABLE IF NOT EXISTS config.currencies (
    code CHAR(3) PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    symbol VARCHAR(10) NOT NULL,
    decimal_places INTEGER NOT NULL DEFAULT 2,
    is_active BOOLEAN NOT NULL DEFAULT true,
    is_base_currency BOOLEAN NOT NULL DEFAULT false,
    is_fiat BOOLEAN NOT NULL DEFAULT true,
    is_crypto BOOLEAN GENERATED ALWAYS AS (NOT is_fiat) STORED,
    format_pattern VARCHAR(50) NOT NULL DEFAULT '#,##0.00',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by UUID,
    updated_by UUID,
    version INTEGER NOT NULL DEFAULT 1,
    CONSTRAINT chk_decimal_places CHECK (decimal_places BETWEEN 0 AND 8)
);

CREATE TABLE IF NOT EXISTS config.exchange_rates (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    from_currency CHAR(3) NOT NULL,
    to_currency CHAR(3) NOT NULL,
    rate NUMERIC(24, 12) NOT NULL,
    effective_date DATE NOT NULL,
    expiry_date DATE,
    is_active BOOLEAN NOT NULL DEFAULT true,
    source VARCHAR(50) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by UUID,
    updated_by UUID,
    version INTEGER NOT NULL DEFAULT 1,
    CONSTRAINT fk_from_currency FOREIGN KEY (from_currency) REFERENCES config.currencies(code) ON DELETE CASCADE,
    CONSTRAINT fk_to_currency FOREIGN KEY (to_currency) REFERENCES config.currencies(code) ON DELETE CASCADE,
    CONSTRAINT uq_currency_pair_date UNIQUE (from_currency, to_currency, effective_date)
);

CREATE TABLE IF NOT EXISTS config.fee_structures (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(100) NOT NULL,
    description TEXT,
    fee_type VARCHAR(50) NOT NULL,
    calculation_method VARCHAR(50) NOT NULL,
    is_active BOOLEAN NOT NULL DEFAULT true,
    applies_to_all_transaction_types BOOLEAN NOT NULL DEFAULT false,
    applies_to_all_account_types BOOLEAN NOT NULL DEFAULT false,
    applies_to_all_currencies BOOLEAN NOT NULL DEFAULT false,
    min_fee_amount NUMERIC(20, 4),
    max_fee_amount NUMERIC(20, 4),
    fee_percentage NUMERIC(5, 2),
    fixed_fee_amount NUMERIC(20, 4),
    fee_currency CHAR(3),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by UUID,
    updated_by UUID,
    version INTEGER NOT NULL DEFAULT 1,
    CONSTRAINT fk_fee_currency FOREIGN KEY (fee_currency) REFERENCES config.currencies(code) ON DELETE SET NULL,
    CONSTRAINT chk_fee_type CHECK (fee_type IN ('transaction', 'account', 'service', 'penalty', 'other')),
    CONSTRAINT chk_calculation_method CHECK (calculation_method IN ('fixed', 'percentage', 'tiered', 'volume_based'))
);

CREATE TABLE IF NOT EXISTS config.fee_structure_rules (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    fee_structure_id UUID NOT NULL,
    rule_type VARCHAR(50) NOT NULL,
    rule_condition JSONB NOT NULL,
    fee_value NUMERIC(20, 4) NOT NULL,
    fee_percentage NUMERIC(5, 2),
    min_amount NUMERIC(20, 4),
    max_amount NUMERIC(20, 4),
    currency CHAR(3),
    priority INTEGER NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by UUID,
    updated_by UUID,
    version INTEGER NOT NULL DEFAULT 1,
    CONSTRAINT fk_fee_structure FOREIGN KEY (fee_structure_id) REFERENCES config.fee_structures(id) ON DELETE CASCADE,
    CONSTRAINT fk_currency FOREIGN KEY (currency) REFERENCES config.currencies(code) ON DELETE SET NULL,
    CONSTRAINT chk_rule_type CHECK (rule_type IN ('amount_range', 'transaction_type', 'account_type', 'customer_tier', 'channel'))
);

CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE 'plpgsql';

CREATE OR REPLACE FUNCTION auth.create_user_invitation(
    p_email VARCHAR(255),
    p_role_id INTEGER,
    p_invited_by UUID,
    p_expires_in_hours INTEGER DEFAULT 72
) RETURNS UUID AS $$
DECLARE
    v_invitation_id UUID;
    v_token VARCHAR(255);
BEGIN
    v_token := encode(gen_random_bytes(32), 'hex');
    
    INSERT INTO auth.user_invitations (
        email, token, role_id, invited_by, expires_at
    ) VALUES (
        p_email, v_token, p_role_id, p_invited_by, 
        NOW() + (p_expires_in_hours || ' hours')::INTERVAL
    ) RETURNING id INTO v_invitation_id;
    
    RETURN v_invitation_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION auth.log_user_activity(
    p_user_id UUID,
    p_activity_type VARCHAR(50),
    p_description TEXT DEFAULT NULL,
    p_ip_address INET DEFAULT NULL,
    p_user_agent TEXT DEFAULT NULL,
    p_metadata JSONB DEFAULT NULL
) RETURNS UUID AS $$
DECLARE
    v_log_id UUID;
BEGIN
    INSERT INTO auth.user_activity_log (
        user_id, activity_type, description, ip_address, user_agent, metadata
    ) VALUES (
        p_user_id, p_activity_type, p_description, p_ip_address, p_user_agent, p_metadata
    ) RETURNING id INTO v_log_id;
    
    RETURN v_log_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION auth.can_change_password(
    p_user_id UUID,
    p_new_password_hash VARCHAR(255)
) RETURNS BOOLEAN AS $$
DECLARE
    v_password_count INTEGER;
    v_password_exists BOOLEAN;
BEGIN
    SELECT COUNT(*) INTO v_password_count
    FROM auth.user_password_history
    WHERE user_id = p_user_id
    ORDER BY changed_at DESC
    LIMIT 5;
    
    SELECT EXISTS(
        SELECT 1 FROM auth.user_password_history 
        WHERE user_id = p_user_id AND password_hash = p_new_password_hash
    ) INTO v_password_exists;
    
    RETURN NOT v_password_exists;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP SCHEMA IF EXISTS auth CASCADE;
DROP SCHEMA IF EXISTS core CASCADE;
DROP SCHEMA IF EXISTS compliance CASCADE;
DROP SCHEMA IF EXISTS config CASCADE;
DROP TYPE IF EXISTS transaction_status;
DROP TYPE IF EXISTS transaction_direction;
DROP TYPE IF EXISTS participant_type;
DROP TYPE IF EXISTS user_status;
-- +goose StatementEnd
