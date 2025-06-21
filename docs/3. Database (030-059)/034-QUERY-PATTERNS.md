# Database Query Patterns

## Introduction
This document outlines common query patterns used in the Global Remit application and provides optimization strategies for each. Understanding these patterns helps in designing efficient database schemas and indexes.

## Table of Contents
- [Authentication & Authorization](#authentication--authorization)
- [Client Management](#client-management)
- [Account Operations](#account-operations)
- [Transaction Processing](#transaction-processing)
- [Reporting & Analytics](#reporting--analytics)
- [Compliance & Auditing](#compliance--auditing)
- [Configuration Lookups](#configuration-lookups)
- [Performance Optimization](#performance-optimization)
- [Related Documents](#related-documents)
- [Version History](#version-history)

## Authentication & Authorization

### User Login
**Pattern**: Lookup user by email/username and verify credentials
```sql
SELECT id, email, password_hash, status, role_id, last_login_at
FROM auth.users 
WHERE email = $1 AND deleted_at IS NULL;
```

**Optimizations**:
- Index on `email` (case-insensitive)
- Consider rate limiting to prevent brute force attacks
- Use prepared statements to prevent SQL injection

### Session Management
**Pattern**: Validate and update session
```sql
-- Get session
SELECT s.*, u.role_id, u.status as user_status
FROM auth.sessions s
JOIN auth.users u ON s.user_id = u.id
WHERE s.token_hash = $1 
  AND s.expires_at > NOW()
  AND u.status = 'active';

-- Update last activity
UPDATE auth.sessions 
SET last_activity = NOW()
WHERE id = $1;
```

**Optimizations**:
- Index on `token_hash`
- Partial index for active sessions
- Consider using Redis for session storage in high-traffic scenarios

## Client Management

### Client Lookup
**Pattern**: Search clients by various criteria
```sql
SELECT c.*, 
       (SELECT COUNT(*) FROM core.accounts a WHERE a.client_id = c.id) as account_count,
       k.verification_status as kyc_status
FROM core.clients c
LEFT JOIN compliance.kyc_verifications k ON k.client_id = c.id
WHERE (c.first_name ILIKE $1 OR c.last_name ILIKE $1 OR c.email = $1 OR c.phone = $1)
  AND c.status = 'active'
  AND c.deleted_at IS NULL
ORDER BY c.last_name, c.first_name
LIMIT 20 OFFSET 0;
```

**Optimizations**:
- GIN index for text search on name fields
- Separate indexes for email and phone
- Consider using a dedicated search service (e.g., Elasticsearch) for complex searches

### Client Profile with Related Data
**Pattern**: Get client with all related information
```sql
-- Client basic info
SELECT * FROM core.clients WHERE id = $1 AND deleted_at IS NULL;

-- Addresses
SELECT * FROM core.addresses WHERE client_id = $1;

-- Accounts with balances
SELECT a.*, at.name as account_type_name
FROM core.accounts a
JOIN core.account_types at ON a.account_type_id = at.id
WHERE a.client_id = $1
  AND a.status = 'active';

-- Recent transactions
SELECT t.*, tt.name as transaction_type
FROM core.transactions t
JOIN core.transaction_types tt ON t.transaction_type_id = tt.id
WHERE t.client_id = $1
ORDER BY t.transaction_date DESC
LIMIT 10;
```

**Optimizations**:
- Use transactions for data consistency
- Consider materialized views for frequently accessed data
- Implement caching for relatively static data

## Account Operations

### Account Balance Check
**Pattern**: Get current balance with recent transactions
```sql
-- Account summary
SELECT a.*, c.first_name, c.last_name, at.name as account_type
FROM core.accounts a
JOIN core.clients c ON a.client_id = c.id
JOIN core.account_types at ON a.account_type_id = at.id
WHERE a.account_number = $1
  AND a.status = 'active';

-- Recent transactions
SELECT t.*, tt.name as transaction_type
FROM core.transactions t
JOIN core.transaction_types tt ON t.transaction_type_id = tt.id
WHERE t.account_id = $1
ORDER BY t.transaction_date DESC
LIMIT 5;
```

**Optimizations**:
- Index on `account_number`
- Consider denormalizing frequently accessed data
- Cache account balance if real-time precision isn't critical

## Transaction Processing

### Money Transfer
**Pattern**: Atomic transfer between accounts
```sql
BEGIN;

-- Debit source account
UPDATE core.accounts 
SET balance = balance - $amount,
    updated_at = NOW()
WHERE id = $source_account_id
  AND balance >= $amount
RETURNING balance AS new_balance;

-- Credit destination account
UPDATE core.accounts 
SET balance = balance + $amount,
    updated_at = NOW()
WHERE id = $dest_account_id
RETURNING balance AS new_balance;

-- Record transaction
INSERT INTO core.transactions (
    transaction_reference,
    account_id,
    transaction_type_id,
    amount,
    currency,
    status,
    description,
    metadata
) VALUES (
    gen_transaction_reference(),
    $source_account_id,
    (SELECT id FROM core.transaction_types WHERE code = 'TRANSFER_OUT'),
    $amount,
    $currency,
    'completed',
    $description,
    jsonb_build_object('related_transaction_id', $dest_tx_id, 'counterparty_account_id', $dest_account_id)
) RETURNING id;

-- Record corresponding credit transaction
INSERT INTO core.transactions (
    transaction_reference,
    account_id,
    transaction_type_id,
    amount,
    currency,
    status,
    description,
    metadata
) VALUES (
    gen_transaction_reference(),
    $dest_account_id,
    (SELECT id FROM core.transaction_types WHERE code = 'TRANSFER_IN'),
    $amount,
    $currency,
    'completed',
    $description,
    jsonb_build_object('related_transaction_id', $source_tx_id, 'counterparty_account_id', $source_account_id)
) RETURNING id;

COMMIT;
```

**Optimizations**:
- Use transaction isolation level SERIALIZABLE for critical operations
- Implement idempotency keys for retry safety
- Consider batching for high-volume operations

## Reporting & Analytics

### Daily Transaction Summary
**Pattern**: Aggregate transactions by type and status
```sql
SELECT 
    DATE(transaction_date) as transaction_date,
    tt.name as transaction_type,
    COUNT(*) as transaction_count,
    SUM(amount) as total_amount,
    COUNT(DISTINCT account_id) as unique_accounts
FROM core.transactions t
JOIN core.transaction_types tt ON t.transaction_type_id = tt.id
WHERE transaction_date >= CURRENT_DATE - INTERVAL '30 days'
GROUP BY DATE(transaction_date), tt.name
ORDER BY transaction_date DESC, transaction_type;
```

**Optimizations**:
- Create a BRIN index on `transaction_date`
- Consider materialized views for complex aggregations
- Schedule pre-aggregation during off-peak hours

## Compliance & Auditing

### Audit Trail
**Pattern**: Query system activity for compliance
```sql
SELECT 
    al.event_time,
    u.email as user_email,
    al.event_type,
    al.table_name,
    al.record_id,
    al.old_values,
    al.new_values,
    al.client_ip
FROM compliance.audit_logs al
LEFT JOIN auth.users u ON al.user_id = u.id
WHERE al.event_time >= $start_date
  AND al.event_time < $end_date
  AND ($table_name IS NULL OR al.table_name = $table_name)
  AND ($user_id IS NULL OR al.user_id = $user_id)
ORDER BY al.event_time DESC
LIMIT 100;
```

**Optimizations**:
- Partition `audit_logs` by date
- Create appropriate indexes on filter columns
- Consider archiving old audit data

## Configuration Lookups

### Exchange Rate Lookup
**Pattern**: Get current exchange rate
```sql
SELECT er.rate, er.effective_date
FROM config.exchange_rates er
WHERE er.from_currency = $from_currency
  AND er.to_currency = $to_currency
  AND er.effective_date <= CURRENT_DATE
  AND er.is_active = true
ORDER BY er.effective_date DESC
LIMIT 1;
```

**Optimizations**:
- Composite index on `(from_currency, to_currency, effective_date)`
- Cache exchange rates in application memory
- Consider using a materialized view for active rates

## Performance Optimization

### Common Optimization Techniques

1. **Query Planning**
   ```sql
   -- Analyze query execution plan
   EXPLAIN ANALYZE 
   SELECT * FROM core.transactions WHERE account_id = $1;
   ```

2. **Index-Only Scans**
   ```sql
   -- Create covering index
   CREATE INDEX idx_transactions_covering ON core.transactions(account_id, transaction_date)
   INCLUDE (amount, description);
   ```

3. **Query Rewriting**
   ```sql
   -- Instead of IN with subquery
   SELECT * FROM core.accounts WHERE client_id IN (SELECT id FROM core.clients WHERE status = 'active');
   
   -- Use JOIN
   SELECT a.* 
   FROM core.accounts a
   JOIN core.clients c ON a.client_id = c.id
   WHERE c.status = 'active';
   ```

4. **Pagination**
   ```sql
   -- Keyset pagination (faster than OFFSET for large datasets)
   SELECT * FROM core.transactions
   WHERE transaction_date < $last_date
   ORDER BY transaction_date DESC
   LIMIT 20;
   ```

## Related Documents
- [Database Overview](./030-DATABASE-OVERVIEW.md)
- [Schema Design Overview](./031-SCHEMA-DESIGN-OVERVIEW.md)
- [Tables Reference](./032-TABLES-REFERENCE.md)
- [Indexing Strategy](./033-INDEXING-STRATEGY.md)
- [Performance Tuning Guide](../038-PERFORMANCE-TUNING.md)

## Version History
| Date | Version | Description |
|------|---------|-------------|
| 2025-06-20 | 1.0 | Initial version |
