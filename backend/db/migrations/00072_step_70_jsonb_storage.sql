-- Step 70: JSONB Storage Implementation
-- This migration implements JSONB storage for flexible data structures

-- 1. Create JSONB storage table
CREATE TABLE IF NOT EXISTS core.jsonb_storage (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    data JSONB NOT NULL,
    metadata JSONB DEFAULT '{}',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 2. Create GIN indexes for JSONB
CREATE INDEX idx_jsonb_storage_data ON core.jsonb_storage USING GIN (data);
CREATE INDEX idx_jsonb_storage_metadata ON core.jsonb_storage USING GIN (metadata);
CREATE INDEX idx_jsonb_storage_created_at ON core.jsonb_storage(created_at);
CREATE INDEX idx_jsonb_storage_updated_at ON core.jsonb_storage(updated_at);

-- 3. Create JSONB utility functions
CREATE OR REPLACE FUNCTION core.jsonb_set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_jsonb_storage_updated_at
    BEFORE UPDATE ON core.jsonb_storage
    FOR EACH ROW EXECUTE FUNCTION core.jsonb_set_updated_at();

-- 4. Create JSONB storage functions
CREATE OR REPLACE FUNCTION core.store_jsonb_data(
    p_data JSONB,
    p_metadata JSONB DEFAULT '{}'
)
RETURNS UUID AS $$
DECLARE
    record_id UUID;
BEGIN
    INSERT INTO core.jsonb_storage (data, metadata)
    VALUES (p_data, p_metadata)
    RETURNING id INTO record_id;
    
    RETURN record_id;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION core.get_jsonb_data(p_id UUID)
RETURNS TABLE (
    id UUID,
    data JSONB,
    metadata JSONB,
    created_at TIMESTAMPTZ,
    updated_at TIMESTAMPTZ
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        js.id,
        js.data,
        js.metadata,
        js.created_at,
        js.updated_at
    FROM core.jsonb_storage js
    WHERE js.id = p_id;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION core.update_jsonb_data(
    p_id UUID,
    p_data JSONB,
    p_metadata JSONB DEFAULT NULL
)
RETURNS BOOLEAN AS $$
DECLARE
    rows_affected INTEGER;
BEGIN
    IF p_metadata IS NULL THEN
        UPDATE core.jsonb_storage 
        SET data = p_data
        WHERE id = p_id;
    ELSE
        UPDATE core.jsonb_storage 
        SET data = p_data, metadata = p_metadata
        WHERE id = p_id;
    END IF;
    
    GET DIAGNOSTICS rows_affected = ROW_COUNT;
    RETURN rows_affected > 0;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION core.delete_jsonb_data(p_id UUID)
RETURNS BOOLEAN AS $$
DECLARE
    rows_affected INTEGER;
BEGIN
    DELETE FROM core.jsonb_storage WHERE id = p_id;
    GET DIAGNOSTICS rows_affected = ROW_COUNT;
    RETURN rows_affected > 0;
END;
$$ LANGUAGE plpgsql;

-- 5. Create JSONB search functions
CREATE OR REPLACE FUNCTION core.search_jsonb_data(
    p_query JSONB,
    p_limit INTEGER DEFAULT 20
)
RETURNS TABLE (
    id UUID,
    data JSONB,
    metadata JSONB,
    created_at TIMESTAMPTZ,
    updated_at TIMESTAMPTZ,
    relevance FLOAT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        js.id,
        js.data,
        js.metadata,
        js.created_at,
        js.updated_at,
        jsondata_depth(js.data)::FLOAT as relevance
    FROM core.jsonb_storage js
    WHERE js.data @> p_query
    ORDER BY js.updated_at DESC
    LIMIT p_limit;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION core.search_jsonb_by_path(
    p_path TEXT,
    p_value TEXT,
    p_limit INTEGER DEFAULT 20
)
RETURNS TABLE (
    id UUID,
    data JSONB,
    metadata JSONB,
    created_at TIMESTAMPTZ,
    updated_at TIMESTAMPTZ
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        js.id,
        js.data,
        js.metadata,
        js.created_at,
        js.updated_at
    FROM core.jsonb_storage js
    WHERE js.data #>> string_to_array(p_path, '.') = p_value
    ORDER BY js.updated_at DESC
    LIMIT p_limit;
END;
$$ LANGUAGE plpgsql;

-- 6. Create JSONB aggregation functions
CREATE OR REPLACE FUNCTION core.aggregate_jsonb_data(
    p_aggregation_path TEXT,
    p_aggregation_type TEXT DEFAULT 'count'
)
RETURNS TABLE (
    value TEXT,
    count BIGINT
) AS $$
BEGIN
    RETURN QUERY
    EXECUTE format(
        'SELECT 
            data #>> string_to_array(%L, ''.'') as value,
            COUNT(*) as count
        FROM core.jsonb_storage 
        WHERE data #>> string_to_array(%L, ''.'') IS NOT NULL
        GROUP BY data #>> string_to_array(%L, ''.'')
        ORDER BY count DESC',
        p_aggregation_path, p_aggregation_path, p_aggregation_path
    );
END;
$$ LANGUAGE plpgsql;

-- 7. Create JSONB statistics functions
CREATE OR REPLACE FUNCTION core.get_jsonb_statistics()
RETURNS TABLE (
    total_records INTEGER,
    total_size TEXT,
    avg_data_depth NUMERIC,
    most_common_keys TEXT[]
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        (SELECT COUNT(*) FROM core.jsonb_storage) as total_records,
        pg_size_pretty(pg_total_relation_size('core.jsonb_storage')) as total_size,
        (SELECT AVG(jsondata_depth(data)) FROM core.jsonb_storage) as avg_data_depth,
        ARRAY(
            SELECT DISTINCT jsonb_object_keys(data)
            FROM core.jsonb_storage
            LIMIT 10
        ) as most_common_keys;
END;
$$ LANGUAGE plpgsql;

-- 8. Create JSONB cleanup function
CREATE OR REPLACE FUNCTION core.cleanup_old_jsonb_data(p_days_old INTEGER DEFAULT 30)
RETURNS INTEGER AS $$
DECLARE
    deleted_count INTEGER;
BEGIN
    DELETE FROM core.jsonb_storage 
    WHERE updated_at < NOW() - (p_days_old || ' days')::INTERVAL;
    
    GET DIAGNOSTICS deleted_count = ROW_COUNT;
    RETURN deleted_count;
END;
$$ LANGUAGE plpgsql;

-- 9. Create JSONB export/import functions
CREATE OR REPLACE FUNCTION core.export_jsonb_data(p_filter JSONB DEFAULT '{}')
RETURNS TABLE (
    id UUID,
    data JSONB,
    metadata JSONB,
    created_at TIMESTAMPTZ,
    updated_at TIMESTAMPTZ
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        js.id,
        js.data,
        js.metadata,
        js.created_at,
        js.updated_at
    FROM core.jsonb_storage js
    WHERE js.data @> p_filter
    ORDER BY js.updated_at DESC;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION core.import_jsonb_data(p_data JSONB)
RETURNS UUID AS $$
DECLARE
    record_id UUID;
    data_record RECORD;
BEGIN
    -- Expect p_data to be an array of objects with 'data' and 'metadata' fields
    FOR data_record IN SELECT * FROM jsonb_array_elements(p_data)
    LOOP
        INSERT INTO core.jsonb_storage (data, metadata)
        VALUES (
            data_record.value->'data',
            COALESCE(data_record.value->'metadata', '{}'::jsonb)
        )
        RETURNING id INTO record_id;
    END LOOP;
    
    RETURN record_id;
END;
$$ LANGUAGE plpgsql;

-- 10. Create specialized JSONB tables for common use cases
CREATE TABLE IF NOT EXISTS core.user_preferences (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID NOT NULL,
    preferences JSONB DEFAULT '{}',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS core.system_config (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    config_key TEXT UNIQUE NOT NULL,
    config_value JSONB NOT NULL,
    description TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS core.notification_templates (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    template_name TEXT UNIQUE NOT NULL,
    template_data JSONB NOT NULL,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 11. Create indexes for specialized tables
CREATE INDEX idx_user_preferences_user_id ON core.user_preferences(user_id);
CREATE INDEX idx_user_preferences_preferences ON core.user_preferences USING GIN (preferences);
CREATE INDEX idx_system_config_key ON core.system_config(config_key);
CREATE INDEX idx_system_config_value ON core.system_config USING GIN (config_value);
CREATE INDEX idx_notification_templates_name ON core.notification_templates(template_name);
CREATE INDEX idx_notification_templates_data ON core.notification_templates USING GIN (template_data);

-- 12. Grant permissions
GRANT EXECUTE ON FUNCTION core.store_jsonb_data(JSONB, JSONB) TO postgres;
GRANT EXECUTE ON FUNCTION core.get_jsonb_data(UUID) TO postgres;
GRANT EXECUTE ON FUNCTION core.update_jsonb_data(UUID, JSONB, JSONB) TO postgres;
GRANT EXECUTE ON FUNCTION core.delete_jsonb_data(UUID) TO postgres;
GRANT EXECUTE ON FUNCTION core.search_jsonb_data(JSONB, INTEGER) TO postgres;
GRANT EXECUTE ON FUNCTION core.search_jsonb_by_path(TEXT, TEXT, INTEGER) TO postgres;
GRANT EXECUTE ON FUNCTION core.aggregate_jsonb_data(TEXT, TEXT) TO postgres;
GRANT EXECUTE ON FUNCTION core.get_jsonb_statistics() TO postgres;
GRANT EXECUTE ON FUNCTION core.cleanup_old_jsonb_data(INTEGER) TO postgres;
GRANT EXECUTE ON FUNCTION core.export_jsonb_data(JSONB) TO postgres;
GRANT EXECUTE ON FUNCTION core.import_jsonb_data(JSONB) TO postgres;

-- 13. Add to extensions config
INSERT INTO config.extensions_config (extension_name, is_enabled, config_data) VALUES
('jsonb_storage', TRUE, '{"indexes": ["gin"], "cleanup_days": 30, "max_depth": 10}')
ON CONFLICT (extension_name) DO UPDATE SET
    updated_at = NOW(),
    config_data = EXCLUDED.config_data;

-- 14. Log completion
INSERT INTO monitoring.performance_metrics (metric_name, metric_value, metric_unit, tags)
VALUES ('jsonb_storage_implementation_completed', 1, 'count', '{"migration": "step_70_jsonb_storage"}'); 