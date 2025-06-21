# Database Connection Pooling Guide

## Introduction
This document outlines the connection pooling strategy for the Global Remit application. Connection pooling is essential for managing database connections efficiently, reducing overhead, and improving application performance.

## Table of Contents
- [Connection Pooling Overview](#connection-pooling-overview)
- [PgBouncer Configuration](#pgbouncer-configuration)
- [Application-Level Pooling](#application-level-pooling)
- [Connection Pool Sizing](#connection-pool-sizing)
- [Monitoring and Maintenance](#monitoring-and-maintenance)
- [High Availability](#high-availability)
- [Troubleshooting](#troubleshooting)
- [Related Documents](#related-documents)
- [Version History](#version-history)

## Connection Pooling Overview

### What is Connection Pooling?
Connection pooling is a technique where a pool of database connections is maintained so that the connections can be reused when future requests to the database are required.

### Benefits
- **Reduced Connection Overhead**: Eliminates the cost of creating new connections
- **Improved Performance**: Reuses existing connections instead of creating new ones
- **Resource Management**: Controls the number of connections to the database
- **Better Scalability**: Handles more concurrent users with fewer database connections

### Connection Pooling Options

| Type | Description | When to Use |
|------|-------------|-------------|
| **PgBouncer** | Lightweight connection pooler for PostgreSQL | Recommended for most PostgreSQL deployments |
| **Pgpool-II** | More feature-rich but more complex | Advanced replication and load balancing |
| **Application-Level** | Built into ORMs and database drivers | Simple applications with low concurrency |
| **Cloud Provider** | Managed services like AWS RDS Proxy | When using managed database services |

## PgBouncer Configuration

### Installation

#### Ubuntu/Debian
```bash
sudo apt-get update
sudo apt-get install pgbouncer
```

#### RHEL/CentOS
```bash
sudo yum install pgbouncer
```

#### Docker
```bash
docker run -d --name pgbouncer \
  -e DATABASE_URL="postgresql://user:password@host:5432/dbname" \
  -p 6432:6432 \
  edoburu/pgbouncer
```

### Configuration File (pgbouncer.ini)

```ini
[databases]
# Format: dbname = host=hostname port=5432 dbname=actualdbname user=username
* = host=localhost port=5432 dbname=global_remit

[pgbouncer]
; General settings
listen_addr = *
listen_port = 6432
unix_socket_dir = /var/run/postgresql

; Authentication
auth_type = md5
auth_file = /etc/pgbouncer/userlist.txt

; Pool modes: session, transaction, statement
pool_mode = transaction

; Connection limits
max_client_conn = 1000
default_pool_size = 20
reserve_pool_size = 5
max_db_connections = 100
server_reset_query = DISCARD ALL

; Timeouts
server_lifetime = 3600
server_idle_timeout = 600
server_connect_timeout = 15
server_login_retry = 2
client_login_timeout = 15

; Logging
log_connections = 1
log_disconnections = 1
log_pooler_errors = 1
stats_period = 60

; Security
admin_users = postgres
stats_users = stats, monitor

; TLS/SSL
;ssl = 0
;sslmode = disable
;ssl_cert_file = /path/to/server.crt
;ssl_key_file = /path/to/server.key
;ssl_ca_file = /path/to/ca.crt
```

### User Authentication

#### Create userlist.txt
```bash
# Format: "username" "password" (password can be plain text or md5 hash)
"postgres" "md5d7d880f96044b72d0bba108ace96d1e4"
"app_user" "md5239f2b9219814f7b45f7a1d86f32a9e3"
```

To generate an MD5 hash:
```bash
echo -n "yourpasswordusername" | md5sum
```

### Starting and Managing PgBouncer

#### Start/Stop/Restart
```bash
# Systemd
sudo systemctl start pgbouncer
sudo systemctl stop pgbouncer
sudo systemctl restart pgbouncer
sudo systemctl status pgbouncer

# Check logs
sudo journalctl -u pgbouncer -f
```

#### Admin Console
```bash
# Connect to admin console
psql -p 6432 -U postgres pgbouncer

# Show help
\help

# Show stats
SHOW STATS;
SHOW POOLS;
SHOW CLIENTS;
SHOW SERVERS;
SHOW CONFIG;

# Reload configuration
RELOAD;

# Pause/Resume
PAUSE;
RESUME;
```

## Application-Level Pooling

### Node.js (with pg-pool)

```javascript
const { Pool } = require('pg');

const pool = new Pool({
  user: 'app_user',
  host: 'localhost',
  database: 'global_remit',
  password: 'yourpassword',
  port: 6432,  // PgBouncer port
  max: 20,     // max number of clients in the pool
  idleTimeoutMillis: 30000,
  connectionTimeoutMillis: 2000,
});

// Example query
async function getAccount(accountId) {
  const client = await pool.connect();
  try {
    const res = await client.query('SELECT * FROM accounts WHERE id = $1', [accountId]);
    return res.rows[0];
  } finally {
    client.release();
  }
}
```

### Python (with psycopg2 and psycopg2.pool)

```python
from psycopg2 import pool

# Create a connection pool
connection_pool = pool.SimpleConnectionPool(
    minconn=1,
    maxconn=10,
    host="localhost",
    port=6432,  # PgBouncer port
    database="global_remit",
    user="app_user",
    password="yourpassword"
)

# Get a connection from the pool
def get_account(account_id):
    conn = connection_pool.getconn()
    try:
        with conn.cursor() as cur:
            cur.execute("SELECT * FROM accounts WHERE id = %s", (account_id,))
            return cur.fetchone()
    finally:
        connection_pool.putconn(conn)
```

## Connection Pool Sizing

### General Guidelines

| Application Type | Recommended Pool Size | Notes |
|-----------------|----------------------|-------|
| Web Application | `(2 * num_cores) + effective_spindle_count` | Good starting point |
| Background Job | `num_cores + 1` | For CPU-bound workloads |
| Batch Processing | `(num_cores / 2) + 1` | For I/O-bound workloads |
| Microservices | `min(20, num_cores * 2)` | For containerized services |

### Formula
```
max_connections = ((core_count * 2) + effective_spindle_count)
```

Where:
- `core_count` = Number of CPU cores
- `effective_spindle_count` = 1 for SSD, 0.1 * number of spindles for HDD

### Example Calculations

#### 16-core server with SSD:
```
(16 * 2) + 1 = 33 connections
```

#### 8-core server with HDD (2 spindles):
```
(8 * 2) + (0.1 * 2) ≈ 16 connections
```

### Adjusting Based on Workload
- **Read-heavy**: Increase pool size
- **Write-heavy**: Smaller pools may be better
- **Mixed workload**: Start with the formula and adjust based on monitoring

## Monitoring and Maintenance

### Key Metrics to Monitor

| Metric | Description | Warning Threshold |
|--------|-------------|-------------------|
| Active Connections | Currently active connections | > 80% of max_connections |
| Idle Connections | Connections in pool not in use | Monitor for leaks |
| Wait Events | Clients waiting for a connection | > 0 indicates pool saturation |
| Query Duration | Average query execution time | Varies by query |
| Connection Errors | Failed connection attempts | > 0 should be investigated |

### PgBouncer Admin Commands

```sql
-- Show pool statistics
SHOW POOLS;

-- Show client connections
SHOW CLIENTS;

-- Show server connections
SHOW SERVERS;

-- Show active queries
SHOW ACTIVE_SOCKETS;

-- Show stats
SHOW STATS;
SHOW STATS_TOTALS;
SHOW STATS_AVERAGES;

-- Show memory usage
SHOW MEM;
```

### Log Analysis

#### Enable Detailed Logging
```ini
; In pgbouncer.ini
log_connections = 1
log_disconnections = 1
log_pooler_errors = 1
log_stats = 1
stats_period = 60
```

#### Common Log Patterns
```
# Connection issues
LOG C-0x1a2b3c4d: app_user@[local] db=global_remit user=app_user NO SERVER AVAILABLE

# Authentication failures
LOG S-0x1a2b3c4d: app_user@[local] db=global_remit user=app_user closing because: auth failed

# Timeouts
LOG C-0x1a2b3c4d: app_user@[local] db=global_remit user=app_user closing because: client close request
```

## High Availability

### PgBouncer with Keepalived

#### Install Keepalived
```bash
# On Ubuntu/Debian
sudo apt-get install keepalived

# On RHEL/CentOS
sudo yum install keepalived
```

#### Keepalived Configuration (/etc/keepalived/keepalived.conf)
```
vrrp_script chk_pgbouncer {
    script "pidof pgbouncer"
    interval 2
    weight 2
}

vrrp_instance VI_1 {
    state MASTER  # Use BACKUP on secondary server
    interface eth0
    virtual_router_id 51
    priority 100  # Higher priority on primary
    
    authentication {
        auth_type PASS
        auth_pass your_secure_password
    }
    
    track_script {
        chk_pgbouncer
    }
    
    virtual_ipaddress {
        192.168.1.100/24 dev eth0  # Virtual IP address
    }
}
```

#### Start Keepalived
```bash
sudo systemctl start keepalived
sudo systemctl enable keepalived
```

## Troubleshooting

### Common Issues and Solutions

#### 1. Too Many Connections
**Symptom**: `FATAL: sorry, too many clients already`
**Solution**:
- Increase `max_connections` in PostgreSQL
- Reduce `max_client_conn` in PgBouncer
- Check for connection leaks in application code

#### 2. Connection Timeouts
**Symptom**: `timeout expired` or `connection timed out`
**Solution**:
- Increase `server_connect_timeout` in PgBouncer
- Check network connectivity
- Verify PostgreSQL is running and accepting connections

#### 3. Authentication Failures
**Symptom**: `password authentication failed for user`
**Solution**:
- Verify `userlist.txt` matches PostgreSQL users
- Check password hashes
- Ensure PgBouncer is using the correct auth_type

#### 4. Performance Issues
**Symptom**: Slow query performance with PgBouncer
**Solution**:
- Check `pool_mode` (transaction is usually best)
- Increase `default_pool_size` if needed
- Monitor with `SHOW STATS` and `SHOW POOLS`

#### 5. Prepared Statement Errors
**Symptom**: `prepared statement "__prepstmt_1" already exists`
**Solution**:
- Set `pool_mode = session` if using prepared statements
- Or disable prepared statements in your application
- Or use `server_reset_query = DISCARD ALL`

## Related Documents
- [Database Overview](./030-DATABASE-OVERVIEW.md)
- [Performance Tuning](./039-PERFORMANCE-TUNING.md)
- [Query Optimization](./041-QUERY-OPTIMIZATION.md)
- [Backup and Recovery](./038-BACKUP-RECOVERY.md)

## Version History
| Date | Version | Description |
|------|---------|-------------|
| 2025-06-20 | 1.0 | Initial version |
