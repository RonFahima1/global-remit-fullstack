# Database Indexing Strategy

## Introduction
This document outlines the indexing strategy for the Global Remit database to ensure optimal query performance while maintaining efficient write operations. The strategy is designed based on the access patterns, query requirements, and data distribution of the application.

## Indexing Principles

### General Guidelines
1. **Selective Indexing**
   - Index columns with high cardinality
   - Avoid indexing frequently updated columns
   - Consider the write vs. read ratio

2. **Index Types**
   - **B-tree**: Default and most common (equality and range queries)
   - **Hash**: Equality-only lookups (not used in this application)
   - **GIN**: For indexing array or JSONB data
   - **BRIN**: For very large tables with naturally ordered data

3. **Index Maintenance**
   - Regular `VACUUM ANALYZE` operations
   - Monitor index usage and bloat
   - Rebuild or drop unused indexes

## Schema-Specific Indexing

### Auth Schema

#### users
```sql
-- Existing indexes
CREATE INDEX idx_users_email_lower ON auth.users(LOWER(email));
CREATE INDEX idx_users_status ON auth.users(status);
CREATE INDEX idx_users_role ON auth.users(role_id);

-- Recommended additional indexes
CREATE INDEX idx_users_created_at ON auth.users(created_at) WHERE deleted_at IS NULL;
CREATE INDEX idx_users_last_login ON auth.users(last_login_at) WHERE last_login_at IS NOT NULL;
```

#### sessions
```sql
-- Existing indexes
CREATE UNIQUE INDEX idx_sessions_token ON auth.sessions(token_hash);

-- Recommended additional indexes
CREATE INDEX idx_sessions_expires ON auth.sessions(expires_at) WHERE expires_at > NOW();
CREATE INDEX idx_sessions_user ON auth.sessions(user_id) WHERE expires_at > NOW();
```

### Core Schema

#### clients
```sql
-- Existing indexes
CREATE INDEX idx_clients_client_number ON core.clients(client_number);
CREATE INDEX idx_clients_email ON core.clients(email);
CREATE INDEX idx_clients_phone ON core.clients(phone);

-- Recommended additional indexes
CREATE INDEX idx_clients_status ON core.clients(status) WHERE status != 'active';
CREATE INDEX idx_clients_created_at ON core.clients(created_at);
```

#### accounts
```sql
-- Existing indexes
CREATE INDEX idx_accounts_client_id ON core.accounts(client_id);
CREATE INDEX idx_accounts_account_number ON core.accounts(account_number);

-- Recommended additional indexes
CREATE INDEX idx_accounts_status ON core.accounts(status) WHERE status != 'active';
CREATE INDEX idx_accounts_balance ON core.accounts(balance) WHERE balance > 0;
```

#### transactions
```sql
-- Existing indexes
CREATE INDEX idx_transactions_account_id ON core.transactions(account_id);
CREATE INDEX idx_transactions_reference ON core.transactions(reference_number);
CREATE INDEX idx_transactions_date ON core.transactions(transaction_date);

-- Recommended additional indexes
CREATE INDEX idx_transactions_type_status ON core.transactions(transaction_type, status);
CREATE INDEX idx_transactions_amount ON core.transactions(amount) WHERE amount > 10000;
```

### Compliance Schema

#### audit_logs
```sql
-- Existing indexes
CREATE INDEX idx_audit_logs_event_time ON compliance.audit_logs(event_time);
CREATE INDEX idx_audit_logs_event_type ON compliance.audit_logs(event_type);
CREATE INDEX idx_audit_logs_table ON compliance.audit_logs(table_name);
CREATE INDEX idx_audit_logs_user ON compliance.audit_logs(user_id);

-- Recommended additional indexes (for partitioning)
CREATE INDEX idx_audit_logs_composite ON compliance.audit_logs(event_type, event_time) 
    WHERE event_time > NOW() - INTERVAL '1 year';
```

#### kyc_verifications
```sql
-- Existing indexes
CREATE INDEX idx_kyc_client ON compliance.kyc_verifications(client_id);
CREATE INDEX idx_kyc_status ON compliance.kyc_verifications(verification_status);

-- Recommended additional indexes
CREATE INDEX idx_kyc_expiration ON compliance.kyc_verifications(expiration_date) 
    WHERE expiration_date IS NOT NULL;
```

### Config Schema

