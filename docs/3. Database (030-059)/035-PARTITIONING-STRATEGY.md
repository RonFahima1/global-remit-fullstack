# Database Partitioning Strategy

## Introduction
This document outlines the partitioning strategy for the Global Remit database to improve query performance, simplify data management, and optimize storage for large tables. Partitioning helps manage large tables by dividing them into smaller, more manageable pieces while maintaining the logical structure of the data.

## Table of Contents
- [Partitioning Benefits](#partitioning-benefits)
- [Partitioning Types](#partitioning-types)
- [Partitioning Strategy by Table](#partitioning-strategy-by-table)
- [Implementation Details](#implementation-details)
- [Partition Maintenance](#partition-maintenance)
- [Query Optimization](#query-optimization)
- [Monitoring and Management](#monitoring-and-management)
- [Migration Strategy](#migration-strategy)
- [Related Documents](#related-documents)
- [Version History](#version-history)

## Partitioning Benefits

1. **Performance**
   - Faster queries through partition pruning
   - Reduced I/O by accessing only relevant partitions
   - Better cache utilization

2. **Manageability**
   - Easier data archiving and purging
   - Simplified backup and restore operations
   - Reduced index maintenance overhead

3. **Availability**
   - Improved query performance during maintenance
   - Reduced impact of VACUUM operations
   - Better resource utilization

## Partitioning Types

### 1. Range Partitioning
- **Best for**: Time-series data (e.g., transactions, logs)
- **Example**: Partition by date ranges (daily, monthly, yearly)

### 2. List Partitioning
- **Best for**: Categorical data with known values
- **Example**: Partition by region, status, or type

### 3. Hash Partitioning
- **Best for**: Distributing data evenly across partitions
- **Example**: Partition by account_id for even distribution

## Partitioning Strategy by Table

### 1. compliance.audit_logs
**Partition Type**: Range (by month)
**Partition Key**: `event_time`
**Retention**: 12 months online, archive older partitions

```sql
-- Create partitioned table
CREATE TABLE compliance.audit_logs (
    id UUID DEFAULT gen_random_uuid(),
    event_time TIMESTAMPTZ NOT NULL,
    event_type VARCHAR(50) NOT NULL,
    table_name VARCHAR(100),
    record_id UUID,
    user_id UUID,
    old_values JSONB,
    new_values JSONB,
    client_ip INET,
    application_name TEXT,
    CONSTRAINT pk_audit_logs PRIMARY KEY (event_time, id)
) PARTITION BY RANGE (event_time);

-- Create monthly partitions
CREATE TABLE compliance.audit_logs_y2025m06 PARTITION OF compliance.audit_logs
    FOR VALUES FROM ('2025-06-01') TO ('2025-07-01');

CREATE TABLE compliance.audit_logs_y2025m07 PARTITION OF compliance.audit_logs
    FOR VALUES FROM ('2025-07-01') TO ('2025-08-01');
```

**Indexes**:
```sql
CREATE INDEX idx_audit_logs_event_type ON compliance.audit_logs(event_type);
CREATE INDEX idx_audit_logs_user_id ON compliance.audit_logs(user_id);
CREATE INDEX idx_audit_logs_table_record ON compliance.audit_logs(table_name, record_id);
```

### 2. core.transactions
**Partition Type**: Range (by month)
**Partition Key**: `transaction_date`
**Retention**: 24 months online, archive older partitions

```sql
-- Create partitioned table
CREATE TABLE core.transactions (
    id UUID DEFAULT gen_random_uuid(),
    transaction_date TIMESTAMPTZ NOT NULL,
    account_id UUID NOT NULL,
    transaction_type_id INTEGER NOT NULL,
    amount NUMERIC(20, 4) NOT NULL,
    currency CHAR(3) NOT NULL,
    reference_number VARCHAR(50) NOT NULL,
    status VARCHAR(20) NOT NULL,
    description TEXT,
    metadata JSONB,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT pk_transactions PRIMARY KEY (transaction_date, id),
    CONSTRAINT fk_transactions_account FOREIGN KEY (account_id) 
        REFERENCES core.accounts(id),
    CONSTRAINT fk_transactions_type FOREIGN KEY (transaction_type_id) 
        REFERENCES core.transaction_types(id)
) PARTITION BY RANGE (transaction_date);

-- Create monthly partitions
CREATE TABLE core.transactions_y2025m06 PARTITION OF core.transactions
    FOR VALUES FROM ('2025-06-01') TO ('2025-07-01');

CREATE TABLE core.transactions_y2025m07 PARTITION OF core.transactions
    FOR VALUES FROM ('2025-07-01') TO ('2025-08-01');
```

**Indexes**:
```sql
CREATE INDEX idx_transactions_account ON core.transactions(account_id);
CREATE INDEX idx_transactions_type ON core.transactions(transaction_type_id);
CREATE INDEX idx_transactions_reference ON core.transactions(reference_number);
CREATE INDEX idx_transactions_status ON core.transactions(status) WHERE status = 'pending';
```

### 3. compliance.kyc_verifications
**Partition Type**: List (by verification status)
**Partition Key**: `verification_status`
**Retention**: Active verifications online, archive completed/expired after 6 months

```sql
-- Create partitioned table
CREATE TABLE compliance.kyc_verifications (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    client_id UUID NOT NULL,
    verification_status VARCHAR(20) NOT NULL,
    verification_type VARCHAR(50) NOT NULL,
    verified_by UUID,
    verified_at TIMESTAMPTZ,
    expiration_date DATE,
    metadata JSONB,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT fk_kyc_client FOREIGN KEY (client_id) 
        REFERENCES core.clients(id)
) PARTITION BY LIST (verification_status);

-- Create partitions by status
CREATE TABLE compliance.kyc_pending PARTITION OF compliance.kyc_verifications
    FOR VALUES IN ('pending');

CREATE TABLE compliance.kyc_approved PARTITION OF compliance.kyc_verifications
    FOR VALUES IN ('approved');

CREATE TABLE compliance.kyc_rejected PARTITION OF compliance.kyc_verifications
    FOR VALUES IN ('rejected', 'expired');
```

**Indexes**:
```sql
CREATE INDEX idx_kyc_client_id ON compliance.kyc_verifications(client_id);
CREATE INDEX idx_kyc_expiration ON compliance.kyc_verifications(expiration_date) 
    WHERE verification_status = 'approved';
```

## Implementation Details

### 1. Partition Creation Automation

Create a function to automatically create new partitions:

```sql
CREATE OR REPLACE FUNCTION create_monthly_partitions(
    p_schema_name TEXT,
    p_table_name TEXT,
    p_partition_column TEXT,
    p_months_ahead INTEGER DEFAULT 2
) RETURNS VOID AS $$
DECLARE
    v_partition_name TEXT;
    v_start_date DATE;
    v_end_date DATE;
    v_sql TEXT;
    i INTEGER;
BEGIN
    FOR i IN 0..(p_months_ahead - 1) LOOP
        v_start_date := DATE_TRUNC('month', CURRENT_DATE + (i || ' month')::INTERVAL);
        v_end_date := v_start_date + INTERVAL '1 month';
        v_partition_name := p_table_name || '_y' || 
                           TO_CHAR(v_start_date, 'YYYY') || 'm' || 
                           LPAD(EXTRACT(MONTH FROM v_start_date)::TEXT, 2, '0');
        
        -- Check if partition already exists
        IF NOT EXISTS (
            SELECT 1 
            FROM pg_tables 
            WHERE schemaname = p_schema_name 
            AND tablename = v_partition_name
        ) THEN
            v_sql := format(
                'CREATE TABLE %I.%I PARTITION OF %I.%I 
                 FOR VALUES FROM (%L) TO (%L)',
                p_schema_name, v_partition_name, 
                p_schema_name, p_table_name,
                v_start_date, v_end_date
            );
            EXECUTE v_sql;
            
            RAISE NOTICE 'Created partition: %.%', p_schema_name, v_partition_name;
        END IF;
    END LOOP;
END;
$$ LANGUAGE plpgsql;
```

### 2. Partition Management

#### Monthly Maintenance Job
```sql
-- Run this monthly to create new partitions
SELECT create_monthly_partitions('compliance', 'audit_logs', 'event_time');
SELECT create_monthly_partitions('core', 'transactions', 'transaction_date');
```

#### Archiving Old Partitions
```sql
-- Detach old partition (e.g., after 1 year for audit_logs)
ALTER TABLE compliance.audit_logs 
DETACH PARTITION compliance.audit_logs_y2024m06;

-- Archive to slower storage or backup
-- pg_dump -t compliance.audit_logs_y2024m06 > audit_logs_202406.sql

-- Optionally, compress and move to archive storage
```

## Query Optimization

### 1. Partition Pruning
Ensure queries include the partition key in WHERE clauses to enable partition pruning:

```sql
-- Good: Will only scan relevant partitions
SELECT * 
FROM core.transactions 
WHERE transaction_date >= '2025-06-01' 
  AND transaction_date < '2025-07-01';

-- Bad: Will scan all partitions
SELECT * 
FROM core.transactions 
WHERE EXTRACT(MONTH FROM transaction_date) = 6;
```

### 2. Index-Only Scans
Create covering indexes for common query patterns:

```sql
-- For transaction reporting
CREATE INDEX idx_transactions_covering ON core.transactions 
    (transaction_date, account_id) 
    INCLUDE (amount, status, description);
```

## Monitoring and Management

### 1. Partition Information
```sql
-- List all partitions
SELECT 
    nmsp_parent.nspname AS parent_schema,
    parent.relname AS parent_table,
    nmsp_child.nspname AS child_schema,
    child.relname AS child_table,
    pg_get_expr(child.relpartbound, child.oid) AS partition_expression
FROM pg_inherits
JOIN pg_class parent ON pg_inherits.inhparent = parent.oid
JOIN pg_class child ON pg_inherits.inhrelid = child.oid
JOIN pg_namespace nmsp_parent ON nmsp_parent.oid = parent.relnamespace
JOIN pg_namespace nmsp_child ON nmsp_child.oid = child.relnamespace
WHERE parent.relname = 'audit_logs';
```

### 2. Partition Size Monitoring
```sql
-- Get partition sizes
SELECT
    n.nspname AS schema_name,
    c.relname AS table_name,
    pg_size_pretty(pg_total_relation_size(c.oid)) AS total_size,
    pg_size_pretty(pg_relation_size(c.oid)) AS table_size,
    pg_size_pretty(pg_total_relation_size(c.oid) - pg_relation_size(c.oid)) AS index_size,
    c.reltuples AS row_estimate
FROM pg_class c
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE c.relkind = 'r' 
  AND n.nspname IN ('compliance', 'core')
  AND c.relname LIKE '%y20%'  -- Match partitioned tables
ORDER BY pg_total_relation_size(c.oid) DESC;
```

## Migration Strategy

### 1. New Tables
For new tables, implement partitioning from the start using the `PARTITION BY` clause.

### 2. Existing Tables
For existing tables, follow these steps:

1. Create a new partitioned table with the same structure
2. Copy data from the old table to the new partitioned table
3. Set up constraints and indexes
4. Rename tables (swap)
5. Update any foreign key references
6. Drop the old table

Example migration script:

```sql
BEGIN;

-- 1. Create new partitioned table
CREATE TABLE core.transactions_new (LIKE core.transactions INCLUDING ALL)
PARTITION BY RANGE (transaction_date);

-- 2. Create default partition (optional, for new data that doesn't fit existing partitions)
CREATE TABLE core.transactions_default PARTITION OF core.transactions_new
    DEFAULT;

-- 3. Create initial partitions
CREATE TABLE core.transactions_y2025m06 PARTITION OF core.transactions_new
    FOR VALUES FROM ('2025-06-01') TO ('2025-07-01');

-- 4. Copy data in batches to avoid locks
INSERT INTO core.transactions_new
SELECT * FROM core.transactions
WHERE transaction_date >= '2025-06-01' AND transaction_date < '2025-07-01';

-- 5. Create indexes on the new table (if not inherited)
CREATE INDEX idx_transactions_new_account ON core.transactions_new(account_id);

-- 6. In a transaction, swap the tables
ALTER TABLE core.transactions RENAME TO transactions_old;
ALTER TABLE core.transactions_new RENAME TO transactions;

-- 7. Update foreign key constraints if needed
-- 8. Recreate views, triggers, and functions

COMMIT;

-- 9. After verifying everything works, drop the old table
-- DROP TABLE core.transactions_old;
```

## Related Documents
- [Database Overview](./030-DATABASE-OVERVIEW.md)
- [Schema Design Overview](./031-SCHEMA-DESIGN-OVERVIEW.md)
- [Tables Reference](./032-TABLES-REFERENCE.md)
- [Indexing Strategy](./033-INDEXING-STRATEGY.md)
- [Query Patterns](./034-QUERY-PATTERNS.md)
- [Performance Tuning Guide](../038-PERFORMANCE-TUNING.md)

## Version History
| Date | Version | Description |
|------|---------|-------------|
| 2025-06-20 | 1.0 | Initial version |
