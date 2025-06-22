-- Enhanced User Management Schema Migration
-- This migration adds comprehensive user management capabilities

-- 1. Enhance user_status enum with additional statuses
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_enum WHERE enumlabel = 'INVITED' AND enumtypid = (SELECT oid FROM pg_type WHERE typname = 'user_status')) THEN
        ALTER TYPE user_status ADD VALUE 'INVITED';
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM pg_enum WHERE enumlabel = 'PASSWORD_EXPIRED' AND enumtypid = (SELECT oid FROM pg_type WHERE typname = 'user_status')) THEN
        ALTER TYPE user_status ADD VALUE 'PASSWORD_EXPIRED';
    END IF;
END;
$$;

-- 2. Add comprehensive user management columns
ALTER TABLE auth.users 
ADD COLUMN IF NOT EXISTS employee_id VARCHAR(50) UNIQUE,
ADD COLUMN IF NOT EXISTS hire_date DATE,
ADD COLUMN IF NOT EXISTS termination_date DATE,
ADD COLUMN IF NOT EXISTS manager_id UUID REFERENCES auth.users(id),
ADD COLUMN IF NOT EXISTS department VARCHAR(100),
ADD COLUMN IF NOT EXISTS position VARCHAR(100),
ADD COLUMN IF NOT EXISTS branch_id UUID,
ADD COLUMN IF NOT EXISTS address TEXT,
ADD COLUMN IF NOT EXISTS city VARCHAR(100),
ADD COLUMN IF NOT EXISTS state VARCHAR(100),
ADD COLUMN IF NOT EXISTS postal_code VARCHAR(20),
ADD COLUMN IF NOT EXISTS country CHAR(2),
ADD COLUMN IF NOT EXISTS phone_verified_at TIMESTAMPTZ,
ADD COLUMN IF NOT EXISTS email_verified_at TIMESTAMPTZ,
ADD COLUMN IF NOT EXISTS password_expires_at TIMESTAMPTZ,
ADD COLUMN IF NOT EXISTS last_password_change TIMESTAMPTZ,
ADD COLUMN IF NOT EXISTS password_history TEXT[], -- Store last 5 password hashes
ADD COLUMN IF NOT EXISTS login_count INTEGER NOT NULL DEFAULT 0,
ADD COLUMN IF NOT EXISTS invitation_token VARCHAR(255),
ADD COLUMN IF NOT EXISTS invitation_expires_at TIMESTAMPTZ,
ADD COLUMN IF NOT EXISTS invitation_accepted_at TIMESTAMPTZ,
ADD COLUMN IF NOT EXISTS invited_by UUID REFERENCES auth.users(id),
ADD COLUMN IF NOT EXISTS status_reason TEXT, -- Reason for status change
ADD COLUMN IF NOT EXISTS status_changed_at TIMESTAMPTZ,
ADD COLUMN IF NOT EXISTS status_changed_by UUID REFERENCES auth.users(id),
ADD COLUMN IF NOT EXISTS notes TEXT, -- Admin notes about user
ADD COLUMN IF NOT EXISTS metadata JSONB; -- Flexible metadata storage

