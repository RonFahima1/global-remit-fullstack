-- PostgreSQL Extensions and Optimizations Setup
-- This migration sets up all the required extensions for the Global Remit system

-- 1. PGVECTOR - Vector similarity search for AI/ML features
CREATE EXTENSION IF NOT EXISTS vector;

-- 2. PG_AI - AI/ML functions for PostgreSQL
CREATE EXTENSION IF NOT EXISTS pg_ai;

-- 3. TEST FACTOR - Testing and validation utilities
-- Note: This is a custom extension, we'll create functions instead
CREATE OR REPLACE FUNCTION test_factor_validate_email(email TEXT)
RETURNS BOOLEAN AS $$
BEGIN
    RETURN email ~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$';
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION test_factor_validate_phone(phone TEXT)
RETURNS BOOLEAN AS $$
BEGIN
    RETURN phone ~* '^\+?[1-9]\d{1,14}$';
END;
$$ LANGUAGE plpgsql;

-- 4. GRAPHQL - GraphQL support (using PostGraphile approach)
-- We'll set up the foundation for GraphQL queries
CREATE SCHEMA IF NOT EXISTS graphql;

-- 5. ELECTRIC SQL - Real-time sync capabilities
-- Create tables for real-time synchronization
CREATE TABLE IF NOT EXISTS core.realtime_sync_log (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    table_name TEXT NOT NULL,
    operation TEXT NOT NULL CHECK (operation IN ('INSERT', 'UPDATE', 'DELETE')),
    record_id UUID NOT NULL,
    old_data JSONB,
    new_data JSONB,
    sync_timestamp TIMESTAMPTZ DEFAULT NOW(),
    synced BOOLEAN DEFAULT FALSE,
    retry_count INTEGER DEFAULT 0
);

CREATE INDEX idx_realtime_sync_log_table_operation ON core.realtime_sync_log(table_name, operation);
CREATE INDEX idx_realtime_sync_log_synced ON core.realtime_sync_log(synced) WHERE NOT synced;

-- 6. PG_MOONCAKE - Advanced caching and performance
-- Create a custom caching system inspired by mooncake
CREATE SCHEMA IF NOT EXISTS cache;

CREATE TABLE IF NOT EXISTS cache.query_cache (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    cache_key TEXT UNIQUE NOT NULL,
    cache_value JSONB NOT NULL,
    ttl TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    accessed_at TIMESTAMPTZ DEFAULT NOW(),
    access_count INTEGER DEFAULT 0
);

CREATE INDEX idx_query_cache_ttl ON cache.query_cache(ttl) WHERE ttl < NOW();
CREATE INDEX idx_query_cache_key ON cache.query_cache(cache_key);

-- Cache management functions
CREATE OR REPLACE FUNCTION cache.set_cache(
    p_key TEXT,
    p_value JSONB,
    p_ttl_seconds INTEGER DEFAULT 3600
)
RETURNS VOID AS $$
BEGIN
    INSERT INTO cache.query_cache (cache_key, cache_value, ttl)
    VALUES (p_key, p_value, NOW() + (p_ttl_seconds || ' seconds')::INTERVAL)
    ON CONFLICT (cache_key) 
    DO UPDATE SET 
        cache_value = EXCLUDED.cache_value,
        ttl = EXCLUDED.ttl,
        accessed_at = NOW(),
        access_count = cache.query_cache.access_count + 1;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION cache.get_cache(p_key TEXT)
RETURNS JSONB AS $$
DECLARE
    result JSONB;
BEGIN
    SELECT cache_value INTO result
    FROM cache.query_cache
    WHERE cache_key = p_key AND ttl > NOW();
    
    IF FOUND THEN
        UPDATE cache.query_cache 
        SET accessed_at = NOW(), access_count = access_count + 1
        WHERE cache_key = p_key;
    END IF;
    
    RETURN result;
END;
$$ LANGUAGE plpgsql;

-- 7. PG_CRYPTO - Enhanced cryptography functions
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- Enhanced crypto functions
CREATE OR REPLACE FUNCTION crypto.encrypt_sensitive_data(
    data TEXT,
    secret_key TEXT DEFAULT current_setting('app.encryption_key', true)
)
RETURNS BYTEA AS $$
BEGIN
    IF secret_key IS NULL THEN
        RAISE EXCEPTION 'Encryption key not configured';
    END IF;
    RETURN pgp_sym_encrypt(data, secret_key, 'compress-algo=1, cipher-algo=aes256');
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION crypto.decrypt_sensitive_data(
    encrypted_data BYTEA,
    secret_key TEXT DEFAULT current_setting('app.encryption_key', true)
)
RETURNS TEXT AS $$
BEGIN
    IF secret_key IS NULL THEN
        RAISE EXCEPTION 'Encryption key not configured';
    END IF;
    RETURN pgp_sym_decrypt(encrypted_data, secret_key);
END;
$$ LANGUAGE plpgsql;

-- 8. POSTGREST - REST API layer setup
-- Create views and functions for REST API access
CREATE SCHEMA IF NOT EXISTS rest_api;

-- Create REST API views for common operations
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

-- Grant permissions for REST API access
GRANT SELECT ON rest_api.transactions_summary TO postgres;

-- 9. Performance optimizations
-- Create indexes for better query performance
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_transactions_client_status 
ON core.transactions(client_id, status);

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_transactions_created_at 
ON core.transactions(created_at DESC);

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_accounts_client_id 
ON core.accounts(client_id);

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_clients_email 
ON core.clients(email);

