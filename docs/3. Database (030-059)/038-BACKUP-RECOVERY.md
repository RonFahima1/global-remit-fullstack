# Database Backup and Recovery Guide

## Introduction
This document outlines the backup and recovery strategy for the Global Remit database. It ensures data integrity, availability, and quick recovery in case of data loss or corruption.

## Table of Contents
- [Backup Strategy](#backup-strategy)
- [Recovery Procedures](#recovery-procedures)
- [Backup Types](#backup-types)
- [Automated Backup System](#automated-backup-system)
- [Disaster Recovery](#disaster-recovery)
- [Testing and Validation](#testing-and-validation)
- [Monitoring and Alerting](#monitoring-and-alerting)
- [Related Documents](#related-documents)
- [Version History](#version-history)

## Backup Strategy

### 1. Backup Types and Retention

| Backup Type | Frequency | Retention | Storage Location |
|-------------|-----------|-----------|------------------|
| Full Backup | Daily | 7 days | On-premises NAS |
| WAL Archiving | Continuous | 14 days | AWS S3 |
| Transaction Logs | Every 15 min | 3 days | AWS S3 |
| Monthly Full | 1st of month | 1 year | AWS S3 Glacier |
| Yearly Full | Jan 1st | 7 years | AWS S3 Glacier Deep Archive |

### 2. Backup Locations
- **Primary**: On-premises NAS for quick recovery
- **Secondary**: AWS S3 for geographic redundancy
- **Archive**: AWS S3 Glacier for long-term retention

### 3. Backup Encryption
- All backups are encrypted using AES-256
- Encryption keys are managed via AWS KMS
- Separate keys for different environments (prod/staging/dev)

## Recovery Procedures

### 1. Point-in-Time Recovery (PITR)

#### Prerequisites
- Base backup
- WAL (Write-Ahead Log) files
- Recovery target time or transaction ID

#### Recovery Steps
1. Identify the recovery target time:
   ```bash
   # Find the last known good state
   psql -c "SELECT pg_walfile_name(pg_current_wal_lsn()) AS current_wal_file;"
   ```

2. Create recovery configuration:
   ```ini
   # $PGDATA/recovery.conf
   restore_command = 'aws s3 cp s3://global-remit-backups/wal/%f %p'
   recovery_target_time = '2025-06-20 15:00:00+03'
   recovery_target_timeline = 'latest'
   recovery_target_action = 'promote'
   ```

3. Start the recovery process:
   ```bash
   # Stop PostgreSQL if running
   systemctl stop postgresql
   
   # Remove any existing data directory contents
   rm -rf $PGDATA/*
   
   # Restore the base backup
   pg_basebackup -h backup-server -D $PGDATA -U replicator -v -P --wal-method=stream
   
   # Configure recovery
   echo "restore_command = 'aws s3 cp s3://global-remit-backups/wal/%f %p'" > $PGDATA/recovery.conf
   
   # Start PostgreSQL
   systemctl start postgresql
   ```

### 2. Full Database Restore

#### Using pg_dump/pg_restore
```bash
# Create a compressed backup
pg_dump -Fc -d global_remit_prod -f /backups/global_remit_prod_$(date +%Y%m%d).dump

# Restore to a new database
pg_restore -d global_remit_restore /backups/global_remit_prod_20250620.dump

# Restore specific schemas
pg_restore -d global_remit_restore --schema=core --schema=auth /backups/global_remit_prod_20250620.dump
```

#### Using Barman (for PostgreSQL)
```bash
# List available backups
barman list-backup main

# Recover to a specific point in time
barman recover \
    --target-time "2025-06-20 15:00:00+03" \
    --remote-ssh-command "ssh postgres@restore-server" \
    main \
    latest \
    /var/lib/postgresql/14/main/
```

## Backup Types

### 1. Logical Backups
- **Tool**: `pg_dump`/`pg_dumpall`
- **Advantages**: Portable, selective restore, version-independent
- **Use Case**: Schema changes, selective data restore

### 2. Physical Backups
- **Tool**: `pg_basebackup`, Barman
- **Advantages**: Faster, consistent, includes all databases
- **Use Case**: Full database recovery, point-in-time recovery

### 3. Continuous Archiving
- **Tool**: WAL archiving
- **Advantages**: Minimal data loss, point-in-time recovery
- **Use Case**: Disaster recovery, zero data loss requirements

## Automated Backup System

### 1. Backup Script
```bash
#!/bin/bash
# /usr/local/bin/backup-db.sh

# Configuration
BACKUP_DIR="/backups/$(date +%Y%m%d)" 
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
DB_NAME="global_remit_prod"
S3_BUCKET="s3://global-remit-backups"
RETENTION_DAYS=7

# Create backup directory
mkdir -p "$BACKUP_DIR"

# Create backup
pg_dump -Fc "$DB_NAME" > "$BACKUP_DIR/${DB_NAME}_${TIMESTAMP}.dump"

# Upload to S3
aws s3 cp --recursive "$BACKUP_DIR" "$S3_BUCKET/$(date +%Y%m%d)/"

# Clean up old backups
find /backups -type d -mtime +$RETENTION_DAYS -exec rm -rf {} \;
aws s3 rm --recursive "$S3_BUCKET/$(date -d "$RETENTION_DAYS days ago" +%Y%m%d)/"

# Verify backup
if [ -s "$BACKUP_DIR/${DB_NAME}_${TIMESTAMP}.dump" ]; then
    echo "Backup completed successfully"
    exit 0
else
    echo "Backup failed"
    exit 1
fi
```

### 2. Systemd Service
```ini
# /etc/systemd/system/backup-db.service
[Unit]
Description=Database Backup Service
After=postgresql.service

[Service]
Type=oneshot
User=postgres
ExecStart=/usr/local/bin/backup-db.sh
```

### 3. Systemd Timer
```ini
# /etc/systemd/system/backup-db.timer
[Unit]
Description=Run database backup daily

[Timer]
OnCalendar=daily
Persistent=true
RandomizedDelaySec=1h

[Install]
WantedBy=timers.target
```

## Disaster Recovery

### 1. Recovery Time Objective (RTO) and Recovery Point Objective (RPO)
- **RTO**: 2 hours for full recovery
- **RPO**: 5 minutes of data loss maximum

### 2. Recovery Procedures

#### Complete Data Center Failure
1. Launch new database instances in secondary region
2. Restore latest backup from S3
3. Configure WAL archiving for point-in-time recovery
4. Update DNS to point to new database servers

#### Data Corruption
1. Identify affected tables
2. Restore from most recent backup
3. Apply WAL logs to recover to point of failure
4. Verify data consistency

## Testing and Validation

### 1. Backup Verification
```bash
# Verify backup integrity
pg_restore --list /backups/global_remit_prod_20250620.dump

# Test restore to a temporary database
createdb verify_restore
pg_restore -d verify_restore /backups/global_remit_prod_20250620.dump

# Run data validation queries
psql -d verify_restore -c "SELECT count(*) FROM transactions;"
```

### 2. Recovery Drills
- Monthly recovery tests
- Document recovery time and any issues
- Update procedures based on findings

## Monitoring and Alerting

### 1. Backup Monitoring
- Monitor backup success/failure
- Alert if backup is older than 24 hours
- Verify backup size is within expected range

### 2. Disk Space Monitoring
- Monitor disk space on backup servers
- Alert if free space is below 20%
- Implement automatic cleanup of old backups

### 3. Log Monitoring
- Monitor PostgreSQL logs for backup-related errors
- Alert on WAL archiving failures
- Track backup performance metrics

## Related Documents
- [Database Overview](./030-DATABASE-OVERVIEW.md)
- [Schema Design Overview](./031-SCHEMA-DESIGN-OVERVIEW.md)
- [Partitioning Strategy](./035-PARTITIONING-STRATEGY.md)
- [Migrations Guide](./036-MIGRATIONS-GUIDE.md)
- [Seed Data Guide](./037-SEED-DATA.md)

## Version History
| Date | Version | Description |
|------|---------|-------------|
| 2025-06-20 | 1.0 | Initial version |