-- 3. Create user_activity_log table for comprehensive audit trail
CREATE TABLE IF NOT EXISTS auth.user_activity_log (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    activity_type VARCHAR(50) NOT NULL, -- LOGIN, LOGOUT, PASSWORD_CHANGE, STATUS_CHANGE, ROLE_CHANGE, etc.
    description TEXT,
    ip_address INET,
    user_agent TEXT,
    metadata JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 4. Create user_sessions table for better session management
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

-- 5. Create user_password_history table for password policy compliance
CREATE TABLE IF NOT EXISTS auth.user_password_history (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    password_hash VARCHAR(255) NOT NULL,
    changed_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    changed_by UUID REFERENCES auth.users(id),
    is_temporary BOOLEAN NOT NULL DEFAULT false
);

-- 6. Create user_invitations table for invitation management
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

-- 7. Create user_verification_tokens table for email/phone verification
CREATE TABLE IF NOT EXISTS auth.user_verification_tokens (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    token VARCHAR(255) UNIQUE NOT NULL,
    token_type VARCHAR(20) NOT NULL CHECK (token_type IN ('EMAIL', 'PHONE', 'PASSWORD_RESET')),
    expires_at TIMESTAMPTZ NOT NULL,
    used_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 8. Create user_preferences table for user settings
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

-- 9. Add indexes for performance
CREATE INDEX IF NOT EXISTS idx_users_employee_id ON auth.users(employee_id);
CREATE INDEX IF NOT EXISTS idx_users_manager_id ON auth.users(manager_id);
CREATE INDEX IF NOT EXISTS idx_users_branch_id ON auth.users(branch_id);
CREATE INDEX IF NOT EXISTS idx_users_invitation_token ON auth.users(invitation_token);
CREATE INDEX IF NOT EXISTS idx_users_status_changed_at ON auth.users(status_changed_at);
CREATE INDEX IF NOT EXISTS idx_users_password_expires_at ON auth.users(password_expires_at);
CREATE INDEX IF NOT EXISTS idx_users_hire_date ON auth.users(hire_date);
CREATE INDEX IF NOT EXISTS idx_users_department ON auth.users(department);

CREATE INDEX IF NOT EXISTS idx_user_activity_log_user_id ON auth.user_activity_log(user_id);
CREATE INDEX IF NOT EXISTS idx_user_activity_log_activity_type ON auth.user_activity_log(activity_type);
CREATE INDEX IF NOT EXISTS idx_user_activity_log_created_at ON auth.user_activity_log(created_at);

CREATE INDEX IF NOT EXISTS idx_user_sessions_user_id ON auth.user_sessions(user_id);
CREATE INDEX IF NOT EXISTS idx_user_sessions_session_token ON auth.user_sessions(session_token);
CREATE INDEX IF NOT EXISTS idx_user_sessions_refresh_token ON auth.user_sessions(refresh_token);
CREATE INDEX IF NOT EXISTS idx_user_sessions_expires_at ON auth.user_sessions(expires_at);

CREATE INDEX IF NOT EXISTS idx_user_password_history_user_id ON auth.user_password_history(user_id);
CREATE INDEX IF NOT EXISTS idx_user_password_history_changed_at ON auth.user_password_history(changed_at);

CREATE INDEX IF NOT EXISTS idx_user_invitations_email ON auth.user_invitations(email);
CREATE INDEX IF NOT EXISTS idx_user_invitations_token ON auth.user_invitations(token);
CREATE INDEX IF NOT EXISTS idx_user_invitations_status ON auth.user_invitations(status);
CREATE INDEX IF NOT EXISTS idx_user_invitations_expires_at ON auth.user_invitations(expires_at);

CREATE INDEX IF NOT EXISTS idx_user_verification_tokens_user_id ON auth.user_verification_tokens(user_id);
CREATE INDEX IF NOT EXISTS idx_user_verification_tokens_token ON auth.user_verification_tokens(token);
CREATE INDEX IF NOT EXISTS idx_user_verification_tokens_token_type ON auth.user_verification_tokens(token_type);
CREATE INDEX IF NOT EXISTS idx_user_verification_tokens_expires_at ON auth.user_verification_tokens(expires_at);

-- 10. Add triggers for automatic timestamp updates
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE 'plpgsql';

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'update_user_sessions_updated_at') THEN
        CREATE TRIGGER update_user_sessions_updated_at BEFORE UPDATE ON auth.user_sessions
            FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
    END IF;
END;
$$;

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'update_user_invitations_updated_at') THEN
        CREATE TRIGGER update_user_invitations_updated_at BEFORE UPDATE ON auth.user_invitations
            FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
    END IF;
END;
$$;

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'update_user_preferences_updated_at') THEN
        CREATE TRIGGER update_user_preferences_updated_at BEFORE UPDATE ON auth.user_preferences
            FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
    END IF;
END;
$$;

-- 11. Add functions for common user management operations

-- Function to create user invitation
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
    -- Generate secure token
    v_token := encode(gen_random_bytes(32), 'hex');
    
    -- Create invitation
    INSERT INTO auth.user_invitations (
        email, token, role_id, invited_by, expires_at
    ) VALUES (
        p_email, v_token, p_role_id, p_invited_by, 
        NOW() + (p_expires_in_hours || ' hours')::INTERVAL
    ) RETURNING id INTO v_invitation_id;
    
    RETURN v_invitation_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to log user activity
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

