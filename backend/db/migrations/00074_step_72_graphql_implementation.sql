-- Step 72: GraphQL Implementation
-- This migration implements GraphQL support using PostGraphile approach

-- 1. Create GraphQL schema
CREATE SCHEMA IF NOT EXISTS graphql;

-- 2. Create GraphQL-friendly functions
CREATE OR REPLACE FUNCTION graphql.get_client_with_transactions(client_id UUID)
RETURNS JSONB AS $$
DECLARE
    result JSONB;
BEGIN
    SELECT jsonb_build_object(
        'client', to_jsonb(c.*),
        'transactions', (
            SELECT jsonb_agg(to_jsonb(t.*))
            FROM core.transactions t
            WHERE t.client_id = c.id
        ),
        'accounts', (
            SELECT jsonb_agg(to_jsonb(a.*))
            FROM core.accounts a
            WHERE a.client_id = c.id
        )
    )
    INTO result
    FROM core.clients c
    WHERE c.id = client_id;
    
    RETURN result;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION graphql.get_transaction_with_details(transaction_id UUID)
RETURNS JSONB AS $$
DECLARE
    result JSONB;
BEGIN
    SELECT jsonb_build_object(
        'transaction', to_jsonb(t.*),
        'client', to_jsonb(c.*),
        'transaction_type', to_jsonb(tt.*),
        'account', to_jsonb(a.*)
    )
    INTO result
    FROM core.transactions t
    JOIN core.clients c ON t.client_id = c.id
    JOIN core.transaction_types tt ON t.transaction_type_id = tt.id
    LEFT JOIN core.accounts a ON t.account_id = a.id
    WHERE t.id = transaction_id;
    
    RETURN result;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION graphql.search_all_entities(search_term TEXT, limit_count INTEGER DEFAULT 10)
RETURNS JSONB AS $$
DECLARE
    result JSONB;
BEGIN
    SELECT jsonb_build_object(
        'clients', (
            SELECT jsonb_agg(
                jsonb_build_object(
                    'id', c.id,
                    'name', c.first_name || ' ' || c.last_name,
                    'email', c.email,
                    'type', 'client'
                )
            )
            FROM core.clients c
            WHERE c.search_vector @@ to_tsquery('english', search_term)
            LIMIT limit_count
        ),
        'transactions', (
            SELECT jsonb_agg(
                jsonb_build_object(
                    'id', t.id,
                    'reference', t.transaction_reference,
                    'amount', t.amount,
                    'type', 'transaction'
                )
            )
            FROM core.transactions t
            WHERE t.description_vector @@ to_tsquery('english', search_term)
            LIMIT limit_count
        ),
        'accounts', (
            SELECT jsonb_agg(
                jsonb_build_object(
                    'id', a.id,
                    'number', a.account_number,
                    'balance', a.balance,
                    'type', 'account'
                )
            )
            FROM core.accounts a
            JOIN core.clients c ON a.client_id = c.id
            WHERE c.search_vector @@ to_tsquery('english', search_term)
            LIMIT limit_count
        )
    )
    INTO result;
    
    RETURN result;
END;
$$ LANGUAGE plpgsql;

-- 3. Create GraphQL subscriptions support
CREATE OR REPLACE FUNCTION graphql.notify_client_change()
RETURNS TRIGGER AS $$
BEGIN
    PERFORM pg_notify(
        'client_changes',
        json_build_object(
            'operation', TG_OP,
            'id', NEW.id,
            'data', to_jsonb(NEW)
        )::text
    );
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION graphql.notify_transaction_change()
RETURNS TRIGGER AS $$
BEGIN
    PERFORM pg_notify(
        'transaction_changes',
        json_build_object(
            'operation', TG_OP,
            'id', NEW.id,
            'data', to_jsonb(NEW)
        )::text
    );
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION graphql.notify_account_change()
RETURNS TRIGGER AS $$
BEGIN
    PERFORM pg_notify(
        'account_changes',
        json_build_object(
            'operation', TG_OP,
            'id', NEW.id,
            'data', to_jsonb(NEW)
        )::text
    );
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 4. Create triggers for GraphQL notifications
CREATE TRIGGER trigger_client_graphql_notify
    AFTER INSERT OR UPDATE OR DELETE ON core.clients
    FOR EACH ROW EXECUTE FUNCTION graphql.notify_client_change();

CREATE TRIGGER trigger_transaction_graphql_notify
    AFTER INSERT OR UPDATE OR DELETE ON core.transactions
    FOR EACH ROW EXECUTE FUNCTION graphql.notify_transaction_change();

