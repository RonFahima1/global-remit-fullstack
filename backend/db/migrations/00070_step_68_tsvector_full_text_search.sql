-- Step 68: tsvector Full-Text Search Implementation
-- This migration implements full-text search capabilities using PostgreSQL's tsvector/tsquery

-- 1. Add tsvector columns to existing tables
ALTER TABLE core.clients ADD COLUMN IF NOT EXISTS search_vector tsvector;
ALTER TABLE core.transactions ADD COLUMN IF NOT EXISTS description_vector tsvector;

-- 2. Create function to update client search vectors
CREATE OR REPLACE FUNCTION core.update_client_search_vector()
RETURNS TRIGGER AS $$
BEGIN
    NEW.search_vector := 
        setweight(to_tsvector('english', COALESCE(NEW.first_name, '')), 'A') ||
        setweight(to_tsvector('english', COALESCE(NEW.last_name, '')), 'A') ||
        setweight(to_tsvector('english', COALESCE(NEW.email, '')), 'B') ||
        setweight(to_tsvector('english', COALESCE(NEW.phone, '')), 'C') ||
        setweight(to_tsvector('english', COALESCE(NEW.client_type, '')), 'D');
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 3. Create function to update transaction description vectors
CREATE OR REPLACE FUNCTION core.update_transaction_description_vector()
RETURNS TRIGGER AS $$
BEGIN
    NEW.description_vector := 
        setweight(to_tsvector('english', COALESCE(NEW.transaction_reference, '')), 'A') ||
        setweight(to_tsvector('english', COALESCE(NEW.description, '')), 'B') ||
        setweight(to_tsvector('english', COALESCE(NEW.currency_code, '')), 'C');
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 4. Create triggers for automatic search vector updates
CREATE TRIGGER trigger_clients_search_vector
    BEFORE INSERT OR UPDATE ON core.clients
    FOR EACH ROW EXECUTE FUNCTION core.update_client_search_vector();

CREATE TRIGGER trigger_transactions_description_vector
    BEFORE INSERT OR UPDATE ON core.transactions
    FOR EACH ROW EXECUTE FUNCTION core.update_transaction_description_vector();

-- 5. Create GIN indexes for full-text search
CREATE INDEX IF NOT EXISTS idx_clients_search_vector ON core.clients USING GIN (search_vector);
CREATE INDEX IF NOT EXISTS idx_transactions_description_vector ON core.transactions USING GIN (description_vector);

-- 6. Update existing data with search vectors
UPDATE core.clients SET search_vector = 
    setweight(to_tsvector('english', COALESCE(first_name, '')), 'A') ||
    setweight(to_tsvector('english', COALESCE(last_name, '')), 'A') ||
    setweight(to_tsvector('english', COALESCE(email, '')), 'B') ||
    setweight(to_tsvector('english', COALESCE(phone, '')), 'C') ||
    setweight(to_tsvector('english', COALESCE(client_type, '')), 'D')
WHERE search_vector IS NULL;

UPDATE core.transactions SET description_vector = 
    setweight(to_tsvector('english', COALESCE(transaction_reference, '')), 'A') ||
    setweight(to_tsvector('english', COALESCE(description, '')), 'B') ||
    setweight(to_tsvector('english', COALESCE(currency_code, '')), 'C')
WHERE description_vector IS NULL;