-- Function to check if user can change password (password history policy)
CREATE OR REPLACE FUNCTION auth.can_change_password(
    p_user_id UUID,
    p_new_password_hash VARCHAR(255)
) RETURNS BOOLEAN AS $$
DECLARE
    v_password_count INTEGER;
    v_password_exists BOOLEAN;
BEGIN
    -- Check if password exists in recent history (last 5 passwords)
    SELECT COUNT(*) INTO v_password_count
    FROM auth.user_password_history
    WHERE user_id = p_user_id
    ORDER BY changed_at DESC
    LIMIT 5;
    
    -- Check if new password hash already exists in history
    SELECT EXISTS(
        SELECT 1 FROM auth.user_password_history 
        WHERE user_id = p_user_id AND password_hash = p_new_password_hash
    ) INTO v_password_exists;
    
    -- Return false if password exists in history
    RETURN NOT v_password_exists;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 12. Update existing users with default values
UPDATE auth.users SET status = 'ACTIVE' WHERE status IS NULL;
UPDATE auth.users SET must_change_password = false WHERE must_change_password IS NULL;
UPDATE auth.users SET login_count = 0 WHERE login_count IS NULL;

-- 13. Create default user preferences for existing users
INSERT INTO auth.user_preferences (user_id)
SELECT id FROM auth.users 
WHERE id NOT IN (SELECT user_id FROM auth.user_preferences);

-- +goose Down
DROP FUNCTION IF EXISTS auth.can_change_password(UUID, VARCHAR);
DROP FUNCTION IF EXISTS auth.log_user_activity(UUID, VARCHAR, TEXT, INET, TEXT, JSONB);
DROP FUNCTION IF EXISTS auth.create_user_invitation(VARCHAR, INTEGER, UUID, INTEGER);
DROP TRIGGER IF EXISTS update_user_preferences_updated_at ON auth.user_preferences;
DROP TRIGGER IF EXISTS update_user_invitations_updated_at ON auth.user_invitations;
DROP TRIGGER IF EXISTS update_user_sessions_updated_at ON auth.user_sessions;
DROP FUNCTION IF EXISTS update_updated_at_column();
DROP TABLE IF EXISTS auth.user_preferences;
DROP TABLE IF EXISTS auth.user_verification_tokens;
DROP TABLE IF EXISTS auth.user_invitations;
DROP TABLE IF EXISTS auth.user_password_history;
DROP TABLE IF EXISTS auth.user_sessions;
DROP TABLE IF EXISTS auth.user_activity_log;
ALTER TABLE auth.users
DROP COLUMN IF EXISTS metadata,
DROP COLUMN IF EXISTS notes,
DROP COLUMN IF EXISTS status_changed_by,
DROP COLUMN IF EXISTS status_changed_at,
DROP COLUMN IF EXISTS status_reason,
DROP COLUMN IF EXISTS invited_by,
DROP COLUMN IF EXISTS invitation_accepted_at,
DROP COLUMN IF EXISTS invitation_expires_at,
DROP COLUMN IF EXISTS invitation_token,
DROP COLUMN IF EXISTS login_count,
DROP COLUMN IF EXISTS password_history,
DROP COLUMN IF EXISTS last_password_change,
DROP COLUMN IF EXISTS password_expires_at,
DROP COLUMN IF EXISTS email_verified_at,
DROP COLUMN IF EXISTS phone_verified_at,
DROP COLUMN IF EXISTS country,
DROP COLUMN IF EXISTS postal_code,
DROP COLUMN IF EXISTS state,
DROP COLUMN IF EXISTS city,
DROP COLUMN IF EXISTS address,
DROP COLUMN IF EXISTS branch_id,
DROP COLUMN IF EXISTS position,
DROP COLUMN IF EXISTS department,
DROP COLUMN IF EXISTS manager_id,
DROP COLUMN IF EXISTS termination_date,
DROP COLUMN IF EXISTS hire_date,
DROP COLUMN IF EXISTS employee_id; 