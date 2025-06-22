-- +goose Up
CREATE SCHEMA IF NOT EXISTS auth;

CREATE TABLE IF NOT EXISTS auth.users (
    -- Core Identity
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    username VARCHAR(50) UNIQUE NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    email_verified BOOLEAN NOT NULL DEFAULT false,
    
    -- Authentication
    password_hash VARCHAR(255) NOT NULL,
    password_changed_at TIMESTAMPTZ,
    password_reset_token VARCHAR(100),
    password_reset_expires_at TIMESTAMPTZ,
    
    -- Multi-Factor Authentication
    mfa_enabled BOOLEAN NOT NULL DEFAULT false,
    mfa_secret VARCHAR(100),
    mfa_recovery_codes TEXT[],
    
    -- Account Status
    status VARCHAR(20) NOT NULL DEFAULT 'PENDING_VERIFICATION' 
        CHECK (status IN ('PENDING_VERIFICATION', 'ACTIVE', 'SUSPENDED', 'LOCKED')),
    failed_login_attempts INTEGER NOT NULL DEFAULT 0,
    locked_until TIMESTAMPTZ,
    
    -- Profile
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    phone VARCHAR(20),
    phone_verified BOOLEAN NOT NULL DEFAULT false,
    
    -- Security
    last_login_at TIMESTAMPTZ,
    last_login_ip INET,
    last_login_user_agent TEXT,
    
    -- System
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at TIMESTAMPTZ,
    version INTEGER NOT NULL DEFAULT 1
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_users_email_lower ON auth.users(LOWER(email));
CREATE INDEX IF NOT EXISTS idx_users_status ON auth.users(status);

CREATE TABLE IF NOT EXISTS auth.roles (
    id SERIAL PRIMARY KEY,
    name VARCHAR(50) NOT NULL UNIQUE,
    description TEXT,
    is_system BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Insert default system roles
INSERT INTO auth.roles (name, description, is_system) VALUES
    ('super_admin', 'Full system access', true),
    ('admin', 'Administrative access', true),
    ('teller', 'Bank teller', true),
    ('compliance', 'Compliance officer', true)
ON CONFLICT (name) DO NOTHING;

CREATE TABLE IF NOT EXISTS auth.permissions (
    id SERIAL PRIMARY KEY,
    code VARCHAR(100) NOT NULL UNIQUE,
    name VARCHAR(100) NOT NULL,
    description TEXT,
    category VARCHAR(50) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Example permissions
INSERT INTO auth.permissions (code, name, category, description) VALUES
    ('user:create', 'Create User', 'Users', 'Create new user accounts'),
    ('user:read', 'View Users', 'Users', 'View user accounts'),
    ('user:update', 'Update Users', 'Users', 'Modify user accounts'),
    ('user:delete', 'Delete Users', 'Users', 'Delete user accounts'),
    ('transaction:create', 'Create Transaction', 'Transactions', 'Create new transactions'),
    ('transaction:approve', 'Approve Transaction', 'Transactions', 'Approve pending transactions')
ON CONFLICT (code) DO NOTHING;

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

-- Indexes
CREATE INDEX IF NOT EXISTS idx_sessions_user_id ON auth.sessions(user_id);
CREATE INDEX IF NOT EXISTS idx_sessions_token_hash ON auth.sessions(token_hash);
CREATE INDEX IF NOT EXISTS idx_sessions_expires_at ON auth.sessions(expires_at);

CREATE TABLE IF NOT EXISTS auth.password_reset_tokens (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    token_hash TEXT NOT NULL,
    expires_at TIMESTAMPTZ NOT NULL,
    is_used BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_password_reset_tokens_user_id ON auth.password_reset_tokens(user_id);
CREATE INDEX IF NOT EXISTS idx_password_reset_tokens_token_hash ON auth.password_reset_tokens(token_hash);

-- +goose Down
DROP TABLE IF EXISTS auth.password_reset_tokens;
DROP TABLE IF EXISTS auth.sessions;
DROP TABLE IF EXISTS auth.user_roles;
DROP TABLE IF EXISTS auth.role_permissions;
DROP TABLE IF EXISTS auth.permissions;
DROP TABLE IF EXISTS auth.roles;
DROP TABLE IF EXISTS auth.users;
DROP SCHEMA IF EXISTS auth;