-- 10. Vector search setup for AI features
-- Create vector columns for AI-powered search
ALTER TABLE core.clients ADD COLUMN IF NOT EXISTS embedding vector(1536);
ALTER TABLE core.transactions ADD COLUMN IF NOT EXISTS description_embedding vector(1536);

-- Create vector indexes
CREATE INDEX IF NOT EXISTS idx_clients_embedding ON core.clients USING ivfflat (embedding vector_cosine_ops) WITH (lists = 100);
CREATE INDEX IF NOT EXISTS idx_transactions_description_embedding ON core.transactions USING ivfflat (description_embedding vector_cosine_ops) WITH (lists = 100);

-- Vector similarity search function
CREATE OR REPLACE FUNCTION ai.similar_clients(
    query_embedding vector(1536),
    match_threshold float DEFAULT 0.8,
    match_count int DEFAULT 10
)
RETURNS TABLE (
    id UUID,
    first_name TEXT,
    last_name TEXT,
    email TEXT,
    similarity float
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        c.id,
        c.first_name,
        c.last_name,
        c.email,
        1 - (c.embedding <=> query_embedding) AS similarity
    FROM core.clients c
    WHERE c.embedding IS NOT NULL
    AND 1 - (c.embedding <=> query_embedding) > match_threshold
    ORDER BY c.embedding <=> query_embedding
    LIMIT match_count;
END;
$$;

-- 11. Monitoring and analytics setup
CREATE SCHEMA IF NOT EXISTS monitoring;

CREATE TABLE IF NOT EXISTS monitoring.performance_metrics (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    metric_name TEXT NOT NULL,
    metric_value NUMERIC NOT NULL,
    metric_unit TEXT,
    tags JSONB DEFAULT '{}',
    recorded_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_performance_metrics_name_time ON monitoring.performance_metrics(metric_name, recorded_at);

-- Performance monitoring function
CREATE OR REPLACE FUNCTION monitoring.record_metric(
    p_name TEXT,
    p_value NUMERIC,
    p_unit TEXT DEFAULT NULL,
    p_tags JSONB DEFAULT '{}'
)
RETURNS VOID AS $$
BEGIN
    INSERT INTO monitoring.performance_metrics (metric_name, metric_value, metric_unit, tags)
    VALUES (p_name, p_value, p_unit, p_tags);
END;
$$ LANGUAGE plpgsql;

-- 12. Automated maintenance functions
CREATE OR REPLACE FUNCTION maintenance.cleanup_expired_cache()
RETURNS INTEGER AS $$
DECLARE
    deleted_count INTEGER;
BEGIN
    DELETE FROM cache.query_cache WHERE ttl < NOW();
    GET DIAGNOSTICS deleted_count = ROW_COUNT;
    RETURN deleted_count;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION maintenance.cleanup_sync_log()
RETURNS INTEGER AS $$
DECLARE
    deleted_count INTEGER;
BEGIN
    DELETE FROM core.realtime_sync_log 
    WHERE synced = TRUE AND sync_timestamp < NOW() - INTERVAL '30 days';
    GET DIAGNOSTICS deleted_count = ROW_COUNT;
    RETURN deleted_count;
END;
$$ LANGUAGE plpgsql;

-- 13. Create a scheduled job for maintenance (if pg_cron is available)
-- Note: This requires pg_cron extension to be installed
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_cron') THEN
        -- Schedule cache cleanup every hour
        PERFORM cron.schedule('cleanup-cache', '0 * * * *', 'SELECT maintenance.cleanup_expired_cache();');
        
        -- Schedule sync log cleanup daily at 2 AM
        PERFORM cron.schedule('cleanup-sync-log', '0 2 * * *', 'SELECT maintenance.cleanup_sync_log();');
    END IF;
END $$;

-- 14. Grant necessary permissions
GRANT USAGE ON SCHEMA cache TO postgres;
GRANT USAGE ON SCHEMA monitoring TO postgres;
GRANT USAGE ON SCHEMA rest_api TO postgres;
GRANT USAGE ON SCHEMA ai TO postgres;
GRANT USAGE ON SCHEMA maintenance TO postgres;

GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA cache TO postgres;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA monitoring TO postgres;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA rest_api TO postgres;

-- 15. Create configuration table for extensions
CREATE TABLE IF NOT EXISTS config.extensions_config (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    extension_name TEXT UNIQUE NOT NULL,
    is_enabled BOOLEAN DEFAULT TRUE,
    config_data JSONB DEFAULT '{}',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

INSERT INTO config.extensions_config (extension_name, is_enabled, config_data) VALUES
('pgvector', TRUE, '{"dimension": 1536, "index_type": "ivfflat"}'),
('pg_ai', TRUE, '{"model_cache_size": "100MB"}'),
('pgcrypto', TRUE, '{"encryption_algorithm": "aes256"}'),
('cache_system', TRUE, '{"default_ttl": 3600, "max_cache_size": "1GB"}'),
('realtime_sync', TRUE, '{"batch_size": 100, "sync_interval": 30}'),
('monitoring', TRUE, '{"metrics_retention_days": 90}'),
('vector_search', TRUE, '{"similarity_threshold": 0.8, "max_results": 10}')
ON CONFLICT (extension_name) DO UPDATE SET
    updated_at = NOW(),
    config_data = EXCLUDED.config_data;

-- Log the completion
INSERT INTO monitoring.performance_metrics (metric_name, metric_value, metric_unit, tags)
VALUES ('extensions_setup_completed', 1, 'count', '{"migration": "step_45_postgres_extensions_setup"}'); 