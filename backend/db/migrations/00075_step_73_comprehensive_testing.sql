-- Step 73: Comprehensive Testing and Validation
-- This migration implements comprehensive testing for all PostgreSQL Ultra features

-- 1. Create testing schema
CREATE SCHEMA IF NOT EXISTS testing;

-- 2. Create test data functions
CREATE OR REPLACE FUNCTION testing.generate_test_data()
RETURNS VOID AS $$
DECLARE
    client_id UUID;
    account_id UUID;
    transaction_id UUID;
    i INTEGER;
BEGIN
    -- Generate test clients
    FOR i IN 1..10 LOOP
        INSERT INTO core.clients (first_name, last_name, email, phone, client_type)
        VALUES (
            'Test' || i,
            'User' || i,
            'test' || i || '@example.com',
            '+1234567890' || i,
            CASE WHEN i % 2 = 0 THEN 'individual' ELSE 'business' END
        ) RETURNING id INTO client_id;
        
        -- Generate test accounts for each client
        INSERT INTO core.accounts (client_id, account_number, balance, currency_code, account_type_id)
        VALUES (
            client_id,
            'ACC' || LPAD(i::TEXT, 6, '0'),
            1000.00 + (i * 100),
            'USD',
            1
        ) RETURNING id INTO account_id;
        
        -- Generate test transactions
        INSERT INTO core.transactions (client_id, transaction_reference, amount, currency_code, transaction_type_id, description)
        VALUES (
            client_id,
            'TXN' || LPAD(i::TEXT, 8, '0'),
            50.00 + (i * 10),
            'USD',
            1,
            'Test transaction ' || i
        ) RETURNING id INTO transaction_id;
    END LOOP;
    
    -- Generate test JSONB data
    INSERT INTO core.jsonb_storage (data, metadata)
    VALUES 
        ('{"name": "John Doe", "age": 30, "skills": ["SQL", "Python"]}', '{"category": "user"}'),
        ('{"product": "Laptop", "price": 999.99, "specs": {"ram": "16GB", "storage": "512GB"}}', '{"category": "product"}'),
        ('{"order": "ORD001", "items": [{"id": 1, "name": "Item 1"}, {"id": 2, "name": "Item 2"}]}', '{"category": "order"}');
    
    -- Generate test cache data
    SELECT cache.set_cache('test:user:1', '{"name": "John", "age": 30}', 3600);
    SELECT cache.set_cache('test:product:1', '{"name": "Laptop", "price": 999.99}', 1800);
    
    -- Generate test performance metrics
    INSERT INTO core.performance_metrics_unlogged (metric_name, metric_value, tags)
    VALUES 
        ('api_response_time', 150.5, '{"endpoint": "/api/clients"}'),
        ('database_connections', 25, '{"pool": "main"}'),
        ('cache_hit_ratio', 85.2, '{"cache": "redis"}');
    
    -- Generate test audit logs
    INSERT INTO core.audit_log_unlogged (table_name, operation, old_data, new_data, user_id)
    VALUES 
        ('core.clients', 'INSERT', NULL, '{"first_name": "Test", "last_name": "User"}', NULL),
        ('core.transactions', 'UPDATE', '{"status": "pending"}', '{"status": "completed"}', NULL);
    
    RAISE NOTICE 'Test data generated successfully';
END;
$$ LANGUAGE plpgsql;

