# Advanced Query Optimization Guide

## Introduction
This document provides advanced techniques and patterns for optimizing SQL queries in the Global Remit application. It covers query analysis, optimization strategies, and PostgreSQL-specific features to improve query performance.

## Table of Contents
- [Query Analysis](#query-analysis)
- [Execution Plan Interpretation](#execution-plan-interpretation)
- [Indexing Strategies](#indexing-strategies)
- [Query Rewriting](#query-rewriting)
- [Join Optimization](#join-optimization)
- [Subquery Optimization](#subquery-optimization)
- [Materialized Views](#materialized-views)
- [Common Table Expressions (CTEs)](#common-table-expressions-ctes)
- [Partitioning for Performance](#partitioning-for-performance)
- [Connection Pooling](#connection-pooling)
- [Related Documents](#related-documents)
- [Version History](#version-history)

## Query Analysis

### 1. Identifying Problematic Queries

```sql
-- Find slowest queries
SELECT 
    query,
    total_exec_time,
    calls,
    mean_exec_time,
    rows,
    100.0 * shared_blks_hit / nullif(shared_blks_hit + shared_blks_read, 0) AS hit_percent
FROM pg_stat_statements
JOIN pg_database ON pg_database.oid = dbid
WHERE datname = current_database()
ORDER BY mean_exec_time DESC
LIMIT 20;

-- Find most frequently called queries
SELECT 
    query,
    calls,
    total_exec_time,
    mean_exec_time,
    rows
FROM pg_stat_statements
ORDER BY calls DESC
LIMIT 20;

-- Find queries with high I/O
SELECT 
    query,
    (total_exec_time / 1000 / 60) as total_minutes,
    calls,
    (total_exec_time / calls) as avg_ms,
    (blk_read_time + blk_write_time) as io_time,
    (blk_read_time + blk_write_time) / total_exec_time as io_ratio
FROM pg_stat_statements
WHERE total_exec_time > 0
ORDER BY io_time DESC
LIMIT 20;
```

### 2. Using EXPLAIN ANALYZE

```sql
-- Basic EXPLAIN ANALYZE
EXPLAIN ANALYZE 
SELECT * FROM transactions WHERE amount > 1000;

-- More detailed EXPLAIN ANALYZE
EXPLAIN (ANALYZE, BUFFERS, VERBOSE, FORMAT JSON)
SELECT c.first_name, c.last_name, COUNT(t.id) as transaction_count
FROM customers c
JOIN accounts a ON c.id = a.customer_id
JOIN transactions t ON a.id = t.account_id
WHERE t.transaction_date > CURRENT_DATE - INTERVAL '30 days'
GROUP BY c.id, c.first_name, c.last_name
HAVING COUNT(t.id) > 5
ORDER BY transaction_count DESC;
```

## Execution Plan Interpretation

### 1. Common Operations

| Operation | Description | When to Worry |
|-----------|-------------|----------------|
| **Seq Scan** | Full table scan | On large tables without filters |
| **Index Scan** | Uses index to find rows | When scanning many rows |
| **Index Only Scan** | Retrieves data from index only | Ideal for covering indexes |
| **Bitmap Heap Scan** | Uses bitmap of row locations | Common for OR conditions |
| **Nested Loop** | Joins tables by nested iteration | With large result sets |
| **Hash Join** | Builds hash table for one side | With large tables |
| **Merge Join** | Sorts both inputs and merges | When inputs are pre-sorted |
| **Sort** | Sorts result set | With large result sets |
| **Hash Aggregate** | Groups using hash table | With many groups |
| **GroupAggregate** | Groups using sorted input | When input is already sorted |

### 2. Reading Execution Plans

```
# Example execution plan with cost analysis
Limit  (cost=1000.00..1000.05 rows=20 width=44) (actual time=10.123..10.125 rows=20 loops=1)
  ->  Sort  (cost=1000.00..1000.05 rows=20 width=44) (actual time=10.122..10.123 rows=20 loops=1)
        Sort Key: (count(*)) DESC
        Sort Method: quicksort  Memory: 25kB
        ->  HashAggregate  (cost=999.50..999.70 rows=20 width=44) (actual time=10.100..10.110 rows=42 loops=1)
              Group Key: c.id
              ->  Hash Join  (cost=100.50..999.30 rows=40 width=40) (actual time=1.234..10.050 rows=100 loops=1)
                    Hash Cond: (t.account_id = a.id)
                    ->  Seq Scan on transactions t  (cost=0.00..800.00 rows=10000 width=8) (actual time=0.010..5.000 rows=10000 loops=1)
                    ->  Hash  (cost=100.20..100.20 rows=20 width=40) (actual time=1.200..1.200 rows=20 loops=1)
                          Buckets: 1024  Batches: 1  Memory Usage: 10kB
                          ->  Hash Join  (cost=50.10..100.20 rows=20 width=40) (actual time=0.800..1.180 rows=20 loops=1)
                                Hash Cond: (a.customer_id = c.id)
                                ->  Seq Scan on accounts a  (cost=0.00..40.00 rows=1000 width=8) (actual time=0.010..0.200 rows=1000 loops=1)
                                ->  Hash  (cost=50.00..50.00 rows=5 width=40) (actual time=0.500..0.500 rows=5 loops=1)
                                      Buckets: 1024  Batches: 1  Memory Usage: 9kB
                                      ->  Seq Scan on customers c  (cost=0.00..50.00 rows=5 width=40) (actual time=0.010..0.300 rows=5 loops=1)
                                            Filter: (status = 'active'::text)
                                            Rows Removed by Filter: 95
Planning Time: 0.500 ms
Execution Time: 10.500 ms
```

## Indexing Strategies

### 1. Advanced Index Types

#### Partial Indexes
```sql
-- Index only active users
CREATE INDEX idx_customers_active ON customers(id) WHERE status = 'active';

-- Index for recent transactions
CREATE INDEX idx_transactions_recent ON transactions(account_id, transaction_date DESC) 
WHERE transaction_date > CURRENT_DATE - INTERVAL '90 days';
```

#### Expression Indexes
```sql
-- Case-insensitive search
CREATE INDEX idx_customers_lower_email ON customers(LOWER(email));

-- Date part index
CREATE INDEX idx_transactions_created_month ON transactions(date_trunc('month', created_at));
```

#### Composite Indexes
```sql
-- Covering index for common query
CREATE INDEX idx_transactions_covering ON transactions(account_id, status, amount)
INCLUDE (transaction_date, reference_number);
```

### 2. Index-Only Scans

```sql
-- Create a covering index
CREATE INDEX idx_transactions_covering ON transactions(account_id, transaction_date, amount);

-- Query that can use index-only scan
SELECT account_id, transaction_date, amount 
FROM transactions 
WHERE account_id = 123 
  AND transaction_date BETWEEN '2025-01-01' AND '2025-06-30';
```

## Query Rewriting

### 1. OR to UNION ALL

```sql
-- Slow with OR
SELECT * FROM transactions 
WHERE (status = 'completed' AND amount > 1000)
   OR (status = 'pending' AND created_at > NOW() - INTERVAL '1 day');

-- Faster with UNION ALL
SELECT * FROM transactions 
WHERE status = 'completed' AND amount > 1000
UNION ALL
SELECT * FROM transactions 
WHERE status = 'pending' AND created_at > NOW() - INTERVAL '1 day';
```

### 2. Avoid SELECT *

```sql
-- Instead of
SELECT * FROM customers WHERE id = 123;

-- Use
SELECT id, first_name, last_name, email 
FROM customers 
WHERE id = 123;
```

### 3. Use EXISTS instead of IN for large datasets

```sql
-- Instead of
SELECT * FROM accounts 
WHERE customer_id IN (SELECT id FROM customers WHERE status = 'active');

-- Use
SELECT a.* FROM accounts a
WHERE EXISTS (
    SELECT 1 FROM customers c 
    WHERE c.id = a.customer_id AND c.status = 'active'
);
```

## Join Optimization

### 1. Join Order

```sql
-- Instead of joining large tables first
SELECT * FROM large_table1 t1
JOIN large_table2 t2 ON t1.id = t2.t1_id
JOIN small_table s ON t2.s_id = s.id
WHERE s.filter = 'value';

-- Filter small table first
WITH filtered_small AS (
    SELECT * FROM small_table WHERE filter = 'value'
)
SELECT * FROM filtered_small s
JOIN large_table2 t2 ON s.id = t2.s_id
JOIN large_table1 t1 ON t2.t1_id = t1.id;
```

### 2. Join Types

```sql
-- Use INNER JOIN when you only want matching rows
SELECT c.*, a.account_number 
FROM customers c
INNER JOIN accounts a ON c.id = a.customer_id;

-- Use LEFT JOIN when you want all rows from the left table
SELECT c.*, COUNT(a.id) as account_count
FROM customers c
LEFT JOIN accounts a ON c.id = a.customer_id
GROUP BY c.id;
```

## Subquery Optimization

### 1. LATERAL Joins

```sql
-- Instead of correlated subquery
SELECT c.*, 
       (SELECT COUNT(*) 
        FROM accounts a 
        WHERE a.customer_id = c.id) as account_count
FROM customers c;

-- Use LATERAL join
SELECT c.*, a.account_count
FROM customers c
LEFT JOIN LATERAL (
    SELECT COUNT(*) as account_count
    FROM accounts a 
    WHERE a.customer_id = c.id
) a ON true;
```

### 2. EXISTS vs IN vs JOIN

```sql
-- EXISTS is often fastest for "exists" checks
SELECT * FROM customers c
WHERE EXISTS (
    SELECT 1 FROM accounts a 
    WHERE a.customer_id = c.id AND a.balance > 10000
);

-- IN is good for small lists
SELECT * FROM accounts
WHERE status IN ('active', 'pending_verification');

-- JOIN is good when you need data from both tables
SELECT DISTINCT c.* 
FROM customers c
JOIN accounts a ON c.id = a.customer_id
WHERE a.balance > 10000;
```

## Materialized Views

### 1. Creating Materialized Views

```sql
-- Daily transaction summary
CREATE MATERIALIZED VIEW mv_daily_transaction_summary AS
SELECT 
    date_trunc('day', transaction_date) as day,
    account_id,
    COUNT(*) as transaction_count,
    SUM(amount) as total_amount,
    COUNT(DISTINCT user_id) as unique_users
FROM transactions
GROUP BY 1, 2
WITH DATA;

-- Create index on materialized view
CREATE UNIQUE INDEX idx_mv_daily_transaction_summary 
ON mv_daily_transaction_summary(day, account_id);

-- Refresh materialized view
REFRESH MATERIALIZED VIEW CONCURRENTLY mv_daily_transaction_summary;
```

### 2. Using Materialized Views

```sql
-- Query the materialized view
SELECT 
    day,
    SUM(transaction_count) as total_transactions,
    SUM(total_amount) as total_volume
FROM mv_daily_transaction_summary
WHERE day BETWEEN '2025-01-01' AND '2025-06-30'
GROUP BY day
ORDER BY day;
```

## Common Table Expressions (CTEs)

### 1. Recursive CTEs

```sql
-- Find account hierarchy
WITH RECURSIVE account_hierarchy AS (
    -- Base case: top-level accounts
    SELECT id, name, parent_id, 1 as level, ARRAY[id] as path
    FROM accounts
    WHERE parent_id IS NULL
    
    UNION ALL
    
    -- Recursive case: child accounts
    SELECT a.id, a.name, a.parent_id, h.level + 1, h.path || a.id
    FROM accounts a
    JOIN account_hierarchy h ON a.parent_id = h.id
)
SELECT 
    id,
    repeat('    ', level - 1) || name as account_name,
    level,
    array_to_string(path, ' -> ') as path
FROM account_hierarchy
ORDER BY path;
```

### 2. Data Modification CTEs

```sql
-- Update with returning data
WITH updated_transactions AS (
    UPDATE transactions
    SET status = 'processed'
    WHERE status = 'pending'
    AND created_at < NOW() - INTERVAL '1 hour'
    RETURNING id, account_id, amount, status
)
INSERT INTO transaction_log (transaction_id, account_id, amount, status, log_time)
SELECT id, account_id, amount, status, NOW()
FROM updated_transactions;
```

## Partitioning for Performance

### 1. Time-Based Partitioning

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

-- Create monthly partitions
CREATE TABLE transactions_y2025m06 PARTITION OF transactions
    FOR VALUES FROM ('2025-06-01') TO ('2025-07-01');

CREATE TABLE transactions_y2025m07 PARTITION OF transactions
    FOR VALUES FROM ('2025-07-01') TO ('2025-08-01');

-- Create default partition
CREATE TABLE transactions_default PARTITION OF transactions DEFAULT;
```

### 2. Querying Partitioned Tables

```sql
-- This query will only scan the June 2025 partition
SELECT * FROM transactions
WHERE transaction_date BETWEEN '2025-06-15' AND '2025-06-20';
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

```
# Recommended formula
connections = ((core_count * 2) + effective_spindle_count)

# Example: 16-core server with SSD
(16 * 2) + 1 = 33 connections

# Start with 20-50 connections and adjust based on monitoring
```

## Related Documents
- [Database Overview](./030-DATABASE-OVERVIEW.md)
- [Performance Tuning](./039-PERFORMANCE-TUNING.md)
- [Indexing Strategy](./033-INDEXING-STRATEGY.md)
- [Query Patterns](./034-QUERY-PATTERNS.md)
- [Partitioning Strategy](./035-PARTITIONING-STRATEGY.md)

## Version History
| Date | Version | Description |
|------|---------|-------------|
| 2025-06-20 | 1.0 | Initial version |