#### exchange_rates
```sql
-- Existing indexes
CREATE INDEX idx_exchange_rates_from ON config.exchange_rates(from_currency);
CREATE INDEX idx_exchange_rates_to ON config.exchange_rates(to_currency);
CREATE INDEX idx_exchange_rates_date ON config.exchange_rates(effective_date);

-- Recommended additional indexes
CREATE UNIQUE INDEX idx_exchange_rates_unique ON config.exchange_rates(
    from_currency, to_currency, effective_date
) WHERE is_active = true;
```

## Composite Indexes

### Best Practices
1. **Column Order Matters**
   - Most selective columns first
   - Equality conditions before range conditions
   - Consider the most common query patterns

2. **Examples**
   ```sql
   -- For queries filtering on status and date range
   CREATE INDEX idx_transactions_status_date ON core.transactions(status, transaction_date);
   
   -- For queries joining on multiple columns
   CREATE INDEX idx_client_accounts ON core.accounts(client_id, account_type, status);
   ```

## Partial Indexes

### When to Use
- When you frequently query a subset of rows
- To exclude NULL values
- For specific status values

### Examples
```sql
-- Only index active sessions
CREATE INDEX idx_sessions_active ON auth.sessions(last_activity) 
    WHERE status = 'active';

-- Index only pending transactions
CREATE INDEX idx_transactions_pending ON core.transactions(created_at) 
    WHERE status = 'pending';
```

## Index-Only Scans

### Optimization Techniques
1. **INCLUDE Columns**
   ```sql
   -- Include additional columns to avoid table lookups
   CREATE INDEX idx_transactions_covering ON core.transactions(
       account_id, 
       transaction_date
   ) INCLUDE (amount, reference_number);
   ```

2. **Materialized Views**
   - For complex, frequently accessed aggregations
   - Refreshed on a schedule or on-demand

## Monitoring and Maintenance

### Index Usage Statistics
```sql
-- Find unused indexes
SELECT 
    schemaname,
    relname,
    indexrelname,
    idx_scan,
    idx_tup_read,
    idx_tup_fetch
FROM pg_stat_user_indexes 
JOIN pg_statio_user_indexes USING (indexrelid, relid)
WHERE idx_scan = 0;
```

### Index Bloat Analysis
```sql
-- Check for index bloat
SELECT
    nspname,
    relname,
    indexrelname,
    pg_size_pretty(pg_relation_size(indexrelid)) as index_size,
    idx_scan,
    idx_tup_read,
    idx_tup_fetch
FROM pg_stat_user_indexes 
JOIN pg_statio_user_indexes USING (indexrelid, relid)
JOIN pg_index USING (indexrelid)
JOIN pg_class ON pg_index.indexrelid = pg_class.oid
JOIN pg_namespace ON pg_namespace.oid = pg_class.relnamespace
WHERE pg_namespace.nspname NOT IN ('pg_catalog', 'information_schema')
ORDER BY pg_relation_size(indexrelid) DESC;
```

### Maintenance Tasks
```sql
-- Update statistics
ANALYZE [table_name];

-- Rebuild an index
REINDEX INDEX index_name;
REINDEX TABLE table_name;

-- Concurrent index creation (avoids locks)
CREATE INDEX CONCURRENTLY index_name ON table_name(column_name);
```

## Performance Considerations

### Index-Only Scans
- Ensure queries can be satisfied by the index alone
- Use `EXPLAIN ANALYZE` to verify index usage

### Index Size vs. Performance
- Larger indexes take more memory
- Balance between query performance and storage overhead
- Consider partial indexes for large tables

### Write Performance
- Each index adds overhead to INSERT/UPDATE/DELETE operations
- Batch operations when possible
- Consider dropping and recreating indexes for bulk loads

## Implementation Plan

### Phase 1: Critical Indexes (Initial Deployment)
1. Primary and foreign key indexes
2. High-cardinality columns used in WHERE clauses
3. Columns used in JOIN conditions

### Phase 2: Performance Tuning (Post-Deployment)
1. Monitor query performance
2. Add indexes based on query patterns
3. Remove unused indexes

### Phase 3: Maintenance (Ongoing)
1. Regular index maintenance
2. Monitor for index bloat
3. Adjust strategy based on usage patterns

## Related Documents
- [Database Overview](./030-DATABASE-OVERVIEW.md)
- [Schema Design Overview](./031-SCHEMA-DESIGN-OVERVIEW.md)
- [Tables Reference](./032-TABLES-REFERENCE.md)
- [Performance Tuning Guide](../038-PERFORMANCE-TUNING.md)

## Version History
| Date | Version | Description |
|------|---------|-------------|
| 2025-06-20 | 1.0 | Initial version |