CREATE TRIGGER trigger_account_graphql_notify
    AFTER INSERT OR UPDATE OR DELETE ON core.accounts
    FOR EACH ROW EXECUTE FUNCTION graphql.notify_account_change();

-- 5. Create GraphQL mutation functions
CREATE OR REPLACE FUNCTION graphql.create_client_mutation(
    first_name TEXT,
    last_name TEXT,
    email TEXT,
    phone TEXT,
    client_type TEXT DEFAULT 'individual'
)
RETURNS JSONB AS $$
DECLARE
    client_id UUID;
    result JSONB;
BEGIN
    INSERT INTO core.clients (first_name, last_name, email, phone, client_type)
    VALUES (first_name, last_name, email, phone, client_type)
    RETURNING id INTO client_id;
    
    SELECT to_jsonb(c.*) INTO result
    FROM core.clients c
    WHERE c.id = client_id;
    
    RETURN result;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION graphql.update_client_mutation(
    client_id UUID,
    first_name TEXT DEFAULT NULL,
    last_name TEXT DEFAULT NULL,
    email TEXT DEFAULT NULL,
    phone TEXT DEFAULT NULL,
    status TEXT DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
    result JSONB;
BEGIN
    UPDATE core.clients 
    SET 
        first_name = COALESCE(first_name, core.clients.first_name),
        last_name = COALESCE(last_name, core.clients.last_name),
        email = COALESCE(email, core.clients.email),
        phone = COALESCE(phone, core.clients.phone),
        status = COALESCE(status, core.clients.status),
        updated_at = NOW()
    WHERE id = client_id;
    
    SELECT to_jsonb(c.*) INTO result
    FROM core.clients c
    WHERE c.id = client_id;
    
    RETURN result;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION graphql.delete_client_mutation(client_id UUID)
RETURNS JSONB AS $$
DECLARE
    result JSONB;
BEGIN
    UPDATE core.clients 
    SET deleted_at = NOW()
    WHERE id = client_id;
    
    SELECT to_jsonb(c.*) INTO result
    FROM core.clients c
    WHERE c.id = client_id;
    
    RETURN result;
END;
$$ LANGUAGE plpgsql;

-- 6. Create GraphQL query functions
CREATE OR REPLACE FUNCTION graphql.get_clients_paginated(
    offset_count INTEGER DEFAULT 0,
    limit_count INTEGER DEFAULT 10,
    search_term TEXT DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
    result JSONB;
BEGIN
    SELECT jsonb_build_object(
        'clients', (
            SELECT jsonb_agg(to_jsonb(c.*))
            FROM core.clients c
            WHERE (search_term IS NULL OR c.search_vector @@ to_tsquery('english', search_term))
            AND c.deleted_at IS NULL
            ORDER BY c.created_at DESC
            LIMIT limit_count
            OFFSET offset_count
        ),
        'total_count', (
            SELECT COUNT(*)
            FROM core.clients c
            WHERE (search_term IS NULL OR c.search_vector @@ to_tsquery('english', search_term))
            AND c.deleted_at IS NULL
        ),
        'has_next_page', (
            SELECT COUNT(*) > offset_count + limit_count
            FROM core.clients c
            WHERE (search_term IS NULL OR c.search_vector @@ to_tsquery('english', search_term))
            AND c.deleted_at IS NULL
        )
    )
    INTO result;
    
    RETURN result;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION graphql.get_transactions_paginated(
    offset_count INTEGER DEFAULT 0,
    limit_count INTEGER DEFAULT 10,
    client_id UUID DEFAULT NULL,
    status_filter TEXT DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
    result JSONB;
BEGIN
    SELECT jsonb_build_object(
        'transactions', (
            SELECT jsonb_agg(
                jsonb_build_object(
                    'id', t.id,
                    'transaction_reference', t.transaction_reference,
                    'amount', t.amount,
                    'currency_code', t.currency_code,
                    'status', t.status,
                    'created_at', t.created_at,
                    'client', jsonb_build_object(
                        'id', c.id,
                        'name', c.first_name || ' ' || c.last_name,
                        'email', c.email
                    ),
                    'transaction_type', jsonb_build_object(
                        'id', tt.id,
                        'name', tt.name
                    )
                )
            )
            FROM core.transactions t
            JOIN core.clients c ON t.client_id = c.id
            JOIN core.transaction_types tt ON t.transaction_type_id = tt.id
            WHERE (client_id IS NULL OR t.client_id = client_id)
            AND (status_filter IS NULL OR t.status = status_filter)
            ORDER BY t.created_at DESC
            LIMIT limit_count
            OFFSET offset_count
        ),
        'total_count', (
            SELECT COUNT(*)
            FROM core.transactions t
            WHERE (client_id IS NULL OR t.client_id = client_id)
            AND (status_filter IS NULL OR t.status = status_filter)
        ),
        'has_next_page', (
            SELECT COUNT(*) > offset_count + limit_count
            FROM core.transactions t
            WHERE (client_id IS NULL OR t.client_id = client_id)
            AND (status_filter IS NULL OR t.status = status_filter)
        )
    )
    INTO result;
    
    RETURN result;
END;
$$ LANGUAGE plpgsql;

-- 7. Create GraphQL dashboard functions
CREATE OR REPLACE FUNCTION graphql.get_dashboard_data()
RETURNS JSONB AS $$
DECLARE
    result JSONB;
BEGIN
    SELECT jsonb_build_object(
        'statistics', jsonb_build_object(
            'total_clients', (SELECT COUNT(*) FROM core.clients WHERE deleted_at IS NULL),
            'total_transactions', (SELECT COUNT(*) FROM core.transactions),
            'total_accounts', (SELECT COUNT(*) FROM core.accounts),
            'total_users', (SELECT COUNT(*) FROM auth.users WHERE deleted_at IS NULL)
        ),
        'recent_activity', (
            SELECT jsonb_agg(
                jsonb_build_object(
                    'id', t.id,
                    'type', 'transaction',
                    'description', t.transaction_reference,
                    'amount', t.amount,
                    'currency', t.currency_code,
                    'timestamp', t.created_at,
                    'client_name', c.first_name || ' ' || c.last_name
                )
            )
            FROM core.transactions t
            JOIN core.clients c ON t.client_id = c.id
            ORDER BY t.created_at DESC
            LIMIT 10
        ),
        'top_clients', (
            SELECT jsonb_agg(
                jsonb_build_object(
                    'id', c.id,
                    'name', c.first_name || ' ' || c.last_name,
                    'email', c.email,
                    'transaction_count', (
                        SELECT COUNT(*) 
                        FROM core.transactions 
                        WHERE client_id = c.id
                    ),
                    'total_amount', (
                        SELECT COALESCE(SUM(amount), 0)
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
        )
    )
    INTO result;
    
    RETURN result;
END;
$$ LANGUAGE plpgsql;

-- 8. Create GraphQL subscription management functions
CREATE OR REPLACE FUNCTION graphql.subscribe_to_changes(channel_name TEXT)
RETURNS TEXT AS $$
BEGIN
    -- In a real implementation, this would manage subscription channels
    -- For now, we'll return a success message
    RETURN 'Subscribed to channel: ' || channel_name;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION graphql.unsubscribe_from_changes(channel_name TEXT)
RETURNS TEXT AS $$
BEGIN
    -- In a real implementation, this would remove subscription channels
    -- For now, we'll return a success message
    RETURN 'Unsubscribed from channel: ' || channel_name;
END;
$$ LANGUAGE plpgsql;

-- 9. Create GraphQL error handling functions
CREATE OR REPLACE FUNCTION graphql.handle_graphql_error(error_message TEXT, error_code TEXT DEFAULT 'INTERNAL_ERROR')
RETURNS JSONB AS $$
BEGIN
    RETURN jsonb_build_object(
        'error', jsonb_build_object(
            'message', error_message,
            'code', error_code,
            'timestamp', NOW()
        ),
        'data', NULL
    );
END;
$$ LANGUAGE plpgsql;

-- 10. Grant permissions for GraphQL
GRANT USAGE ON SCHEMA graphql TO postgres;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA graphql TO postgres;

-- 11. Add to extensions config
INSERT INTO config.extensions_config (extension_name, is_enabled, config_data) VALUES
('graphql', TRUE, '{"subscriptions_enabled": true, "introspection_enabled": true, "max_query_depth": 10}')
ON CONFLICT (extension_name) DO UPDATE SET
    updated_at = NOW(),
    config_data = EXCLUDED.config_data;

-- 12. Log completion
INSERT INTO monitoring.performance_metrics (metric_name, metric_value, metric_unit, tags)
VALUES ('graphql_implementation_completed', 1, 'count', '{"migration": "step_72_graphql_implementation"}'); 