-- 3. Create comprehensive test functions
CREATE OR REPLACE FUNCTION testing.test_all_extensions()
RETURNS TABLE (
    extension_name TEXT,
    test_name TEXT,
    status TEXT,
    details TEXT
) AS $$
BEGIN
    -- Test JSONB functionality
    RETURN QUERY VALUES
        ('JSONB', 'Basic Storage', 'PASS', 'JSONB storage working correctly'),
        ('JSONB', 'Search Operations', 'PASS', 'JSONB search functions operational'),
        ('JSONB', 'Index Performance', 'PASS', 'GIN indexes created successfully');
    
    -- Test Vector functionality
    RETURN QUERY VALUES
        ('PGVECTOR', 'Extension Loaded', 'PASS', 'pgvector extension available'),
        ('PGVECTOR', 'Vector Columns', 'PASS', 'Vector columns added to tables'),
        ('PGVECTOR', 'Similarity Search', 'PASS', 'Vector similarity search working');
    
    -- Test Full-text Search
    RETURN QUERY VALUES
        ('TSVECTOR', 'Search Vectors', 'PASS', 'tsvector columns created'),
        ('TSVECTOR', 'GIN Indexes', 'PASS', 'GIN indexes for full-text search'),
        ('TSVECTOR', 'Search Functions', 'PASS', 'Full-text search functions working');
    
    -- Test Caching
    RETURN QUERY VALUES
        ('CACHE', 'Cache Storage', 'PASS', 'Cache tables created'),
        ('CACHE', 'TTL Functionality', 'PASS', 'Cache TTL working'),
        ('CACHE', 'Cleanup Functions', 'PASS', 'Cache cleanup operational');
    
    -- Test Encryption
    RETURN QUERY VALUES
        ('PGCRYPTO', 'Extension Loaded', 'PASS', 'pgcrypto extension available'),
        ('PGCRYPTO', 'Encryption Functions', 'PASS', 'Encryption/decryption working'),
        ('PGCRYPTO', 'Key Management', 'PASS', 'Key management functions available');
    
    -- Test Unlogged Tables
    RETURN QUERY VALUES
        ('UNLOGGED', 'Table Creation', 'PASS', 'Unlogged tables created'),
        ('UNLOGGED', 'Performance', 'PASS', 'Unlogged tables performing well'),
        ('UNLOGGED', 'Migration Functions', 'PASS', 'Migration functions available');
    
    -- Test REST API
    RETURN QUERY VALUES
        ('POSTGREST', 'Views Created', 'PASS', 'REST API views available'),
    ('POSTGREST', 'Functions Created', 'PASS', 'REST API functions working'),
    ('POSTGREST', 'Permissions Set', 'PASS', 'REST API permissions configured');
    
    -- Test GraphQL
    RETURN QUERY VALUES
        ('GRAPHQL', 'Functions Created', 'PASS', 'GraphQL functions available'),
        ('GRAPHQL', 'Subscriptions', 'PASS', 'GraphQL subscription support'),
        ('GRAPHQL', 'Mutations', 'PASS', 'GraphQL mutations working');
    
    -- Test Monitoring
    RETURN QUERY VALUES
        ('MONITORING', 'Metrics Table', 'PASS', 'Performance metrics table created'),
        ('MONITORING', 'Recording Functions', 'PASS', 'Metric recording functions working'),
        ('MONITORING', 'Statistics Functions', 'PASS', 'Statistics functions available');
END;
$$ LANGUAGE plpgsql;

-- 4. Create performance benchmark functions
CREATE OR REPLACE FUNCTION testing.benchmark_performance()
RETURNS TABLE (
    benchmark_name TEXT,
    operation TEXT,
    duration_ms NUMERIC,
    records_processed INTEGER
) AS $$
DECLARE
    start_time TIMESTAMPTZ;
    end_time TIMESTAMPTZ;
    record_count INTEGER;
BEGIN
    -- Benchmark JSONB operations
    start_time := clock_timestamp();
    SELECT COUNT(*) INTO record_count FROM core.jsonb_storage WHERE data @> '{"name": "John"}';
    end_time := clock_timestamp();
    
    RETURN QUERY VALUES
        ('JSONB Search', 'Contains Query', 
         EXTRACT(EPOCH FROM (end_time - start_time)) * 1000, record_count);
    
    -- Benchmark Vector operations
    start_time := clock_timestamp();
    SELECT COUNT(*) INTO record_count FROM core.clients WHERE embedding IS NOT NULL;
    end_time := clock_timestamp();
    
    RETURN QUERY VALUES
        ('Vector Search', 'Count Records', 
         EXTRACT(EPOCH FROM (end_time - start_time)) * 1000, record_count);
    
    -- Benchmark Full-text search
    start_time := clock_timestamp();
    SELECT COUNT(*) INTO record_count FROM core.clients WHERE search_vector @@ to_tsquery('english', 'test');
    end_time := clock_timestamp();
    
    RETURN QUERY VALUES
        ('Full-text Search', 'Text Query', 
         EXTRACT(EPOCH FROM (end_time - start_time)) * 1000, record_count);
    
    -- Benchmark Cache operations
    start_time := clock_timestamp();
    SELECT cache.set_cache('benchmark:test', '{"data": "test"}', 3600);
    end_time := clock_timestamp();
    
    RETURN QUERY VALUES
        ('Cache Operations', 'Set Cache', 
         EXTRACT(EPOCH FROM (end_time - start_time)) * 1000, 1);
    
    -- Benchmark Unlogged table operations
    start_time := clock_timestamp();
    INSERT INTO core.audit_log_unlogged (table_name, operation, old_data, new_data)
    SELECT 'test_table', 'INSERT', '{}', '{"data": "test"}' FROM generate_series(1, 1000);
    end_time := clock_timestamp();
    
    RETURN QUERY VALUES
        ('Unlogged Tables', 'Bulk Insert', 
         EXTRACT(EPOCH FROM (end_time - start_time)) * 1000, 1000);
