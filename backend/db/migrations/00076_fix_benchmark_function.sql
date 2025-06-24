-- Fix benchmark function
-- This migration fixes the issue in the benchmark_performance function

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
    PERFORM cache.set_cache('benchmark:test', '{"data": "test"}', 3600);
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