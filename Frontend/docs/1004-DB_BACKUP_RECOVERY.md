# Database Backup and Recovery Strategy

## 1. Overview

This document outlines the strategy for backing up and recovering the Global Remit Teller database. It covers both automated and manual procedures to ensure data integrity and availability.

## 2. Backup Strategy

### 2.1 Backup Types

#### 2.1.1 Full Backups
- **Frequency**: Daily
- **Retention**: 7 days
- **Location**: Off-site and on-premises
- **Format**: Compressed SQL dump

#### 2.1.2 Incremental Backups
- **Frequency**: Hourly
- **Retention**: 24 hours
- **Location**: On-premises
- **Format**: WAL (Write-Ahead Logs)

#### 2.1.3 Logical Backups
- **Frequency**: Weekly
- **Retention**: 4 weeks
- **Location**: Off-site
- **Format**: Plain SQL

### 2.2 Backup Schedule

```
┌───────────┬─────────────┬─────────────┬─────────────┐
│ Time      │ Monday      │ Wednesday   │ Friday      │
├───────────┼─────────────┼─────────────┼─────────────┤
│ 00:00     │ Full Backup │ Full Backup │ Full Backup │
│ 04:00     │ Incremental │ Incremental │ Incremental │
│ 08:00     │ Incremental │ Incremental │ Incremental │
│ ...       │ ...         │ ...         │ ...         │
│ 20:00     │ Incremental │ Incremental │ Incremental │
└───────────┴─────────────┴─────────────┴─────────────┘
```

## 3. Backup Procedures

### 3.1 Automated Backups

#### 3.1.1 Using pg_dump
```bash
# Daily full backup
pg_dump -h localhost -U postgres -Fc -f /backups/daily/db_$(date +%Y%m%d).backup global_remit

# Weekly logical backup
pg_dump -h localhost -U postgres -Fp -f /backups/weekly/db_$(date +%Y%m%d).sql global_remit
```

#### 3.1.2 WAL Archiving
```ini
# postgresql.conf
wal_level = replica
archive_mode = on
archive_command = 'test ! -f /backups/wal_archive/%f && cp %p /backups/wal_archive/%f'
```

### 3.2 Manual Backups

#### 3.2.1 Single Table Backup
```bash
pg_dump -h localhost -U postgres -t transactions -f /backups/tables/transactions_$(date +%Y%m%d).sql global_remit
```

#### 3.2.2 Schema-Only Backup
```bash
pg_dump -h localhost -U postgres -s -f /backups/schema/schema_$(date +%Y%m%d).sql global_remit
```

## 4. Recovery Procedures

### 4.1 Point-in-Time Recovery (PITR)

#### 4.1.1 Recovery Configuration
```ini
# postgresql.conf
restore_command = 'cp /backups/wal_archive/%f %p'
recovery_target_time = '2025-06-20 14:30:00+03:00'
```

#### 4.1.2 Recovery Steps
1. Restore the most recent base backup
2. Create recovery.conf with restore_command
3. Create recovery.signal file
4. Start PostgreSQL

### 4.2 Full Database Restore

#### 4.2.1 From Custom Format
```bash
pg_restore -h localhost -U postgres -d global_remit /backups/daily/db_20250620.backup
```

#### 4.2.2 From Plain SQL
```bash
psql -h localhost -U postgres -d global_remit -f /backups/weekly/db_20250620.sql
```

## 5. Backup Verification

### 5.1 Automated Verification
```bash
# Verify backup integrity
pg_restore -l /backups/daily/db_20250620.backup > /dev/null && echo "Backup is valid"

# Check backup size
ls -lh /backups/daily/db_20250620.backup
```

### 5.2 Manual Verification
1. Restore to a test environment
2. Run integrity checks
3. Verify critical data
4. Document verification results

## 6. Retention Policy

### 6.1 Backup Retention
- Daily backups: 7 days
- Weekly backups: 4 weeks
- Monthly backups: 12 months
- Yearly backups: 7 years

### 6.2 Cleanup Procedure
```bash
# Remove backups older than 7 days
find /backups/daily -type f -mtime +7 -delete

# Remove WAL archives older than 24 hours
find /backups/wal_archive -type f -mtime +1 -delete
```

## 7. High Availability

### 7.1 Replication
- Primary-standby setup
- Synchronous replication
- Automatic failover

### 7.2 Failover Procedure
1. Detect primary failure
2. Promote standby
3. Update connection strings
4. Notify team

## 8. Disaster Recovery

### 8.1 Recovery Time Objective (RTO)
- Critical systems: < 1 hour
- Non-critical systems: < 4 hours

### 8.2 Recovery Point Objective (RPO)
- Critical data: < 5 minutes
- Non-critical data: < 1 hour

## 9. Monitoring and Alerts

### 9.1 Backup Monitoring
- Successful completion
- Backup size
- Duration
- Storage usage

### 9.2 Alerting
- Failed backups
- Backup duration too long
- Storage threshold exceeded
- Verification failures

## 10. Security

### 10.1 Encryption
- At rest: AES-256
- In transit: TLS 1.3
- Backup encryption: GPG

### 10.2 Access Control
- Principle of least privilege
- Role-based access
- Audit logging

## 11. Documentation

### 11.1 Runbooks
- Backup procedures
- Recovery procedures
- Troubleshooting guides

### 11.2 Contact Information
- Primary DBA
- Secondary contact
- Escalation path

## 12. Testing

### 12.1 Recovery Testing
- Quarterly recovery tests
- Document results
- Update procedures

### 12.2 Performance Testing
- Backup/restore times
- Impact on production
- Resource utilization

## 13. Appendices

### 13.1 Glossary
- WAL: Write-Ahead Log
- PITR: Point-in-Time Recovery
- RPO: Recovery Point Objective
- RTO: Recovery Time Objective

### 13.2 References
- PostgreSQL Documentation
- Internal Security Policies
- Compliance Requirements