-- 7. Create full-text search functions
CREATE OR REPLACE FUNCTION core.search_clients(
    search_query TEXT,
    limit_count INTEGER DEFAULT 20
)
RETURNS TABLE (
    id UUID,
    first_name TEXT,
    last_name TEXT,
    email TEXT,
    phone TEXT,
    client_type TEXT,
    rank FLOAT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        c.id,
        c.first_name,
        c.last_name,
        c.email,
        c.phone,
        c.client_type,
        ts_rank(c.search_vector, query, 32) as rank
    FROM core.clients c, to_tsquery('english', search_query) query
    WHERE c.search_vector @@ query
    ORDER BY rank DESC
    LIMIT limit_count;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION core.search_transactions(
    search_query TEXT,
    limit_count INTEGER DEFAULT 20
)
RETURNS TABLE (
    id UUID,
    transaction_reference TEXT,
    amount NUMERIC,
    currency_code TEXT,
    description TEXT,
    status TEXT,
    created_at TIMESTAMPTZ,
    rank FLOAT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        t.id,
        t.transaction_reference,
        t.amount,
        t.currency_code,
        t.description,
        t.status,
        t.created_at,
        ts_rank(t.description_vector, query, 32) as rank
    FROM core.transactions t, to_tsquery('english', search_query) query
    WHERE t.description_vector @@ query
    ORDER BY rank DESC
    LIMIT limit_count;
END;
$$ LANGUAGE plpgsql;

-- 8. Create combined search function
CREATE OR REPLACE FUNCTION core.search_all(
    search_query TEXT,
    limit_count INTEGER DEFAULT 10
)
RETURNS TABLE (
    entity_type TEXT,
    id UUID,
    title TEXT,
    description TEXT,
    rank FLOAT
) AS $$
BEGIN
    RETURN QUERY
    -- Search clients
    SELECT 
        'client'::TEXT as entity_type,
        c.id,
        (c.first_name || ' ' || c.last_name)::TEXT as title,
        c.email::TEXT as description,
        ts_rank(c.search_vector, query, 32) as rank
    FROM core.clients c, to_tsquery('english', search_query) query
    WHERE c.search_vector @@ query
    
    UNION ALL
    
    -- Search transactions
    SELECT 
        'transaction'::TEXT as entity_type,
        t.id,
        t.transaction_reference::TEXT as title,
        COALESCE(t.description, 'No description')::TEXT as description,
        ts_rank(t.description_vector, query, 32) as rank
    FROM core.transactions t, to_tsquery('english', search_query) query
    WHERE t.description_vector @@ query
    
    ORDER BY rank DESC
    LIMIT limit_count;
END;
$$ LANGUAGE plpgsql;

-- 9. Create search statistics function
CREATE OR REPLACE FUNCTION core.get_search_statistics()
RETURNS TABLE (
    table_name TEXT,
    total_rows INTEGER,
    indexed_rows INTEGER,
    index_size TEXT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        'clients'::TEXT as table_name,
        (SELECT COUNT(*) FROM core.clients) as total_rows,
        (SELECT COUNT(*) FROM core.clients WHERE search_vector IS NOT NULL) as indexed_rows,
        pg_size_pretty(pg_relation_size('idx_clients_search_vector')) as index_size
    
    UNION ALL
    
    SELECT 
        'transactions'::TEXT as table_name,
        (SELECT COUNT(*) FROM core.transactions) as total_rows,
        (SELECT COUNT(*) FROM core.transactions WHERE description_vector IS NOT NULL) as indexed_rows,
        pg_size_pretty(pg_relation_size('idx_transactions_description_vector')) as index_size;
END;
$$ LANGUAGE plpgsql;

-- 10. Grant permissions
GRANT EXECUTE ON FUNCTION core.search_clients(TEXT, INTEGER) TO postgres;
GRANT EXECUTE ON FUNCTION core.search_transactions(TEXT, INTEGER) TO postgres;
GRANT EXECUTE ON FUNCTION core.search_all(TEXT, INTEGER) TO postgres;
GRANT EXECUTE ON FUNCTION core.get_search_statistics() TO postgres;

-- 11. Add to extensions config
INSERT INTO config.extensions_config (extension_name, is_enabled, config_data) VALUES
('tsvector_search', TRUE, '{"language": "english", "weights": {"A": "first_name,last_name", "B": "email", "C": "phone", "D": "client_type"}}')
ON CONFLICT (extension_name) DO UPDATE SET
    updated_at = NOW(),
    config_data = EXCLUDED.config_data;

-- 12. Log completion
INSERT INTO monitoring.performance_metrics (metric_name, metric_value, metric_unit, tags)
VALUES ('tsvector_search_implementation_completed', 1, 'count', '{"migration": "step_68_tsvector_full_text_search"}'); 