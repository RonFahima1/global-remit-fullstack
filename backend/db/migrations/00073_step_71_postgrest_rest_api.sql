-- Step 71: PostgREST REST API Implementation
-- This migration implements REST API layer using PostgREST approach

-- 1. Create REST API schema
CREATE SCHEMA IF NOT EXISTS rest_api;

-- 2. Create REST API views for common operations
CREATE OR REPLACE VIEW rest_api.clients_summary AS
SELECT 
    id,
    first_name,
    last_name,
    email,
    phone,
    status,
    client_type,
    created_at,
    updated_at
FROM core.clients
WHERE deleted_at IS NULL;

CREATE OR REPLACE VIEW rest_api.transactions_summary AS
SELECT 
    t.id,
    t.transaction_reference,
    t.amount,
    t.currency_code,
    t.status,
    t.created_at,
    c.first_name || ' ' || c.last_name AS customer_name,
    c.email AS customer_email,
    tt.name AS transaction_type
FROM core.transactions t
JOIN core.clients c ON t.client_id = c.id
JOIN core.transaction_types tt ON t.transaction_type_id = tt.id;

CREATE OR REPLACE VIEW rest_api.accounts_summary AS
SELECT 
    a.id,
    a.account_number,
    a.balance,
    a.currency_code,
    a.status,
    a.created_at,
    c.first_name || ' ' || c.last_name AS customer_name,
    c.email AS customer_email,
    at.name AS account_type
FROM core.accounts a
JOIN core.clients c ON a.client_id = c.id
JOIN core.account_types at ON a.account_type_id = at.id;

CREATE OR REPLACE VIEW rest_api.users_summary AS
SELECT 
    u.id,
    u.email,
    u.first_name,
    u.last_name,
    u.username,
    u.status,
    u.created_at,
    u.updated_at,
    COALESCE(r.name, '') as role
FROM auth.users u
LEFT JOIN auth.user_roles ur ON ur.user_id = u.id
LEFT JOIN auth.roles r ON r.id = ur.role_id
WHERE u.deleted_at IS NULL;

