# Database Replication Guide

## Introduction
This document outlines the data replication strategy for the Global Remit application. Replication is crucial for ensuring high availability, disaster recovery, and read scalability of the database infrastructure.

## Table of Contents
- [Replication Overview](#replication-overview)
- [Replication Topologies](#replication-topologies)
- [PostgreSQL Replication Setup](#postgresql-replication-setup)
- [Monitoring and Maintenance](#monitoring-and-maintenance)
- [Failover Procedures](#failover-procedures)
- [Disaster Recovery](#disaster-recovery)
- [Performance Considerations](#performance-considerations)
- [Security Considerations](#security-considerations)
- [Related Documents](#related-documents)
- [Version History](#version-history)

## Replication Overview

### What is Database Replication?
Database replication involves maintaining multiple copies of data across different database servers to ensure data availability, reliability, and fault tolerance.

### Benefits
- **High Availability**: Continuous operation during server failures
- **Load Balancing**: Distribute read queries across multiple servers
- **Disaster Recovery**: Protect against data center failures
- **Geographic Distribution**: Serve users from the nearest location
- **Zero-Downtime Maintenance**: Perform maintenance on replicas first

### Replication Types

| Type | Description | Use Case |
|------|-------------|----------|
| **Synchronous** | Transactions committed only after all replicas confirm | Critical financial data |
| **Asynchronous** | Primary commits before replicas confirm | High throughput systems |
| **Logical** | Row-level changes are replicated | Selective replication, cross-version |
| **Physical** | Disk-level changes are replicated | Exact copy of the database |
| **Cascading** | Replicas can have their own replicas | Geographic distribution |

## Replication Topologies

### 1. Single Primary, Multiple Replicas
```
                    [Primary]
                       |
        +---------------+---------------+
        |               |               |
    [Replica 1]   [Replica 2]   [Replica 3]
```

### 2. Multi-Master
```
                  [Master 1]    [Master 2]
                      \             /
                       \           /
                    [Synchronization]
```

### 3. Bi-Directional Replication
```
                  [Primary A] <-----> [Primary B]
```

### 4. Cascading Replication
```
                    [Primary]
                       |
                   [Replica 1]
                       |
                +------+------+
                |             |
          [Replica 1.1]  [Replica 1.2]
```

## PostgreSQL Replication Setup

### 1. Prerequisites
- PostgreSQL 12+ (latest stable version recommended)
- Identical PostgreSQL versions on all nodes
- Network connectivity between servers
- Sufficient disk space on all nodes
- Synchronized system clocks (NTP recommended)

### 2. Configuration (Primary Server)

#### postgresql.conf
```ini
# Connection Settings
listen_addresses = '*'  # Or specific IP
port = 5432
max_connections = 100

# Replication
wal_level = replica
max_wal_senders = 10    # Max number of replication slots
wal_keep_size = 1024    # in MB
hot_standby = on

# Performance
max_replication_slots = 10
max_wal_senders = 10
synchronous_commit = on
synchronous_standby_names = '*'  # For synchronous replication
```

#### pg_hba.conf
```
# Allow replication connections from replicas
# TYPE  DATABASE        USER            ADDRESS                 METHOD
host    replication     replicator      192.168.1.0/24          md5
```

#### Create Replication User
```sql
CREATE ROLE replicator WITH REPLICATION LOGIN PASSWORD 'secure_password';
```

### 3. Setting Up a Replica (Standby Server)

#### Initial Base Backup
```bash
# On the replica server
pg_basebackup -h primary_host -U replicator -p 5432 -D /var/lib/postgresql/14/main -Fp -Xs -P -R
```

#### Configure Replica (postgresql.conf)
```ini
hot_standby = on
hot_standby_feedback = on
max_standby_streaming_delay = 30s
max_standby_archive_delay = 30s
hot_standby_feedback = on
```

#### Create recovery.conf (if not auto-generated)
```
standby_mode = 'on'
primary_conninfo = 'host=primary_host port=5432 user=replicator password=secure_password'
primary_slot_name = 'replica1_slot'
recovery_target_timeline = 'latest'
```

### 4. Logical Replication Setup

#### On Primary
```sql
-- Enable logical replication
wal_level = logical

-- Create a publication
CREATE PUBLICATION global_remit_pub FOR TABLE 
    clients, accounts, transactions, transaction_ledger;

-- Add specific columns if needed
ALTER PUBLICATION global_remit_pub 
    ADD TABLE clients (id, first_name, last_name, status);
```

#### On Replica
```sql
-- Create the same tables as primary
CREATE TABLE clients (
    -- table definition
);

-- Create a subscription
CREATE SUBSCRIPTION global_remit_sub
    CONNECTION 'host=primary_host dbname=global_remit user=replicator password=secure_password'
    PUBLICATION global_remit_pub
    WITH (copy_data = true);
```

## Monitoring and Maintenance

### Key Metrics to Monitor

| Metric | Description | Warning Threshold |
|--------|-------------|-------------------|
| Replication Lag | Delay in applying changes | > 1 second |
| Replication Slots | Used/remaining slots | > 80% of max |
| WAL Files | Accumulated WAL files | Growing continuously |
| Connection Status | Replica connection status | Any disconnection |
| Replication Delay | Time since last transaction | > 5 seconds |

### Monitoring Queries

#### Check Replication Status
```sql
-- On primary
SELECT * FROM pg_stat_replication;

-- Check replication slots
SELECT * FROM pg_replication_slots;

-- Check WAL sender processes
SELECT * FROM pg_stat_activity 
WHERE backend_type = 'walsender';
```

#### On Replica
```sql
-- Check replication status
SELECT * FROM pg_stat_wal_receiver;

-- Check lag in bytes
SELECT pg_wal_lsn_diff(
    pg_current_wal_lsn(), 
    replay_lsn
) AS replication_lag_bytes
FROM pg_stat_replication;

-- Check lag in seconds
SELECT 
    client_hostname,
    state,
    pg_wal_lsn_diff(
        sent_lsn,
        replay_lsn
    ) as bytes_lag,
    EXTRACT(EPOCH FROM (now() - reply_time)) as seconds_lag
FROM pg_stat_replication;
```

### Maintenance Tasks

#### Add New Replica
1. Take base backup from primary
2. Configure recovery settings
3. Start PostgreSQL on replica
4. Monitor replication status

#### Remove Replica
1. Stop PostgreSQL on replica
2. On primary: `SELECT pg_drop_replication_slot('replica_slot');`
3. Remove recovery configuration
4. Restart PostgreSQL if needed

## Failover Procedures

### Planned Failover
1. Stop application traffic to primary
2. Promote standby to primary
3. Reconfigure remaining replicas to follow new primary
4. Update application connection strings

### Unplanned Failover
1. Verify primary is down
2. Promote most up-to-date standby
3. Reconfigure other standbys
4. Update DNS/load balancer configuration
5. Notify team and investigate original failure

### Using pg_rewind (for failed primary reintegration)
```bash
# On failed primary (after fixing issues)
pg_ctl stop

# On new primary
psql -c "SELECT pg_create_physical_replication_slot('failed_primary_slot');"

# On failed primary
pg_rewind -D /var/lib/postgresql/14/main --source-server="host=new_primary user=postgres"

# Create recovery.conf
cat > /var/lib/postgresql/14/main/recovery.conf << EOF
standby_mode = 'on'
primary_conninfo = 'host=new_primary user=replicator password=secure_password'
primary_slot_name = 'failed_primary_slot'
recovery_target_timeline = 'latest'
EOF

# Start PostgreSQL
pg_ctl start
```

## Disaster Recovery

### Backup and PITR
```bash
# Base backup
pg_basebackup -D /backup/global_remit_base -Ft -z -P -U backup

# Archive WAL files
archive_command = 'test ! -f /mnt/backup/archivedir/%f && cp %p /mnt/backup/archivedir/%f'

# Point-in-Time Recovery
restore_command = 'cp /mnt/backup/archivedir/%f %p'
recovery_target_time = '2025-06-20 15:30:00+03:00'
```

### Geo-Redundancy
1. Set up replicas in different availability zones
2. Configure cross-region replication
3. Implement automated failover between regions
4. Test failover procedures regularly

## Performance Considerations

### Read Scaling
- Route read queries to replicas
- Use connection pooling with read/write splitting
- Monitor replica lag and load balance accordingly

### Write Scaling
- Consider sharding for write-heavy workloads
- Implement connection pooling on application side
- Use batch operations when possible

### Network Optimization
- Use dedicated network links for replication
- Compress WAL traffic for WAN replication
- Monitor network latency and bandwidth

## Security Considerations

### Encryption
- Use SSL for replication traffic
- Encrypt WAL files at rest
- Use strong authentication for replication users

### Access Control
- Limit replication user permissions
- Use separate credentials for each replica
- Regularly rotate passwords and keys

### Audit
- Log all replication-related activities
- Monitor for unauthorized replication attempts
- Regularly review access logs

## Related Documents
- [Database Overview](./030-DATABASE-OVERVIEW.md)
- [Backup and Recovery](./037-BACKUP-RECOVERY.md)
- [Performance Tuning](./038-PERFORMANCE-TUNING.md)
- [Connection Pooling](./041-CONNECTION-POOLING.md)

## Version History
| Date | Version | Description |
|------|---------|-------------|
| 2025-06-20 | 1.0 | Initial version |
