-- Step 69: Unlogged Tables Implementation
-- This migration implements unlogged tables for high-volume, temporary data storage

-- 1. Create unlogged tables for high-volume data
CREATE UNLOGGED TABLE core.audit_log_unlogged (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    table_name TEXT NOT NULL,
    operation TEXT NOT NULL,
    old_data JSONB,
    new_data JSONB,
    user_id UUID,
    timestamp TIMESTAMPTZ DEFAULT NOW()
);

CREATE UNLOGGED TABLE core.performance_metrics_unlogged (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    metric_name TEXT NOT NULL,
    metric_value NUMERIC NOT NULL,
    tags JSONB DEFAULT '{}',
    recorded_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE UNLOGGED TABLE core.session_logs_unlogged (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    session_id TEXT NOT NULL,
    user_id UUID,
    action TEXT NOT NULL,
    ip_address INET,
    user_agent TEXT,
    metadata JSONB DEFAULT '{}',
    timestamp TIMESTAMPTZ DEFAULT NOW()
);

CREATE UNLOGGED TABLE core.api_logs_unlogged (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    endpoint TEXT NOT NULL,
    method TEXT NOT NULL,
    status_code INTEGER,
    response_time_ms INTEGER,
    user_id UUID,
    ip_address INET,
    user_agent TEXT,
    request_body JSONB,
    response_body JSONB,
    timestamp TIMESTAMPTZ DEFAULT NOW()
);

-- 2. Create indexes on unlogged tables
CREATE INDEX idx_audit_log_timestamp ON core.audit_log_unlogged(timestamp);
CREATE INDEX idx_audit_log_table_operation ON core.audit_log_unlogged(table_name, operation);
CREATE INDEX idx_audit_log_user_id ON core.audit_log_unlogged(user_id);

CREATE INDEX idx_performance_metrics_name_time ON core.performance_metrics_unlogged(metric_name, recorded_at);
CREATE INDEX idx_performance_metrics_recorded_at ON core.performance_metrics_unlogged(recorded_at);

CREATE INDEX idx_session_logs_session_id ON core.session_logs_unlogged(session_id);
CREATE INDEX idx_session_logs_user_id ON core.session_logs_unlogged(user_id);
CREATE INDEX idx_session_logs_timestamp ON core.session_logs_unlogged(timestamp);

CREATE INDEX idx_api_logs_endpoint ON core.api_logs_unlogged(endpoint);
CREATE INDEX idx_api_logs_status_code ON core.api_logs_unlogged(status_code);
CREATE INDEX idx_api_logs_timestamp ON core.api_logs_unlogged(timestamp);
CREATE INDEX idx_api_logs_user_id ON core.api_logs_unlogged(user_id);

-- 3. Create function to migrate unlogged to logged tables
CREATE OR REPLACE FUNCTION core.migrate_unlogged_to_logged()
RETURNS VOID AS $$
BEGIN
    -- Create logged version of audit log
    CREATE TABLE IF NOT EXISTS core.audit_log AS 
    SELECT * FROM core.audit_log_unlogged WHERE timestamp > NOW() - INTERVAL '7 days';
    
    -- Create logged version of performance metrics
    CREATE TABLE IF NOT EXISTS core.performance_metrics_logged AS 
    SELECT * FROM core.performance_metrics_unlogged WHERE recorded_at > NOW() - INTERVAL '24 hours';
    
    -- Create logged version of session logs
    CREATE TABLE IF NOT EXISTS core.session_logs_logged AS 
    SELECT * FROM core.session_logs_unlogged WHERE timestamp > NOW() - INTERVAL '7 days';
    
    -- Create logged version of API logs
    CREATE TABLE IF NOT EXISTS core.api_logs_logged AS 
    SELECT * FROM core.api_logs_unlogged WHERE timestamp > NOW() - INTERVAL '7 days';
    
    -- Truncate unlogged tables
    TRUNCATE core.audit_log_unlogged;
    TRUNCATE core.performance_metrics_unlogged;
    TRUNCATE core.session_logs_unlogged;
    TRUNCATE core.api_logs_unlogged;
END;
$$ LANGUAGE plpgsql;

-- 4. Create function to log audit events
CREATE OR REPLACE FUNCTION core.log_audit_event(
    p_table_name TEXT,
    p_operation TEXT,
    p_old_data JSONB DEFAULT NULL,
    p_new_data JSONB DEFAULT NULL,
    p_user_id UUID DEFAULT NULL
)
RETURNS UUID AS $$
DECLARE
    event_id UUID;
BEGIN
    INSERT INTO core.audit_log_unlogged (table_name, operation, old_data, new_data, user_id)
    VALUES (p_table_name, p_operation, p_old_data, p_new_data, p_user_id)
    RETURNING id INTO event_id;
    
    RETURN event_id;
END;
$$ LANGUAGE plpgsql;

-- 5. Create function to log performance metrics
CREATE OR REPLACE FUNCTION core.log_performance_metric(
    p_metric_name TEXT,
    p_metric_value NUMERIC,
    p_tags JSONB DEFAULT '{}'
)
RETURNS UUID AS $$
DECLARE
    metric_id UUID;
BEGIN
    INSERT INTO core.performance_metrics_unlogged (metric_name, metric_value, tags)
    VALUES (p_metric_name, p_metric_value, p_tags)
    RETURNING id INTO metric_id;
    
    RETURN metric_id;
END;
$$ LANGUAGE plpgsql;

-- 6. Create function to log session events
CREATE OR REPLACE FUNCTION core.log_session_event(
    p_session_id TEXT,
    p_action TEXT,
    p_user_id UUID DEFAULT NULL,
    p_ip_address INET DEFAULT NULL,
    p_user_agent TEXT DEFAULT NULL,
    p_metadata JSONB DEFAULT '{}'
)
RETURNS UUID AS $$
DECLARE
    event_id UUID;
BEGIN
    INSERT INTO core.session_logs_unlogged (session_id, action, user_id, ip_address, user_agent, metadata)
    VALUES (p_session_id, p_action, p_user_id, p_ip_address, p_user_agent, p_metadata)
    RETURNING id INTO event_id;
    
    RETURN event_id;
END;
$$ LANGUAGE plpgsql;

-- 7. Create function to log API requests
CREATE OR REPLACE FUNCTION core.log_api_request(
    p_endpoint TEXT,
    p_method TEXT,
    p_status_code INTEGER,
    p_response_time_ms INTEGER,
    p_user_id UUID DEFAULT NULL,
    p_ip_address INET DEFAULT NULL,
    p_user_agent TEXT DEFAULT NULL,
    p_request_body JSONB DEFAULT NULL,
    p_response_body JSONB DEFAULT NULL
)
RETURNS UUID AS $$
DECLARE
    log_id UUID;
BEGIN
    INSERT INTO core.api_logs_unlogged (
        endpoint, method, status_code, response_time_ms, 
        user_id, ip_address, user_agent, request_body, response_body
    )
    VALUES (
        p_endpoint, p_method, p_status_code, p_response_time_ms,
        p_user_id, p_ip_address, p_user_agent, p_request_body, p_response_body
    )
    RETURNING id INTO log_id;
    
    RETURN log_id;
END;
$$ LANGUAGE plpgsql;

-- 8. Create maintenance function for unlogged tables
CREATE OR REPLACE FUNCTION core.maintain_unlogged_tables()
RETURNS TABLE (
    table_name TEXT,
    action TEXT,
    records_processed INTEGER
) AS $$
DECLARE
    audit_count INTEGER;
    metrics_count INTEGER;
    session_count INTEGER;
    api_count INTEGER;
BEGIN
    -- Archive old audit logs
    INSERT INTO core.audit_log 
    SELECT * FROM core.audit_log_unlogged 
    WHERE timestamp < NOW() - INTERVAL '1 hour';
    
    GET DIAGNOSTICS audit_count = ROW_COUNT;
    
    DELETE FROM core.audit_log_unlogged 
    WHERE timestamp < NOW() - INTERVAL '1 hour';
    
    -- Archive old performance metrics
    INSERT INTO core.performance_metrics_logged 
    SELECT * FROM core.performance_metrics_unlogged 
    WHERE recorded_at < NOW() - INTERVAL '1 hour';
    
    GET DIAGNOSTICS metrics_count = ROW_COUNT;
    
    DELETE FROM core.performance_metrics_unlogged 
    WHERE recorded_at < NOW() - INTERVAL '1 hour';
    
    -- Archive old session logs
    INSERT INTO core.session_logs_logged 
    SELECT * FROM core.session_logs_unlogged 
    WHERE timestamp < NOW() - INTERVAL '1 hour';
    
    GET DIAGNOSTICS session_count = ROW_COUNT;
    
    DELETE FROM core.session_logs_unlogged 
    WHERE timestamp < NOW() - INTERVAL '1 hour';
    
    -- Archive old API logs
    INSERT INTO core.api_logs_logged 
    SELECT * FROM core.api_logs_unlogged 
    WHERE timestamp < NOW() - INTERVAL '1 hour';
    
    GET DIAGNOSTICS api_count = ROW_COUNT;
    
    DELETE FROM core.api_logs_unlogged 
    WHERE timestamp < NOW() - INTERVAL '1 hour';
    
    RETURN QUERY VALUES
        ('audit_log'::TEXT, 'archived'::TEXT, audit_count),
        ('performance_metrics'::TEXT, 'archived'::TEXT, metrics_count),
        ('session_logs'::TEXT, 'archived'::TEXT, session_count),
        ('api_logs'::TEXT, 'archived'::TEXT, api_count);
END;
$$ LANGUAGE plpgsql;

-- 9. Create statistics function for unlogged tables
CREATE OR REPLACE FUNCTION core.get_unlogged_table_stats()
RETURNS TABLE (
    table_name TEXT,
    current_rows INTEGER,
    table_size TEXT,
    index_size TEXT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        'audit_log_unlogged'::TEXT as table_name,
        (SELECT COUNT(*) FROM core.audit_log_unlogged) as current_rows,
        pg_size_pretty(pg_total_relation_size('core.audit_log_unlogged')) as table_size,
        pg_size_pretty(pg_relation_size('idx_audit_log_timestamp')) as index_size
    
    UNION ALL
    
    SELECT 
        'performance_metrics_unlogged'::TEXT as table_name,
        (SELECT COUNT(*) FROM core.performance_metrics_unlogged) as current_rows,
        pg_size_pretty(pg_total_relation_size('core.performance_metrics_unlogged')) as table_size,
        pg_size_pretty(pg_relation_size('idx_performance_metrics_name_time')) as index_size
    
    UNION ALL
    
    SELECT 
        'session_logs_unlogged'::TEXT as table_name,
        (SELECT COUNT(*) FROM core.session_logs_unlogged) as current_rows,
        pg_size_pretty(pg_total_relation_size('core.session_logs_unlogged')) as table_size,
        pg_size_pretty(pg_relation_size('idx_session_logs_timestamp')) as index_size
    
    UNION ALL
    
    SELECT 
        'api_logs_unlogged'::TEXT as table_name,
        (SELECT COUNT(*) FROM core.api_logs_unlogged) as current_rows,
        pg_size_pretty(pg_total_relation_size('core.api_logs_unlogged')) as table_size,
        pg_size_pretty(pg_relation_size('idx_api_logs_timestamp')) as index_size;
END;
$$ LANGUAGE plpgsql;

-- 10. Grant permissions
GRANT EXECUTE ON FUNCTION core.log_audit_event(TEXT, TEXT, JSONB, JSONB, UUID) TO postgres;
GRANT EXECUTE ON FUNCTION core.log_performance_metric(TEXT, NUMERIC, JSONB) TO postgres;
GRANT EXECUTE ON FUNCTION core.log_session_event(TEXT, TEXT, UUID, INET, TEXT, JSONB) TO postgres;
GRANT EXECUTE ON FUNCTION core.log_api_request(TEXT, TEXT, INTEGER, INTEGER, UUID, INET, TEXT, JSONB, JSONB) TO postgres;
GRANT EXECUTE ON FUNCTION core.maintain_unlogged_tables() TO postgres;
GRANT EXECUTE ON FUNCTION core.get_unlogged_table_stats() TO postgres;

-- 11. Add to extensions config
INSERT INTO config.extensions_config (extension_name, is_enabled, config_data) VALUES
('unlogged_tables', TRUE, '{"tables": ["audit_log", "performance_metrics", "session_logs", "api_logs"], "maintenance_interval": "1 hour"}')
ON CONFLICT (extension_name) DO UPDATE SET
    updated_at = NOW(),
    config_data = EXCLUDED.config_data;

-- 12. Log completion
INSERT INTO monitoring.performance_metrics (metric_name, metric_value, metric_unit, tags)
VALUES ('unlogged_tables_implementation_completed', 1, 'count', '{"migration": "step_69_unlogged_tables"}'); 