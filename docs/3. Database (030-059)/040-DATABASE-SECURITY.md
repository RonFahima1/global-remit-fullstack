# Database Security Guide

## Introduction
This document outlines the security measures and best practices for securing the Global Remit database. It covers authentication, authorization, encryption, auditing, and other security-related aspects to protect sensitive financial data.

## Table of Contents
- [Authentication](#authentication)
- [Authorization](#authorization)
- [Encryption](#encryption)
- [Network Security](#network-security)
- [Audit Logging](#audit-logging)
- [Data Masking](#data-masking)
- [Security Hardening](#security-hardening)
- [Compliance](#compliance)
- [Incident Response](#incident-response)
- [Related Documents](#related-documents)
- [Version History](#version-history)

## Authentication

### 1. Strong Password Policies

```sql
-- Enforce password complexity
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- Function to validate password complexity
CREATE OR REPLACE FUNCTION validate_password_complexity()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.password !~ '^.*[A-Z].*$' THEN
        RAISE EXCEPTION 'Password must contain at least one uppercase letter';
    END IF;
    
    IF NEW.password !~ '^.*[a-z].*$' THEN
        RAISE EXCEPTION 'Password must contain at least one lowercase letter';
    END IF;
    
    IF NEW.password !~ '^.*[0-9].*$' THEN
        RAISE EXCEPTION 'Password must contain at least one number';
    END IF;
    
    IF NEW.password !~ '^.*[^A-Za-z0-9].*$' THEN
        RAISE EXCEPTION 'Password must contain at least one special character';
    END IF;
    
    IF length(NEW.password) < 12 THEN
        RAISE EXCEPTION 'Password must be at least 12 characters long';
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Apply to users table
CREATE TRIGGER enforce_password_complexity
BEFORE INSERT OR UPDATE OF password ON auth.users
FOR EACH ROW EXECUTE FUNCTION validate_password_complexity();
```

### 2. Multi-Factor Authentication (MFA)

```sql
-- Add MFA columns to users table
ALTER TABLE auth.users
ADD COLUMN mfa_secret TEXT,
ADD COLUMN mfa_enabled BOOLEAN DEFAULT FALSE,
ADD COLUMN mfa_recovery_codes TEXT[];
```

### 3. Failed Login Attempts

```sql
-- Track failed login attempts
CREATE TABLE auth.failed_login_attempts (
    id SERIAL PRIMARY KEY,
    username TEXT NOT NULL,
    ip_address INET NOT NULL,
    attempted_at TIMESTAMPTZ DEFAULT NOW(),
    user_agent TEXT
);

-- Create index for performance
CREATE INDEX idx_failed_login_username ON auth.failed_login_attempts(username);
CREATE INDEX idx_failed_login_ip ON auth.failed_login_attempts(ip_address);

-- Function to check login attempts
CREATE OR REPLACE FUNCTION check_login_attempts(p_username TEXT, p_max_attempts INTEGER DEFAULT 5)
RETURNS BOOLEAN AS $$
DECLARE
    v_attempts INTEGER;
    v_locked_until TIMESTAMPTZ;
BEGIN
    -- Count attempts in last 15 minutes
    SELECT COUNT(*)
    INTO v_attempts
    FROM auth.failed_login_attempts
    WHERE username = p_username
    AND attempted_at > (NOW() - INTERVAL '15 minutes');
    
    -- Check if account is locked
    IF v_attempts >= p_max_attempts THEN
        RETURN FALSE;
    END IF;
    
    RETURN TRUE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
```

## Authorization

### 1. Role-Based Access Control (RBAC)

```sql
-- Create roles
CREATE ROLE read_only_role NOLOGIN NOCREATEDB NOCREATEROLE NOINHERIT;
CREATE ROLE read_write_role NOLOGIN NOCREATEDB NOCREATEROLE NOINHERIT;
CREATE ROLE admin_role NOLOGIN NOCREATEDB NOCREATEROLE NOINHERIT;

-- Grant schema usage
GRANT USAGE ON SCHEMA core, auth, reporting TO read_only_role;
GRANT USAGE ON SCHEMA core, auth, reporting TO read_write_role;
GRANT ALL ON SCHEMA core, auth, reporting TO admin_role;

-- Grant table permissions
GRANT SELECT ON ALL TABLES IN SCHEMA core, auth, reporting TO read_only_role;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA core, auth, reporting TO read_write_role;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA core, auth, reporting TO admin_role;

-- Grant sequence permissions
GRANT USAGE ON ALL SEQUENCES IN SCHEMA core, auth, reporting TO read_write_role, admin_role;

-- Create application users
CREATE USER app_read_only WITH PASSWORD 'complex_password_here';
CREATE USER app_read_write WITH PASSWORD 'complex_password_here';
CREATE USER app_admin WITH PASSWORD 'complex_password_here';

-- Assign roles to users
GRANT read_only_role TO app_read_only;
GRANT read_write_role TO app_read_write;
GRANT admin_role TO app_admin;
```

### 2. Row-Level Security (RLS)

```sql
-- Enable RLS on a table
ALTER TABLE core.transactions ENABLE ROW LEVEL SECURITY;

-- Create policies
CREATE POLICY user_owns_transaction ON core.transactions
    USING (account_id IN (
        SELECT id FROM core.accounts WHERE user_id = current_setting('app.current_user_id')::BIGINT
    ));

CREATE POLICY admin_access ON core.transactions
    USING (EXISTS (
        SELECT 1 FROM auth.user_roles ur
        JOIN auth.roles r ON ur.role_id = r.id
        WHERE ur.user_id = current_setting('app.current_user_id')::BIGINT
        AND r.name = 'admin'
    ));
```

## Encryption

### 1. Data at Rest Encryption

```sql
-- Enable encryption extension
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- Encrypt sensitive data
CREATE OR REPLACE FUNCTION encrypt_data(data TEXT, secret_key TEXT)
RETURNS BYTEA AS $$
BEGIN
    RETURN pgp_sym_encrypt(data, secret_key, 'compress-algo=1, cipher-algo=aes256');
END;
$$ LANGUAGE plpgsql;

-- Decrypt data
CREATE OR REPLACE FUNCTION decrypt_data(encrypted_data BYTEA, secret_key TEXT)
RETURNS TEXT AS $$
BEGIN
    RETURN pgp_sym_decrypt(encrypted_data, secret_key);
END;
$$ LANGUAGE plpgsql;

-- Example table with encrypted data
CREATE TABLE core.sensitive_data (
    id SERIAL PRIMARY KEY,
    user_id BIGINT NOT NULL REFERENCES auth.users(id),
    ssn BYTEA,  -- Encrypted
    credit_card BYTEA,  -- Encrypted
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create a trigger to automatically update updated_at
CREATE OR REPLACE FUNCTION update_modified_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_sensitive_data_modtime
BEFORE UPDATE ON core.sensitive_data
FOR EACH ROW EXECUTE FUNCTION update_modified_column();
```

### 2. Transparent Data Encryption (TDE)

For TDE, you would typically use:
1. AWS RDS Encryption at Rest
2. Azure SQL Database TDE
3. Oracle TDE
4. SQL Server TDE

## Network Security

### 1. Connection Security

```sql
-- Require SSL for all connections
ALTER SYSTEM SET ssl = on;
ALTER SYSTEM SET ssl_cert_file = '/path/to/server.crt';
ALTER SYSTEM SET ssl_key_file = '/path/to/server.key';
ALTER SYSTEM SET ssl_ca_file = '/path/to/root.crt';

-- Force SSL for specific users
ALTER USER app_user SET ssl_require = 'require';

-- Restrict connection methods in pg_hba.conf
# TYPE  DATABASE        USER            ADDRESS                 METHOD
hostssl all             all             0.0.0.0/0              cert clientcert=verify-ca
host    replication     replicator      192.168.1.0/24          md5
```

### 2. IP Whitelisting

```sql
-- Restrict access by IP in pg_hba.conf
# TYPE  DATABASE        USER            ADDRESS                 METHOD
host    all             all             192.168.1.0/24          md5
host    all             all             10.0.0.0/8               reject
host    all             all             0.0.0.0/0               reject
```

## Audit Logging

### 1. Audit Trigger

```sql
-- Create audit schema
CREATE SCHEMA audit;

-- Create audit log table
CREATE TABLE audit.logged_actions (
    event_id BIGSERIAL PRIMARY KEY,
    schema_name TEXT NOT NULL,
    table_name TEXT NOT NULL,
    user_name TEXT,
    action_tstamp TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    action TEXT NOT NULL CHECK (action IN ('I','D','U')),
    original_data JSONB,
    new_data JSONB,
    query TEXT,
    client_addr INET,
    application_name TEXT
);

-- Create index for performance
CREATE INDEX idx_audit_table ON audit.logged_actions (schema_name, table_name);
CREATE INDEX idx_audit_action_tstamp ON audit.logged_actions (action_tstamp);

-- Create audit trigger function
CREATE OR REPLACE FUNCTION audit.if_modified_func()
RETURNS TRIGGER AS $$
DECLARE
    v_old_data JSONB;
    v_new_data JSONB;
BEGIN
    IF TG_WHEN <> 'AFTER' THEN
        RAISE EXCEPTION 'audit.if_modified_func() may only run as an AFTER trigger';
    END IF;

    IF (TG_LEVEL = 'ROW') THEN
        IF (TG_OP = 'UPDATE') THEN
            v_old_data := to_jsonb(OLD);
            v_new_data := to_jsonb(NEW);
            INSERT INTO audit.logged_actions (
                schema_name, table_name, user_name, action, 
                original_data, new_data, query, client_addr, application_name
            ) VALUES (
                TG_TABLE_SCHEMA, TG_TABLE_NAME, session_user, TG_OP,
                v_old_data, v_new_data, current_query(), inet_client_addr(), current_setting('application_name', true)
            );
            RETURN NEW;
        ELSIF (TG_OP = 'DELETE') THEN
            v_old_data := to_jsonb(OLD);
            INSERT INTO audit.logged_actions (
                schema_name, table_name, user_name, action, 
                original_data, query, client_addr, application_name
            ) VALUES (
                TG_TABLE_SCHEMA, TG_TABLE_NAME, session_user, TG_OP,
                v_old_data, current_query(), inet_client_addr(), current_setting('application_name', true)
            );
            RETURN OLD;
        ELSIF (TG_OP = 'INSERT') THEN
            v_new_data := to_jsonb(NEW);
            INSERT INTO audit.logged_actions (
                schema_name, table_name, user_name, action, 
                new_data, query, client_addr, application_name
            ) VALUES (
                TG_TABLE_SCHEMA, TG_TABLE_NAME, session_user, TG_OP,
                v_new_data, current_query(), inet_client_addr(), current_setting('application_name', true)
            );
            RETURN NEW;
        ELSE
            RAISE EXCEPTION '[audit.if_modified_func] - Trigger func added as trigger for unhandled op: %', TG_OP;
            RETURN NULL;
        END IF;
    ELSE
        RAISE EXCEPTION '[audit.if_modified_func] - Trigger func added as trigger for unhandled level: %', TG_LEVEL;
        RETURN NULL;
    END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create audit trigger
CREATE TRIGGER audit_transactions
AFTER INSERT OR UPDATE OR DELETE ON core.transactions
FOR EACH ROW EXECUTE FUNCTION audit.if_modified_func();
```

## Data Masking

### 1. Dynamic Data Masking

```sql
-- Create masked view for sensitive data
CREATE OR REPLACE VIEW core.masked_customers AS
SELECT 
    id,
    first_name,
    last_name,
    -- Mask email
    regexp_replace(email, '(?<=.{1}).(?=[^@]*@)', '*', 'g') AS email,
    -- Mask phone
    regexp_replace(phone, '(\d{3})\d{4}(\d{3})', '\1-****-\2') AS phone,
    -- Mask SSN
    '***-**-' || right(ssn::TEXT, 4) AS ssn,
    created_at,
    updated_at
FROM core.customers;

-- Grant access to the masked view
GRANT SELECT ON core.masked_customers TO read_only_role;
```

## Security Hardening

### 1. PostgreSQL Configuration

```ini
# postgresql.conf
# Connection security
ssl = on
password_encryption = scram-sha-256

# Logging
log_connections = on
log_disconnections = on
log_statement = 'ddl'
log_duration = on
log_hostname = on
log_line_prefix = '%t [%p]: [%l-1] user=%u,db=%d,app=%a,client=%h'

# Authentication
auth_delay.milliseconds = '1000'

# Security
shared_preload_libraries = 'pg_stat_statements,auto_explain'
track_io_timing = on
track_activity_query_size = 16384
```

### 2. Regular Security Updates
- Apply security patches promptly
- Monitor PostgreSQL security announcements
- Schedule regular security audits

## Compliance

### 1. GDPR Compliance
```sql
-- Data retention policy
CREATE TABLE compliance.data_retention_policies (
    id SERIAL PRIMARY KEY,
    table_name TEXT NOT NULL,
    retention_period INTERVAL NOT NULL,
    anonymize_after BOOLEAN DEFAULT FALSE,
    delete_after BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Add retention policies
INSERT INTO compliance.data_retention_policies 
    (table_name, retention_period, anonymize_after, delete_after)
VALUES
    ('core.transactions', '5 years', FALSE, TRUE),
    ('core.customers', '10 years', TRUE, FALSE);

-- Function to enforce retention policies
CREATE OR REPLACE FUNCTION compliance.apply_retention_policies()
RETURNS VOID AS $$
DECLARE
    policy_record RECORD;
    query TEXT;
BEGIN
    FOR policy_record IN 
        SELECT * FROM compliance.data_retention_policies 
        WHERE table_name IN (
            SELECT tablename 
            FROM pg_tables 
            WHERE schemaname = 'core' OR schemaname = 'auth'
        )
    LOOP
        -- Anonymize data
        IF policy_record.anonymize_after THEN
            query := format(
                'UPDATE %I SET ' ||
                'first_name = ''REDACTED'', ' ||
                'last_name = ''REDACTED'', ' ||
                'email = ''REDACTED'', ' ||
                'phone = ''REDACTED'', ' ||
                'ssn = NULL ' ||
                'WHERE created_at < NOW() - %L',
                policy_record.table_name,
                policy_record.retention_period
            );
            EXECUTE query;
        END IF;
        
        -- Delete data
        IF policy_record.delete_after THEN
            query := format(
                'DELETE FROM %I WHERE created_at < NOW() - %L',
                policy_record.table_name,
                policy_record.retention_period
            );
            EXECUTE query;
        END IF;
    END LOOP;
END;
$$ LANGUAGE plpgsql;

-- Schedule retention policy job
-- This would typically be run via pg_cron or an external scheduler
SELECT cron.schedule('0 3 * * *', 'SELECT compliance.apply_retention_policies()');
```

## Incident Response

### 1. Security Incident Response Plan

1. **Detection**
   - Monitor logs for suspicious activities
   - Set up alerts for failed login attempts
   - Monitor for unusual data access patterns

2. **Containment**
   - Isolate affected systems
   - Revoke compromised credentials
   - Block suspicious IP addresses

3. **Investigation**
   - Preserve logs and evidence
   - Determine scope of the breach
   - Identify affected data and users

4. **Remediation**
   - Patch vulnerabilities
   - Reset affected credentials
   - Implement additional security controls

5. **Notification**
   - Notify affected parties if required by law
   - Report to relevant authorities if necessary

6. **Post-Incident Review**
   - Document the incident
   - Identify lessons learned
   - Update security policies and procedures

## Related Documents
- [Database Overview](./030-DATABASE-OVERVIEW.md)
- [Backup and Recovery](./038-BACKUP-RECOVERY.md)
- [Performance Tuning](./039-PERFORMANCE-TUNING.md)
- [Security Policy](../2. Security (000-029)/015-SECURITY-POLICY.md)
- [Incident Response Plan](../2. Security (000-029)/017-INCIDENT-RESPONSE.md)

## Version History
| Date | Version | Description |
|------|---------|-------------|
| 2025-06-20 | 1.0 | Initial version |