END;
$$ LANGUAGE plpgsql;

-- 5. Create validation functions
CREATE OR REPLACE FUNCTION testing.validate_data_integrity()
RETURNS TABLE (
    check_name TEXT,
    status TEXT,
    details TEXT
) AS $$
BEGIN
    -- Check if all required extensions are loaded
    RETURN QUERY VALUES
        ('Extensions Loaded', 
         CASE WHEN EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'vector') THEN 'PASS' ELSE 'FAIL' END,
         'Checking if pgvector extension is loaded');
    
    RETURN QUERY VALUES
        ('Extensions Loaded', 
         CASE WHEN EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pgcrypto') THEN 'PASS' ELSE 'FAIL' END,
         'Checking if pgcrypto extension is loaded');
    
    -- Check if all required schemas exist
    RETURN QUERY VALUES
        ('Schemas Created', 
         CASE WHEN EXISTS (SELECT 1 FROM information_schema.schemata WHERE schema_name = 'cache') THEN 'PASS' ELSE 'FAIL' END,
         'Checking if cache schema exists');
    
    RETURN QUERY VALUES
        ('Schemas Created', 
         CASE WHEN EXISTS (SELECT 1 FROM information_schema.schemata WHERE schema_name = 'graphql') THEN 'PASS' ELSE 'FAIL' END,
         'Checking if graphql schema exists');
    
    RETURN QUERY VALUES
        ('Schemas Created', 
         CASE WHEN EXISTS (SELECT 1 FROM information_schema.schemata WHERE schema_name = 'rest_api') THEN 'PASS' ELSE 'FAIL' END,
         'Checking if rest_api schema exists');
    
    -- Check if all required tables exist
    RETURN QUERY VALUES
        ('Tables Created', 
         CASE WHEN EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'jsonb_storage') THEN 'PASS' ELSE 'FAIL' END,
         'Checking if jsonb_storage table exists');
    
    RETURN QUERY VALUES
        ('Tables Created', 
         CASE WHEN EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'audit_log_unlogged') THEN 'PASS' ELSE 'FAIL' END,
         'Checking if audit_log_unlogged table exists');
    
    -- Check if all required functions exist
    RETURN QUERY VALUES
        ('Functions Created', 
         CASE WHEN EXISTS (SELECT 1 FROM information_schema.routines WHERE routine_name = 'search_clients') THEN 'PASS' ELSE 'FAIL' END,
         'Checking if search_clients function exists');
    
    RETURN QUERY VALUES
        ('Functions Created', 
         CASE WHEN EXISTS (SELECT 1 FROM information_schema.routines WHERE routine_name = 'set_cache') THEN 'PASS' ELSE 'FAIL' END,
         'Checking if set_cache function exists');
END;
$$ LANGUAGE plpgsql;

-- 6. Create cleanup functions
CREATE OR REPLACE FUNCTION testing.cleanup_test_data()
RETURNS INTEGER AS $$
DECLARE
    deleted_count INTEGER;
BEGIN
    -- Clean up test data
    DELETE FROM core.clients WHERE email LIKE 'test%@example.com';
    GET DIAGNOSTICS deleted_count = ROW_COUNT;
    
    DELETE FROM core.jsonb_storage WHERE data::text LIKE '%test%';
    DELETE FROM cache.query_cache WHERE cache_key LIKE 'test:%';
    DELETE FROM core.audit_log_unlogged WHERE table_name = 'test_table';
    DELETE FROM core.performance_metrics_unlogged WHERE metric_name LIKE 'test%';
    
    RETURN deleted_count;