-- 3. Create REST API functions
CREATE OR REPLACE FUNCTION rest_api.search_clients(search_term TEXT)
RETURNS TABLE (
    id UUID,
    first_name TEXT,
    last_name TEXT,
    email TEXT,
    phone TEXT,
    rank float
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        c.id,
        c.first_name,
        c.last_name,
        c.email,
        c.phone,
        ts_rank(c.search_vector, query) as rank
    FROM core.clients c, to_tsquery('english', search_term) query
    WHERE c.search_vector @@ query
    ORDER BY rank DESC;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION rest_api.search_transactions(search_term TEXT)
RETURNS TABLE (
    id UUID,
    transaction_reference TEXT,
    amount NUMERIC,
    currency_code TEXT,
    status TEXT,
    created_at TIMESTAMPTZ,
    customer_name TEXT,
    rank float
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        t.id,
        t.transaction_reference,
        t.amount,
        t.currency_code,
        t.status,
        t.created_at,
        c.first_name || ' ' || c.last_name AS customer_name,
        ts_rank(t.description_vector, query) as rank
    FROM core.transactions t
    JOIN core.clients c ON t.client_id = c.id
    , to_tsquery('english', search_term) query
    WHERE t.description_vector @@ query
    ORDER BY rank DESC;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION rest_api.get_client_details(client_id UUID)
RETURNS TABLE (
    id UUID,
    first_name TEXT,
    last_name TEXT,
    email TEXT,
    phone TEXT,
    status TEXT,
    client_type TEXT,
    created_at TIMESTAMPTZ,
    updated_at TIMESTAMPTZ,
    accounts JSONB,
    transactions JSONB
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        c.id,
        c.first_name,
        c.last_name,
        c.email,
        c.phone,
        c.status,
        c.client_type,
        c.created_at,
        c.updated_at,
        (
            SELECT jsonb_agg(
                jsonb_build_object(
                    'id', a.id,
                    'account_number', a.account_number,
                    'balance', a.balance,
                    'currency_code', a.currency_code,
                    'status', a.status,
                    'account_type', at.name
                )
            )
            FROM core.accounts a
            JOIN core.account_types at ON a.account_type_id = at.id
            WHERE a.client_id = c.id
        ) as accounts,
        (
            SELECT jsonb_agg(
                jsonb_build_object(
                    'id', t.id,
                    'transaction_reference', t.transaction_reference,
                    'amount', t.amount,
                    'currency_code', t.currency_code,
                    'status', t.status,
                    'created_at', t.created_at,
                    'transaction_type', tt.name
                )
            )
            FROM core.transactions t
            JOIN core.transaction_types tt ON t.transaction_type_id = tt.id
            WHERE t.client_id = c.id
            ORDER BY t.created_at DESC
            LIMIT 10
        ) as transactions
    FROM core.clients c
    WHERE c.id = client_id;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION rest_api.get_transaction_details(transaction_id UUID)
RETURNS TABLE (
    id UUID,
    transaction_reference TEXT,
    amount NUMERIC,
    currency_code TEXT,
    status TEXT,
    description TEXT,
    created_at TIMESTAMPTZ,
    updated_at TIMESTAMPTZ,
    customer JSONB,
    transaction_type JSONB
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        t.id,
        t.transaction_reference,
        t.amount,
        t.currency_code,
        t.status,
        t.description,
        t.created_at,
        t.updated_at,
        jsonb_build_object(
            'id', c.id,
            'first_name', c.first_name,
            'last_name', c.last_name,
            'email', c.email,
            'phone', c.phone
        ) as customer,
        jsonb_build_object(
            'id', tt.id,
            'name', tt.name,
            'description', tt.description
        ) as transaction_type
    FROM core.transactions t
    JOIN core.clients c ON t.client_id = c.id
    JOIN core.transaction_types tt ON t.transaction_type_id = tt.id
    WHERE t.id = transaction_id;
END;
$$ LANGUAGE plpgsql;

-- 4. Create REST API statistics functions
CREATE OR REPLACE FUNCTION rest_api.get_dashboard_stats()
RETURNS TABLE (
    total_clients INTEGER,
    total_transactions INTEGER,
    total_accounts INTEGER,
    total_users INTEGER,
    recent_transactions JSONB,
    top_clients JSONB
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        (SELECT COUNT(*) FROM core.clients WHERE deleted_at IS NULL) as total_clients,
        (SELECT COUNT(*) FROM core.transactions) as total_transactions,
        (SELECT COUNT(*) FROM core.accounts) as total_accounts,
        (SELECT COUNT(*) FROM auth.users WHERE deleted_at IS NULL) as total_users,
        (
            SELECT jsonb_agg(
                jsonb_build_object(
                    'id', t.id,
                    'transaction_reference', t.transaction_reference,
                    'amount', t.amount,
                    'currency_code', t.currency_code,
                    'status', t.status,
                    'created_at', t.created_at,
                    'customer_name', c.first_name || ' ' || c.last_name
                )
            )
            FROM core.transactions t
            JOIN core.clients c ON t.client_id = c.id
            ORDER BY t.created_at DESC
            LIMIT 5
        ) as recent_transactions,
        (
            SELECT jsonb_agg(
                jsonb_build_object(
                    'id', c.id,
                    'name', c.first_name || ' ' || c.last_name,
                    'email', c.email,
                    'transaction_count', (
                        SELECT COUNT(*) 
                        FROM core.transactions 
                        WHERE client_id = c.id
                    )
                )
            )
            FROM core.clients c
            ORDER BY (
                SELECT COUNT(*) 
                FROM core.transactions 
                WHERE client_id = c.id
            ) DESC
            LIMIT 5
        ) as top_clients;
END;
$$ LANGUAGE plpgsql;

-- 5. Create REST API CRUD functions
CREATE OR REPLACE FUNCTION rest_api.create_client(
    p_first_name TEXT,
    p_last_name TEXT,
    p_email TEXT,
    p_phone TEXT,
    p_client_type TEXT DEFAULT 'individual'
)
RETURNS UUID AS $$
DECLARE
    client_id UUID;
BEGIN
    INSERT INTO core.clients (first_name, last_name, email, phone, client_type)
    VALUES (p_first_name, p_last_name, p_email, p_phone, p_client_type)
    RETURNING id INTO client_id;
    
    RETURN client_id;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION rest_api.update_client(
    p_id UUID,
    p_first_name TEXT DEFAULT NULL,
    p_last_name TEXT DEFAULT NULL,
    p_email TEXT DEFAULT NULL,
    p_phone TEXT DEFAULT NULL,
    p_status TEXT DEFAULT NULL
)
RETURNS BOOLEAN AS $$
DECLARE
    rows_affected INTEGER;
BEGIN
    UPDATE core.clients 
    SET 
        first_name = COALESCE(p_first_name, first_name),
        last_name = COALESCE(p_last_name, last_name),
        email = COALESCE(p_email, email),
        phone = COALESCE(p_phone, phone),
        status = COALESCE(p_status, status),
        updated_at = NOW()
    WHERE id = p_id;
    
    GET DIAGNOSTICS rows_affected = ROW_COUNT;
    RETURN rows_affected > 0;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION rest_api.delete_client(p_id UUID)
RETURNS BOOLEAN AS $$
DECLARE
    rows_affected INTEGER;
BEGIN
    UPDATE core.clients 
    SET deleted_at = NOW()
    WHERE id = p_id;
    
    GET DIAGNOSTICS rows_affected = ROW_COUNT;
    RETURN rows_affected > 0;
END;
$$ LANGUAGE plpgsql;

-- 6. Create REST API authentication functions
CREATE OR REPLACE FUNCTION rest_api.authenticate_user(
    p_email TEXT,
    p_password TEXT
)
RETURNS TABLE (
    user_id UUID,
    email TEXT,
    first_name TEXT,
    last_name TEXT,
    role TEXT,
    token TEXT
) AS $$
DECLARE
    user_record RECORD;
    role_name TEXT;
BEGIN
    -- Get user details
    SELECT u.id, u.email, u.first_name, u.last_name, u.password_hash
    INTO user_record
    FROM auth.users u
    WHERE u.email = p_email AND u.deleted_at IS NULL;
    
    -- Check if user exists and password is correct
    IF user_record.id IS NULL OR NOT crypt(p_password, user_record.password_hash) = user_record.password_hash THEN
        RETURN;
    END IF;
    
    -- Get user role
    SELECT r.name INTO role_name
    FROM auth.user_roles ur
    JOIN auth.roles r ON r.id = ur.role_id
    WHERE ur.user_id = user_record.id
    LIMIT 1;
    
    -- Generate JWT token (simplified - in production, use proper JWT library)
    RETURN QUERY
    SELECT 
        user_record.id,
        user_record.email,
        user_record.first_name,
        user_record.last_name,
        COALESCE(role_name, 'user'),
        encode(gen_random_bytes(32), 'hex') as token;
END;
$$ LANGUAGE plpgsql;

-- 7. Create REST API rate limiting functions
CREATE OR REPLACE FUNCTION rest_api.check_rate_limit(
    p_ip_address INET,
    p_endpoint TEXT,
    p_limit_per_minute INTEGER DEFAULT 60
)
RETURNS BOOLEAN AS $$
DECLARE
    request_count INTEGER;
BEGIN
    -- Count requests in the last minute
    SELECT COUNT(*) INTO request_count
    FROM core.api_logs_unlogged
    WHERE ip_address = p_ip_address 
    AND endpoint = p_endpoint
    AND timestamp > NOW() - INTERVAL '1 minute';
    
    RETURN request_count < p_limit_per_minute;
END;
$$ LANGUAGE plpgsql;

-- 8. Grant permissions for PostgREST
GRANT USAGE ON SCHEMA rest_api TO postgres;
GRANT SELECT ON ALL TABLES IN SCHEMA rest_api TO postgres;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA rest_api TO postgres;

-- 9. Create row-level security policies
ALTER TABLE core.clients ENABLE ROW LEVEL SECURITY;
ALTER TABLE core.transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE core.accounts ENABLE ROW LEVEL SECURITY;

-- Create policies for clients
CREATE POLICY clients_select_policy ON core.clients
    FOR SELECT USING (true);

CREATE POLICY clients_insert_policy ON core.clients
    FOR INSERT WITH CHECK (true);

CREATE POLICY clients_update_policy ON core.clients
    FOR UPDATE USING (true);

CREATE POLICY clients_delete_policy ON core.clients
    FOR DELETE USING (true);

-- Create policies for transactions
CREATE POLICY transactions_select_policy ON core.transactions
    FOR SELECT USING (true);

CREATE POLICY transactions_insert_policy ON core.transactions
    FOR INSERT WITH CHECK (true);

CREATE POLICY transactions_update_policy ON core.transactions
    FOR UPDATE USING (true);

CREATE POLICY transactions_delete_policy ON core.transactions
    FOR DELETE USING (true);

-- Create policies for accounts
CREATE POLICY accounts_select_policy ON core.accounts
    FOR SELECT USING (true);

CREATE POLICY accounts_insert_policy ON core.accounts
    FOR INSERT WITH CHECK (true);

CREATE POLICY accounts_update_policy ON core.accounts
    FOR UPDATE USING (true);

CREATE POLICY accounts_delete_policy ON core.accounts
    FOR DELETE USING (true);

-- 10. Add to extensions config
INSERT INTO config.extensions_config (extension_name, is_enabled, config_data) VALUES
('postgrest', TRUE, '{"rate_limit_per_minute": 60, "enable_rls": true, "jwt_secret": "your-secret-key"}')
ON CONFLICT (extension_name) DO UPDATE SET
    updated_at = NOW(),
    config_data = EXCLUDED.config_data;

-- 11. Log completion
INSERT INTO monitoring.performance_metrics (metric_name, metric_value, metric_unit, tags)
VALUES ('postgrest_implementation_completed', 1, 'count', '{"migration": "step_71_postgrest_rest_api"}'); 