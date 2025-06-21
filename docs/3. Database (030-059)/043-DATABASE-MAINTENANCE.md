# Database Maintenance Guide

## Introduction
This document outlines the regular database maintenance procedures for the Global Remit application. Proper maintenance is essential for ensuring database performance, stability, and data integrity over time.

## Table of Contents
- [Maintenance Overview](#maintenance-overview)
- [Routine Maintenance Tasks](#routine-maintenance-tasks)
- [Vacuum and Analyze](#vacuum-and-analyze)
- [Index Maintenance](#index-maintenance)
- [Statistics Collection](#statistics-collection)
- [Log Management](#log-management)
- [Backup Verification](#backup-verification)
- [Performance Monitoring](#performance-monitoring)
- [Capacity Planning](#capacity-planning)
- [Security Maintenance](#security-maintenance)
- [Disaster Recovery Testing](#disaster-recovery-testing)
- [Maintenance Automation](#maintenance-automation)
- [Related Documents](#related-documents)
- [Version History](#version-history)

## Maintenance Overview

### Importance of Regular Maintenance
- Prevents database bloat
- Maintains query performance
- Ensures data consistency
- Identifies potential issues early
- Optimizes storage usage

### Maintenance Categories

| Category | Frequency | Description |
|----------|-----------|-------------|
| **Vacuum** | Daily | Reclaims storage and updates visibility map |
| **Analyze** | Daily | Updates statistics for query planner |
| **Reindex** | Weekly | Rebuilds indexes to reduce fragmentation |
| **Statistics** | Daily | Updates database statistics |
| **Log Rotation** | Daily | Manages database log files |
| **Backup Verification** | Weekly | Validates backup integrity |
| **Security Audit** | Monthly | Reviews user permissions and access |

## Routine Maintenance Tasks

### 1. Daily Tasks

#### Check Database Health
```sql
-- Check for long-running queries
SELECT 
    pid, 
    now() - query_start AS duration, 
    query
FROM pg_stat_activity 
WHERE state != 'idle' 
  AND now() - query_start > interval '5 minutes';

-- Check for locks
SELECT blocked_locks.pid AS blocked_pid,
       blocked_activity.usename AS blocked_user,
       blocking_locks.pid AS blocking_pid,
       blocking_activity.usename AS blocking_user,
       blocked_activity.query AS blocked_statement,
       blocking_activity.query AS current_statement_in_blocking_process
FROM pg_catalog.pg_locks blocked_locks
JOIN pg_catalog.pg_stat_activity blocked_activity 
    ON blocked_activity.pid = blocked_locks.pid
JOIN pg_catalog.pg_locks blocking_locks 
    ON blocking_locks.locktype = blocked_locks.locktype
    AND blocking_locks.DATABASE IS NOT DISTINCT FROM blocked_locks.DATABASE
    AND blocking_locks.relation IS NOT DISTINCT FROM blocked_locks.relation
    AND blocking_locks.page IS NOT DISTINCT FROM blocked_locks.page
    AND blocking_locks.tuple IS NOT DISTINCT FROM blocked_locks.tuple
    AND blocking_locks.virtualxid IS NOT DISTINCT FROM blocked_locks.virtualxid
    AND blocking_locks.transactionid IS NOT DISTINCT FROM blocked_locks.transactionid
    AND blocking_locks.classid IS NOT DISTINCT FROM blocked_locks.classid
    AND blocking_locks.objid IS NOT DISTINCT FROM blocked_locks.objid
    AND blocking_locks.objsubid = blocked_locks.objsubid
    AND blocking_locks.pid != blocked_locks.pid
JOIN pg_catalog.pg_stat_activity blocking_activity 
    ON blocking_activity.pid = blocking_locks.pid
WHERE NOT blocked_locks.GRANTED;
```

#### Check Disk Space
```sql
-- Check table sizes
SELECT 
    table_schema,
    table_name,
    pg_size_pretty(pg_total_relation_size('"' || table_schema || '"."' || table_name || '"')) as total_size,
    pg_size_pretty(pg_relation_size('"' || table_schema || '"."' || table_name || '"')) as table_size,
    pg_size_pretty(pg_total_relation_size('"' || table_schema || '"."' || table_name || '"') - pg_relation_size('"' || table_schema || '"."' || table_name || '"')) as index_size
FROM information_schema.tables
WHERE table_schema NOT IN ('pg_catalog', 'information_schema')
ORDER BY pg_total_relation_size('"' || table_schema || '"."' || table_name || '"') DESC;

-- Check database size
SELECT 
    d.datname as database,
    pg_size_pretty(pg_database_size(d.datname)) as size
FROM pg_database d
ORDER BY pg_database_size(d.datname) DESC;
```

### 2. Weekly Tasks

#### Check for Unused Indexes
```sql
SELECT
    schemaname || '.' || relname AS table,
    indexrelname AS index,
    pg_size_pretty(pg_relation_size(i.indexrelid)) AS index_size,
    idx_scan as index_scans
FROM pg_stat_user_indexes ui
JOIN pg_index i ON ui.indexrelid = i.indexrelid
WHERE NOT indisunique
  AND idx_scan < 50
  AND pg_relation_size(relid) > 5 * 8192
ORDER BY pg_relation_size(i.indexrelid) / nullif(idx_scan, 0) DESC NULLS FIRST,
         pg_relation_size(i.indexrelid) DESC;
```

#### Check for Missing Indexes
```sql
SELECT
    relname AS table,
    seq_scan - idx_scan AS too_much_seq,
    CASE WHEN seq_scan - COALESCE(idx_scan, 0) > 0 THEN 'Missing Index' ELSE 'OK' END AS status,
    pg_size_pretty(pg_relation_size(relid::regclass)) AS table_size,
    'CREATE INDEX ix_' || relname || '_' || 
    array_to_string(array_agg(attname), '_') || ' ON ' || relname || 
    ' (' || array_to_string(array_agg(attname), ', ') || ');' AS create_index_sql
FROM pg_stat_user_tables
CROSS JOIN LATERAL (
    SELECT a.attname
    FROM pg_attribute a
    WHERE a.attrelid = pg_stat_user_tables.relid
      AND a.attnum > 0
      AND NOT a.attisdropped
    ORDER BY a.attnum
    LIMIT 5
) a
WHERE schemaname = 'public'
  AND seq_scan > 50
  AND seq_scan > 50 * idx_scan
  AND pg_relation_size(relid) > 5 * 8192
GROUP BY relid, relname, seq_scan, idx_scan
ORDER BY too_much_seq DESC;
```

## Vacuum and Analyze

### Automatic Vacuum Configuration
```ini
# postgresql.conf
autovacuum = on
log_autovacuum_min_duration = 0  # Log all autovacuum runs
autovacuum_max_workers = 3
autovacuum_naptime = 1min
autovacuum_vacuum_threshold = 50
autovacuum_analyze_threshold = 50
autovacuum_vacuum_scale_factor = 0.2
autovacuum_analyze_scale_factor = 0.1
autovacuum_vacuum_cost_delay = 2ms
autovacuum_vacuum_cost_limit = 200
```

### Manual Vacuum Commands
```sql
-- Analyze specific table
ANALYZE VERBOSE table_name;

-- Vacuum specific table
VACUUM (VERBOSE, ANALYZE) table_name;

-- Full vacuum (locks table)
VACUUM FULL VERBOSE ANALYZE table_name;

-- Vacuum all databases
VACUUM;

-- Analyze all databases
ANALYZE;
```

### Monitoring Vacuum Activity
```sql
-- Check autovacuum status
SELECT 
    schemaname,
    relname,
    n_dead_tup,
    last_vacuum,
    last_autovacuum,
    last_autoanalyze,
    last_analyze,
    autovacuum_count,
    autoanalyze_count
FROM pg_stat_user_tables
ORDER BY n_dead_tup DESC;

-- Check current vacuum processes
SELECT 
    pid, 
    datname, 
    usename, 
    client_addr, 
    state, 
    query
FROM pg_stat_activity 
WHERE query LIKE '%VACUUM%' 
   OR query LIKE '%ANALYZE%';
```

## Index Maintenance

### Rebuilding Indexes
```sql
-- Rebuild all indexes for a table
REINDEX TABLE table_name;

-- Rebuild a specific index
REINDEX INDEX index_name;

-- Rebuild all indexes in a schema
REINDEX SCHEMA schema_name;

-- Rebuild all indexes in a database
REINDEX DATABASE database_name;

-- Concurrently rebuild index (non-blocking)
REINDEX INDEX CONCURRENTLY index_name;
```

### Index Bloat Analysis
```sql
WITH constants AS (
    SELECT current_setting('block_size')::numeric AS bs, 23 AS hdr, 4 AS ma
)
SELECT
    nspname AS schema_name,
    tblname AS table_name,
    idxname AS index_name,
    bs*(relpages)::bigint AS real_size,
    bs*(relpages-est_pages)::bigint AS extra_size,
    100 * (relpages-est_pages)::float / NULLIF(relpages, 0) AS extra_ratio,
    fillfactor,
    CASE WHEN relpages > est_pages_ff
        THEN bs*(relpages-est_pages_ff)
        ELSE 0
    END AS bloat_size,
    CASE WHEN relpages > est_pages_ff
        THEN 100 * (relpages-est_pages_ff)::float / NULLIF(relpages, 0)
        ELSE 0
    END AS bloat_ratio,
    est_pages AS est_pages,
    relpages AS rel_pages
FROM (
    SELECT
        nspname, tblname, idxname, relpages, fillfactor,
        ( 
            (reltuples*index_tuple_len + 8192 - 1) / 8192 
        ) AS est_pages,
        ( 
            (reltuples*index_tuple_len + 8192 - 1) / 8192 * fillfactor / 100 
        ) AS est_pages_ff,
        bs, hdr, ma
    FROM (
        SELECT
            n.nspname, i.tblname, i.idxname, i.reltuples, i.relpages, i.relam,
            COALESCE( 
                NULLIF(s.stakind1, 99) IS DISTINCT FROM 0 AND s.stakind1 < 100,
                FALSE 
            ) AS starelhasindex,
            COALESCE(
                NULLIF(s.stakind1, 99) = 0,
                FALSE 
            ) AS staunique,
            COALESCE(
                NULLIF(s.stakind1, 99) = 0,
                FALSE 
            ) AS stanullfrac,
            COALESCE(
                NULLIF(s.stakind1, 99) = 0,
                FALSE 
            ) AS stawidth,
            COALESCE(
                NULLIF(s.stakind1, 99) = 0,
                FALSE 
            ) AS stadistinct,
            i.idx_scan, i.idx_tup_read, i.idx_tup_fetch,
            i.idx_scan / NULLIF(i.idx_tup_read, 0) AS selectivity,
            i.idx_tup_read / NULLIF(i.idx_scan, 0) AS avg_tuples_per_scan,
            i.idx_tup_fetch / NULLIF(i.idx_scan, 0) AS avg_tuples_fetched,
            i.fillfactor,
            current_setting('block_size')::numeric AS bs,
            CASE 
                WHEN version() ~ 'mingw32' OR version() ~ '64-bit|x86_64|ppc64|ia64|amd64' THEN 8
                ELSE 4
            END AS ma,
            24 AS hdr
        FROM (
            SELECT
                c.relname AS tblname,
                ipg.relpages,
                ipg.reltuples,
                i.schemaname,
                i.tablename,
                i.indexname AS idxname,
                i.idx_scan,
                i.idx_tup_read,
                i.idx_tup_fetch,
                i.indexdef,
                i.fillfactor
            FROM pg_index x
            JOIN pg_class c ON c.oid = x.indrelid
            JOIN pg_class c2 ON c2.oid = x.indexrelid
            JOIN pg_indexes i ON i.indexname = c2.relname
            JOIN pg_stat_all_indexes ipg ON ipg.indexrelid = x.indexrelid
            WHERE c.relkind = 'r'::"char"
              AND c.relpages > 100
              AND i.schemaname NOT IN ('pg_catalog', 'pg_toast')
        ) i
        LEFT JOIN pg_statistic s ON (
            s.starelid = (
                SELECT oid FROM pg_class 
                WHERE relname = i.tablename 
                AND relnamespace = (
                    SELECT oid FROM pg_namespace 
                    WHERE nspname = i.schemaname
                )
            )
            AND s.staattnum = 1
        )
        JOIN pg_namespace n ON n.nspname = i.schemaname
    ) AS q1
    CROSS JOIN constants
) AS q2
ORDER BY bloat_size DESC;
```

## Statistics Collection

### Manual Statistics Update
```sql
-- Update statistics for a table
ANALYZE table_name;

-- Update statistics for a specific column
ANALYZE table_name (column1, column2);

-- Update statistics with specific sample size
ANALYZE table_name WITH (analyze_security = off);
```

### Statistics Configuration
```ini
# postgresql.conf
# Increase statistics targets for better query plans
default_statistics_target = 100
maintenance_work_mem = 64MB
```

## Log Management

### Log Configuration
```ini
# postgresql.conf
log_destination = 'stderr'
logging_collector = on
log_directory = 'pg_log'
log_filename = 'postgresql-%Y-%m-%d_%H%M%S.log'
log_rotation_age = 1d
log_rotation_size = 100MB
log_min_duration_statement = 1000  # Log slow queries (ms)
log_checkpoints = on
log_connections = on
log_disconnections = on
log_lock_waits = on
log_temp_files = 0
log_autovacuum_min_duration = 0
log_line_prefix = '%t [%p]: [%l-1] user=%u,db=%d,app=%a,client=%h '
```

### Log Analysis
```bash
# Find slow queries
cat postgresql-*.log | grep "duration: " | sort -n -k2

# Find errors
cat postgresql-*.log | grep -i -E "error|fail|fatal|panic"

# Find connection issues
cat postgresql-*.log | grep -i "connection"

# Find checkpoints
cat postgresql-*.log | grep -i "checkpoint"
```

## Backup Verification

### Verify Backup Integrity
```bash
# For logical backups
pg_restore -l backup_file.dump > /dev/null

# For physical backups
pg_verifybackup /path/to/backup

# Test restore in a temporary location
pg_restore --dbname=test_db --no-owner --role=postgres backup_file.dump
```

## Performance Monitoring

### Key Metrics
```sql
-- Cache hit ratio
SELECT 
    sum(heap_blks_read) as heap_read,
    sum(heap_blks_hit)  as heap_hit,
    sum(heap_blks_hit) / (sum(heap_blks_hit) + sum(heap_blks_read)) as ratio
FROM 
    pg_statio_user_tables;

-- Index hit ratio
SELECT 
    sum(idx_blks_read) as idx_read,
    sum(idx_blks_hit)  as idx_hit,
    (sum(idx_blks_hit) - sum(idx_blks_read)) / sum(idx_blks_hit) as ratio
FROM 
    pg_statio_user_indexes;

-- Check for table bloat
SELECT
    nspname,
    tblname,
    bs*tblpages AS real_size,
    (tblpages-est_tblpages)*bs AS extra_size,
    CASE WHEN tblpages - est_tblpages > 0
        THEN 100 * (tblpages - est_tblpages)/tblpages::float
        ELSE 0
    END AS extra_ratio
FROM (
    SELECT
        nspname, tblname, bs, tblpages, fillfactor,
        ( 
            (tblpages - (tblpages * (1 - fillfactor/100))^3) / NULLIF(tblpages, 0) + 1 
        ) * (1 - 1/100) * tblpages AS est_tblpages
    FROM (
        SELECT
            n.nspname,
            t.relname AS tblname,
            c.reltuples,
            c.relpages,
            c.reltuples / NULLIF(c.relpages, 0) AS rows_per_page,
            current_setting('block_size')::int AS bs,
            COALESCE(
                (SELECT (regexp_matches(reloptions::text, E'.*fillfactor=(\\d+).*'))[1]), 
                '100'
            )::real AS fillfactor
        FROM pg_class c
        JOIN pg_namespace n ON n.oid = c.relnamespace
        LEFT JOIN pg_tablespace t ON t.oid = c.reltablespace
        WHERE c.relkind = 'r'
          AND n.nspname NOT IN ('pg_catalog', 'information_schema')
          AND c.relpages > 10
    ) t
) t
ORDER BY extra_size DESC;
```

## Capacity Planning

### Growth Trends
```sql
-- Table growth over time
SELECT 
    relname,
    pg_size_pretty(pg_total_relation_size(relid)) as total_size,
    pg_size_pretty(pg_relation_size(relid)) as table_size,
    pg_size_pretty(pg_total_relation_size(relid) - pg_relation_size(relid)) as index_size,
    n_live_tup as row_count,
    pg_stat_get_last_analyze_time(relid) as last_analyze,
    pg_stat_get_last_autoanalyze_time(relid) as last_autoanalyze
FROM pg_stat_user_tables 
ORDER BY pg_total_relation_size(relid) DESC;

-- Database growth
SELECT 
    d.datname,
    pg_size_pretty(pg_database_size(d.datname)) as size,
    pg_size_pretty(pg_database_size(d.datname) - 
        (SELECT pg_database_size(d.datname) - 
            (SELECT sum(pg_relation_size(relid)) 
             FROM pg_stat_user_tables 
             WHERE schemaname = 'public')
         )
    ) as table_size,
    pg_size_pretty((SELECT sum(pg_relation_size(relid)) 
                   FROM pg_stat_user_indexes 
                   WHERE schemaname = 'public')) as index_size,
    (SELECT count(*) FROM pg_stat_user_tables WHERE schemaname = 'public') as table_count,
    (SELECT count(*) FROM pg_stat_user_indexes WHERE schemaname = 'public') as index_count
FROM pg_database d
WHERE d.datname = current_database();
```

## Security Maintenance

### User and Permission Audit
```sql
-- List all users and their permissions
SELECT 
    r.rolname, 
    r.rolsuper, 
    r.rolinherit,
    r.rolcreaterole,
    r.rolcreatedb,
    r.rolcanlogin,
    r.rolconnlimit,
    r.rolvaliduntil,
    ARRAY(
        SELECT b.rolname
        FROM pg_catalog.pg_auth_members m
        JOIN pg_catalog.pg_roles b ON (m.roleid = b.oid)
        WHERE m.member = r.oid
    ) as memberof
FROM pg_catalog.pg_roles r
WHERE r.rolname NOT IN ('pg_signal_backend', 'rds_iam')
ORDER BY 1;

-- Check object ownership
SELECT
    n.nspname as schema,
    c.relname as object,
    CASE c.relkind
        WHEN 'r' THEN 'table'
        WHEN 'v' THEN 'view'
        WHEN 'm' THEN 'materialized view'
        WHEN 'i' THEN 'index'
        WHEN 'S' THEN 'sequence'
        WHEN 's' THEN 'special'
        WHEN 'f' THEN 'foreign table'
        WHEN 'p' THEN 'partitioned table'
        WHEN 'I' THEN 'partitioned index'
    END as type,
    pg_catalog.pg_get_userbyid(c.relowner) as owner
FROM
    pg_catalog.pg_class c
LEFT JOIN
    pg_catalog.pg_namespace n ON n.oid = c.relnamespace
WHERE
    c.relkind IN ('r','p','v','m','S','f','')
    AND n.nspname !~ '^pg_toast'
    AND n.nspname !~ '^pg_catalog'
    AND n.nspname !~ '^information_schema'
ORDER BY 1, 2;
```

### Security Hardening
```sql
-- Remove public schema privileges
REVOKE ALL ON SCHEMA public FROM PUBLIC;

-- Set secure search path
ALTER ROLE app_user SET search_path = app_schema, public;

-- Set statement timeout
ALTER DATABASE your_database SET statement_timeout = '30s';

-- Disable unused extensions
DROP EXTENSION IF EXISTS plperl;
DROP EXTENSION IF EXISTS pltcl;
DROP EXTENSION IF EXISTS plpythonu;
```

## Disaster Recovery Testing

### Test Restore Procedures
1. **Documented Restore Process**
   - Step-by-step instructions for restoring from backup
   - Required credentials and access details
   - Expected timing for restore operations

2. **Regular Testing Schedule**
   - Monthly: Test restore of critical tables
   - Quarterly: Full database restore to staging
   - Annually: Full disaster recovery drill

3. **Verification Steps**
   - Data consistency checks
   - Application connectivity testing
   - Performance benchmarking

## Maintenance Automation

### Scheduled Jobs (pgAgent/pg_cron)

```sql
-- Install pg_cron
CREATE EXTENSION pg_cron;

-- Schedule daily vacuum and analyze
SELECT cron.schedule('0 2 * * *', 'VACUUM ANALYZE VERBOSE');

-- Schedule weekly reindex
SELECT cron.schedule('0 3 * * 0', 'REINDEX DATABASE global_remit');

-- Schedule daily statistics collection
SELECT cron.schedule('0 1 * * *', 'ANALYZE VERBOSE');
```

### Monitoring Scripts
```bash
#!/bin/bash
# check_disk_space.sh
THRESHOLD=90
USAGE=$(df -h /var/lib/postgresql | grep -v Filesystem | awk '{print $5}' | tr -d '%')

if [ $USAGE -gt $THRESHOLD ]; then
    echo "WARNING: Disk space usage is ${USAGE}%" | mail -s "Database Disk Space Alert" dba@example.com
fi
```

## Related Documents
- [Database Overview](./030-DATABASE-OVERVIEW.md)
- [Backup and Recovery](./037-BACKUP-RECOVERY.md)
- [Performance Tuning](./038-PERFORMANCE-TUNING.md)
- [Data Replication](./042-DATA-REPLICATION.md)
- [Connection Pooling](./041-CONNECTION-POOLING.md)

## Version History
| Date | Version | Description |
|------|---------|-------------|
| 2025-06-20 | 1.0 | Initial version |