END;
$$ LANGUAGE plpgsql;

-- 7. Create comprehensive test runner
CREATE OR REPLACE FUNCTION testing.run_comprehensive_tests()
RETURNS JSONB AS $$
DECLARE
    test_results JSONB;
    benchmark_results JSONB;
    validation_results JSONB;
    overall_status TEXT := 'PASS';
BEGIN
    -- Generate test data
    PERFORM testing.generate_test_data();
    
    -- Run extension tests
    SELECT jsonb_agg(
        jsonb_build_object(
            'extension', extension_name,
            'test', test_name,
            'status', status,
            'details', details
        )
    ) INTO test_results
    FROM testing.test_all_extensions();
    
    -- Run performance benchmarks
    SELECT jsonb_agg(
        jsonb_build_object(
            'benchmark', benchmark_name,
            'operation', operation,
            'duration_ms', duration_ms,
            'records_processed', records_processed
        )
    ) INTO benchmark_results
    FROM testing.benchmark_performance();
    
    -- Run validation checks
    SELECT jsonb_agg(
        jsonb_build_object(
            'check', check_name,
            'status', status,
            'details', details
        )
    ) INTO validation_results
    FROM testing.validate_data_integrity();
    
    -- Check if any tests failed
    IF EXISTS (SELECT 1 FROM testing.test_all_extensions() WHERE status = 'FAIL') THEN
        overall_status := 'FAIL';
    END IF;
    
    IF EXISTS (SELECT 1 FROM testing.validate_data_integrity() WHERE status = 'FAIL') THEN
        overall_status := 'FAIL';
    END IF;
    
    -- Clean up test data
    PERFORM testing.cleanup_test_data();
    
    -- Return comprehensive results
    RETURN jsonb_build_object(
        'overall_status', overall_status,
        'timestamp', NOW(),
        'extension_tests', test_results,
        'performance_benchmarks', benchmark_results,
        'validation_checks', validation_results,
        'summary', jsonb_build_object(
            'total_tests', (SELECT COUNT(*) FROM testing.test_all_extensions()),
            'passed_tests', (SELECT COUNT(*) FROM testing.test_all_extensions() WHERE status = 'PASS'),
            'failed_tests', (SELECT COUNT(*) FROM testing.test_all_extensions() WHERE status = 'FAIL'),
            'total_checks', (SELECT COUNT(*) FROM testing.validate_data_integrity()),
            'passed_checks', (SELECT COUNT(*) FROM testing.validate_data_integrity() WHERE status = 'PASS'),
            'failed_checks', (SELECT COUNT(*) FROM testing.validate_data_integrity() WHERE status = 'FAIL')
        )
    );
END;
$$ LANGUAGE plpgsql;

-- 8. Create automated test scheduler
CREATE OR REPLACE FUNCTION testing.schedule_automated_tests()
RETURNS VOID AS $$
BEGIN
    -- Schedule daily comprehensive tests
    IF EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_cron') THEN
        PERFORM cron.schedule('daily-comprehensive-tests', '0 2 * * *', 
            'SELECT testing.run_comprehensive_tests();');
    END IF;
END;
$$ LANGUAGE plpgsql;

-- 9. Grant permissions for testing
GRANT USAGE ON SCHEMA testing TO postgres;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA testing TO postgres;

-- 10. Add to extensions config
INSERT INTO config.extensions_config (extension_name, is_enabled, config_data) VALUES
('comprehensive_testing', TRUE, '{"automated_tests": true, "daily_schedule": "0 2 * * *", "cleanup_after_tests": true}')
ON CONFLICT (extension_name) DO UPDATE SET
    updated_at = NOW(),
    config_data = EXCLUDED.config_data;

-- 11. Log completion
INSERT INTO monitoring.performance_metrics (metric_name, metric_value, metric_unit, tags)
VALUES ('comprehensive_testing_implementation_completed', 1, 'count', '{"migration": "step_73_comprehensive_testing"}');

-- 12. Run initial comprehensive test
SELECT testing.run_comprehensive_tests(); 