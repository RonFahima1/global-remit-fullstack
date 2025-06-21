# Database Performance Tuning Guide

## Introduction
This document provides guidelines and best practices for optimizing the performance of the Global Remit database. It covers configuration, monitoring, and optimization techniques to ensure the database operates efficiently under various workloads.

## Table of Contents
- [Performance Monitoring](#performance-monitoring)
- [Configuration Tuning](#configuration-tuning)
- [Query Optimization](#query-optimization)
- [Indexing Strategy](#indexing-strategy)
- [Partitioning](#partitioning)
- [Connection Pooling](#connection-pooling)
- [Maintenance Tasks](#maintenance-tasks)
- [Performance Testing](#performance-testing)
- [Related Documents](#related-documents)
- [Version History](#version-history)

## Performance Monitoring

### 1. Key Metrics to Monitor

#### Database-Level Metrics
- **CPU Usage**: Should be below 70% on average
- **Memory Usage**: Monitor shared buffers and work memory
- **Disk I/O**: Track read/write latency and throughput
- **Connection Count**: Monitor active and idle connections
- **Lock Contention**: Watch for blocking queries
- **Cache Hit Ratio**: Should be above 99% for production

#### Query-Level Metrics
- Slow queries (execution time > 100ms)
- Queries with high logical reads
- Frequently executed queries
- Queries with missing indexes

### 2. Monitoring Tools

#### PostgreSQL Built-in Views
```sql
-- Get top 10 longest running queries
SELECT 
    pid,
    now() - pg_stat_activity.query_start AS duration,
    query,
    state
FROM pg_stat_activity
WHERE state = 'active'
ORDER BY duration DESC
LIMIT 10;

-- Cache hit ratio
SELECT 
    sum(heap_blks_read) as heap_read,
    sum(heap_blks_hit) as heap_hit,
    sum(heap_blks_hit) / (sum(heap_blks_hit) + sum(heap_blks_read)) as ratio
FROM pg_statio_user_tables;

-- Index usage statistics
SELECT 
    schemaname,
    relname,
    indexrelname,
    idx_scan,
    idx_tup_read,
    idx_tup_fetch
FROM pg_stat_user_indexes
ORDER BY idx_scan DESC;
```

#### External Tools
- **pgBadger**: PostgreSQL log analyzer
- **pgAdmin**: GUI for monitoring and administration
- **Prometheus + Grafana**: For time-series monitoring
- **Datadog/New Relic**: APM and database monitoring

## Configuration Tuning

### 1. Memory Configuration

#### Shared Buffers
- **Purpose**: Cache for frequently accessed data
- **Recommended**: 25% of total RAM (not to exceed 8GB)
- **Example**:
  ```
  shared_buffers = 4GB
  ```

#### Work Memory
- **Purpose**: Memory for sort operations and hash tables
- **Recommended**: (Total RAM - shared_buffers) / (max_connections * 2)
- **Example**:
  ```
  work_mem = 16MB
  ```

#### Maintenance Work Memory
- **Purpose**: Memory for maintenance operations (VACUUM, CREATE INDEX)
- **Recommended**: 5% of total RAM
- **Example**:
  ```
  maintenance_work_mem = 1GB
  ```

### 2. Checkpoint Configuration

```ini
# Checkpoint tuning
checkpoint_timeout = 15min        # Range 30s-1d
checkpoint_completion_target = 0.9  # Target of checkpoint completion
max_wal_size = 4GB                # Max size of WAL files between checkpoints
min_wal_size = 1GB                # Min size of WAL files
```

### 3. Parallel Query Configuration

```ini
# Parallel query configuration
max_worker_processes = 8          # Total background worker processes
max_parallel_workers_per_gather = 4  # Workers per gather node
max_parallel_workers = 8          # Total parallel workers
parallel_leader_participation = on
```

## Query Optimization

### 1. EXPLAIN and ANALYZE

```sql
-- Basic EXPLAIN
EXPLAIN SELECT * FROM transactions WHERE amount > 1000;

-- EXPLAIN with ANALYZE for actual execution stats
EXPLAIN (ANALYZE, BUFFERS) 
SELECT * FROM transactions WHERE amount > 1000;

-- EXPLAIN with detailed output
EXPLAIN (ANALYZE, VERBOSE, BUFFERS, FORMAT JSON)
SELECT * FROM transactions WHERE amount > 1000;
```

### 2. Common Query Patterns

#### Pagination with Keyset Pagination
```sql
-- Instead of OFFSET/LIMIT
SELECT * FROM transactions
WHERE created_at < '2025-06-20'
  AND id > 'last_seen_id'
ORDER BY created_at DESC, id
LIMIT 50;
```

#### Avoiding SELECT *
```sql
-- Instead of
SELECT * FROM users;

-- Use
SELECT id, name, email FROM users;
```

#### Using EXISTS instead of IN for large datasets
```sql
-- Instead of
SELECT * FROM accounts WHERE id IN (SELECT account_id FROM transactions WHERE amount > 1000);

-- Use
SELECT a.* FROM accounts a
WHERE EXISTS (SELECT 1 FROM transactions t WHERE t.account_id = a.id AND t.amount > 1000);
```

## Indexing Strategy

### 1. Index Types

#### B-tree Indexes
- Default index type
- Good for equality and range queries
- Supports sorting and pattern matching with LIKE 'prefix%'

#### Hash Indexes
- Only supports equality comparisons
- Generally faster than B-tree for simple equality checks
- Not WAL-logged (unlogged tables only)

#### BRIN Indexes
- Block Range INdexes
- Very small size
- Good for large, naturally ordered tables (e.g., time-series data)

#### GIN/GiST Indexes
- For complex data types (JSON, arrays, full-text search)
- GIN: Good when values contain many distinct values
- GiST: Good when values have overlapping ranges

### 2. Index Creation Examples

```sql
-- Single column index
CREATE INDEX idx_users_email ON users(email);

-- Multi-column index (composite index)
CREATE INDEX idx_transactions_account_date ON transactions(account_id, transaction_date);

-- Partial index (index on a subset of rows)
CREATE INDEX idx_active_users ON users(id) WHERE status = 'active';

-- Expression index
CREATE INDEX idx_lower_username ON users(LOWER(username));

-- Concurrent index (doesn't block writes)
CREATE INDEX CONCURRENTLY idx_transactions_amount ON transactions(amount);
```

### 3. Index Maintenance

```sql
-- Rebuild an index
REINDEX INDEX idx_users_email;

-- Rebuild all indexes on a table
REINDEX TABLE users;

-- Get index usage statistics
SELECT 
    relname,
    indexrelname,
    idx_scan,
    idx_tup_read,
    idx_tup_fetch
FROM pg_stat_user_indexes
JOIN pg_statio_user_indexes USING (indexrelid)
WHERE schemaname = 'public';

-- Find unused indexes
SELECT 
    schemaname,
    relname,
    indexrelname,
    idx_scan,
    pg_size_pretty(pg_relation_size(indexrelid)) as index_size
FROM pg_stat_user_indexes
WHERE idx_scan = 0
ORDER BY pg_relation_size(indexrelid) DESC;
```

## Partitioning

### 1. Partitioning Strategies

#### Range Partitioning
```sql
-- Create partitioned table
CREATE TABLE transactions (
    id BIGSERIAL,
    account_id BIGINT NOT NULL,
    amount DECIMAL(19,4) NOT NULL,
    transaction_date TIMESTAMPTZ NOT NULL,
    status VARCHAR(20) NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    PRIMARY KEY (id, transaction_date)
) PARTITION BY RANGE (transaction_date);

-- Create partitions
CREATE TABLE transactions_y2025m06 PARTITION OF transactions
    FOR VALUES FROM ('2025-06-01') TO ('2025-07-01');

CREATE TABLE transactions_y2025m07 PARTITION OF transactions
    FOR VALUES FROM ('2025-07-01') TO ('2025-08-01');

-- Create default partition
CREATE TABLE transactions_default PARTITION OF transactions DEFAULT;
```

#### List Partitioning
```sql
-- Create partitioned table
CREATE TABLE transactions_by_region (
    id BIGSERIAL,
    region_id INTEGER NOT NULL,
    account_id BIGINT NOT NULL,
    amount DECIMAL(19,4) NOT NULL,
    transaction_date TIMESTAMPTZ NOT NULL,
    PRIMARY KEY (id, region_id)
) PARTITION BY LIST (region_id);

-- Create partitions
CREATE TABLE transactions_region_1 PARTITION OF transactions_by_region
    FOR VALUES IN (1, 2, 3);

CREATE TABLE transactions_region_2 PARTITION OF transactions_by_region
    FOR VALUES IN (4, 5, 6);
```

### 2. Partition Maintenance

```sql
-- Create new monthly partition
CREATE TABLE transactions_y2025m08 PARTITION OF transactions
    FOR VALUES FROM ('2025-08-01') TO ('2025-09-01');

-- Detach old partition (archive)
ALTER TABLE transactions DETACH PARTITION transactions_y2024m12;

-- Attach existing table as partition
CREATE TABLE transactions_archive (LIKE transactions);
-- Load data into transactions_archive
ALTER TABLE transactions ATTACH PARTITION transactions_archive
    FOR VALUES FROM ('2024-01-01') TO ('2025-01-01');
```

## Connection Pooling

### 1. PgBouncer Configuration

```ini
# pgbouncer.ini
[databases]
* = host=localhost port=5432 dbname=global_remit

[pgbouncer]
listen_port = 6432
listen_addr = *
auth_type = md5
auth_file = /etc/pgbouncer/userlist.txt
pool_mode = transaction
max_client_conn = 1000
default_pool_size = 20
reserve_pool_size = 5
log_connections = 1
log_disconnections = 1
log_pooler_errors = 1
```

### 2. Connection Pool Sizing
- **Formula**: `connections = ((core_count * 2) + effective_spindle_count)`
- **Example**: For 16-core server with SSD: `(16 * 2) + 1 = 33`
- **Recommended**: Start with 20-50 connections and adjust based on monitoring

## Maintenance Tasks

### 1. VACUUM and ANALYZE

```sql
-- Run VACUUM on a specific table
VACUUM (VERBOSE, ANALYZE) transactions;

-- Run VACUUM FULL (locks table, use with caution)
VACUUM FULL VERBOSE ANALYZE transactions;

-- Auto-vacuum configuration
ALTER TABLE transactions SET (
    autovacuum_vacuum_scale_factor = 0.05,
    autovacuum_analyze_scale_factor = 0.02
);
```

### 2. Table Statistics

```sql
-- Update statistics for query planner
ANALYZE transactions;

-- Update statistics with specific sample size
ANALYZE transactions (account_id, status);
```

## Performance Testing

### 1. pgBench

```bash
# Initialize test database
pgbench -i -s 100 global_remit

# Run read-only test
pgbench -c 10 -j 2 -T 300 -S global_remit

# Run read-write test
pgbench -c 10 -j 2 -T 300 -N global_remit
```

### 2. Custom Test Script

```sql
-- test_script.sql
\set account_id random(1, 1000000)
BEGIN;
    SELECT * FROM accounts WHERE id = :account_id;
    INSERT INTO transactions (account_id, amount, status)
    VALUES (:account_id, random() * 1000, 'pending');
END;
```

## Related Documents
- [Database Overview](./030-DATABASE-OVERVIEW.md)
- [Indexing Strategy](./033-INDEXING-STRATEGY.md)
- [Query Patterns](./034-QUERY-PATTERNS.md)
- [Partitioning Strategy](./035-PARTITIONING-STRATEGY.md)
- [Backup and Recovery](./038-BACKUP-RECOVERY.md)

## Version History
| Date | Version | Description |
|------|---------|-------------|
| 2025-06-20 | 1.0 | Initial version |
