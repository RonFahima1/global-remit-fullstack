# Redis Integration Strategy

## Table of Contents
1. [Overview](#overview)
2. [Caching Strategy](#caching-strategy)
   - [Cache Invalidation](#cache-invalidation)
   - [Cache Key Naming](#cache-key-naming)
   - [TTL Configuration](#ttl-configuration)
   - [Cache-Aside Pattern](#cache-aside-pattern)
3. [Rate Limiting](#rate-limiting)
   - [Rate Limiting Tiers](#rate-limiting-tiers)
   - [Implementation](#implementation)
   - [Response Headers](#response-headers)
4. [Session Management](#session-management)
   - [Session Storage](#session-storage)
   - [Session Expiration](#session-expiration)
   - [Distributed Sessions](#distributed-sessions)
5. [Message Queue](#message-queue)
   - [Job Types](#job-types)
   - [Priority Queues](#priority-queues)
   - [Retry Mechanism](#retry-mechanism)
   - [Dead Letter Queue](#dead-letter-queue)
6. [Redis Configuration](#redis-configuration)
7. [Monitoring and Maintenance](#monitoring-and-maintenance)
8. [Security Considerations](#security-considerations)
9. [Performance Optimization](#performance-optimization)
10. [Disaster Recovery](#disaster-recovery)
11. [Implementation Roadmap](#implementation-roadmap)

## Overview

Redis will be used as a multi-purpose in-memory data store to enhance the performance, scalability, and reliability of the Global Remit application. This document outlines the strategies for using Redis for:

- **Caching** frequently accessed data to reduce database load
- **Rate limiting** to protect API endpoints from abuse
- **Session storage** for user authentication state
- **Message queuing** for background job processing

## Caching Strategy

### Cache Invalidation

We'll implement a hybrid cache invalidation strategy:

1. **Time-based expiration (TTL)**
   - Default TTL: 5 minutes for most cached items
   - Shorter TTL (1 minute) for rapidly changing data (e.g., exchange rates)
   - Longer TTL (1 hour) for relatively static data (e.g., country lists)

2. **Event-based invalidation**
   - Invalidate cache entries when underlying data changes
   - Use Redis Pub/Sub to notify all instances of data changes
   - Example: When a client's KYC status is updated, invalidate the cached client data

3. **Pattern-based invalidation**
   - Invalidate groups of related cache keys using patterns
   - Example: `client:123:*` to invalidate all cache entries for a specific client

### Cache Key Naming

Use a consistent naming convention for cache keys:

```
{namespace}:{entity}:{id}[:{sub-entity}]:{suffix}
```

Examples:
- `client:profile:123` - Cached client profile
- `account:balance:456` - Cached account balance
- `exchange:rate:USD:EUR` - Cached exchange rate
- `client:transactions:123:recent` - Recent transactions for client 123

### TTL Configuration

| Data Type | TTL | Notes |
|-----------|-----|-------|
| Client Profile | 5 minutes | Invalidate on profile update |
| Account Balance | 30 seconds | Critical data, short TTL |
| Exchange Rates | 1 minute | External data, frequent updates |
| Country/Currency Lists | 1 hour | Rarely changes |
| Transaction History | 5 minutes | Stale data acceptable |
| Compliance Data | 15 minutes | Regulatory data, moderate TTL |

### Cache-Aside Pattern

Implement the cache-aside (lazy loading) pattern:

1. Application checks the cache first
2. If cache hit, return cached data
3. If cache miss, fetch from database
4. Store in cache before returning
5. Set appropriate TTL

```typescript
async function getClientProfile(clientId: string) {
  const cacheKey = `client:profile:${clientId}`;
  
  // Try to get from cache
  const cachedData = await redis.get(cacheKey);
  if (cachedData) {
    return JSON.parse(cachedData);
  }
  
  // If not in cache, get from database
  const dbData = await db.clients.findById(clientId);
  
  if (dbData) {
    // Store in cache for future requests
    await redis.setex(cacheKey, 300, JSON.stringify(dbData)); // 5 minutes TTL
  }
  
  return dbData;
}
```

## Rate Limiting

### Rate Limiting Tiers

Implement tiered rate limiting based on user roles and endpoints:

| Tier | Requests/Minute | Notes |
|------|----------------|-------|
| Unauthenticated | 60 | Public endpoints only |
| Basic Teller | 300 | Standard teller operations |
| Senior Teller | 600 | Higher limit for senior staff |
| Manager | 1000 | Administrative operations |
| System | 5000 | Internal service-to-service |

### Implementation

Use Redis to implement sliding window rate limiting:

```typescript
async function isRateLimited(userId: string, endpoint: string, limit: number, windowMs: number): Promise<boolean> {
  const key = `rate_limit:${userId}:${endpoint}`;
  const now = Date.now();
  const windowStart = now - windowMs;
  
  // Add current timestamp to sorted set
  await redis.zadd(key, now.toString(), now.toString());
  
  // Remove timestamps outside the current window
  await redis.zremrangebyscore(key, 0, windowStart);
  
  // Get count of requests in current window
  const requestCount = await redis.zcard(key);
  
  // Set expiry on the key
  await redis.expire(key, Math.ceil(windowMs / 1000));
  
  return requestCount > limit;
}
```

### Response Headers

Include rate limit information in response headers:

```
X-RateLimit-Limit: 300
X-RateLimit-Remaining: 254
X-RateLimit-Reset: 1624123456
Retry-After: 10  // When rate limited
```

## Session Management

### Session Storage

Store session data in Redis with the following structure:

```typescript
interface SessionData {
  userId: string;
  role: string;
  branchId?: string;
  permissions: string[];
  lastActivity: number;
  userAgent: string;
  ipAddress: string;
  expiresAt: number;
  // Additional metadata
}
```

### Session Expiration

- **Idle Timeout**: 30 minutes of inactivity
- **Absolute Timeout**: 8 hours maximum session duration
- **Remember Me**: Extend to 7 days if "Remember Me" is checked

### Distributed Sessions

1. Use Redis as a shared session store
2. Generate secure session IDs using UUID v4
3. Store minimal data in the session cookie
4. Encrypt sensitive session data

```typescript
// Session middleware configuration
app.use(session({
  store: new RedisStore({ client: redisClient }),
  secret: process.env.SESSION_SECRET,
  resave: false,
  saveUninitialized: false,
  cookie: {
    secure: process.env.NODE_ENV === 'production',
    httpOnly: true,
    maxAge: 30 * 60 * 1000, // 30 minutes
    sameSite: 'lax',
  },
  name: 'sid',
  genid: () => uuidv4(),
}));
```

## Message Queue

### Job Types

| Priority | Job Type | Description | Retry Policy |
|----------|----------|-------------|--------------|
| High | Transaction Processing | Process financial transactions | 3 retries, exponential backoff |
| High | Notification | Send transaction notifications | 3 retries, fixed delay |
| Medium | Compliance Check | Run AML/KYC checks | 2 retries |
| Low | Reporting | Generate reports | 1 retry |
| Low | Data Sync | Sync with external systems | 2 retries |

### Priority Queues

Implement priority queues using Redis Sorted Sets:

```
high_priority - Sorted set for high priority jobs
medium_priority - Sorted set for medium priority jobs
low_priority - Sorted set for low priority jobs
```

### Retry Mechanism

1. Track retry count in job data
2. Use exponential backoff for retries
3. Move to dead letter queue after max retries

```typescript
interface JobData {
  id: string;
  type: string;
  payload: any;
  retryCount: number;
  maxRetries: number;
  createdAt: number;
  nextRetryAt?: number;
  lastError?: string;
}

async function processJob(jobData: JobData) {
  try {
    // Process the job
    await processJobPayload(jobData);
    
    // If successful, remove from processing queue
    await removeFromProcessingQueue(jobData.id);
  } catch (error) {
    if (jobData.retryCount >= jobData.maxRetries) {
      // Move to dead letter queue
      await moveToDeadLetterQueue(jobData, error);
    } else {
      // Schedule retry with exponential backoff
      const backoff = Math.min(
        1000 * 60 * 10, // 10 minutes max
        Math.pow(2, jobData.retryCount) * 1000 // Exponential backoff
      );
      
      jobData.retryCount++;
      jobData.nextRetryAt = Date.now() + backoff;
      jobData.lastError = error.message;
      
      await scheduleRetry(jobData);
    }
  }
}
```

### Dead Letter Queue

1. Store failed jobs after max retries
2. Include error details and timestamps
3. Provide admin interface for inspection
4. Allow manual retry or deletion

## Redis Configuration

### Recommended Configuration

```conf
# Memory management
maxmemory 4gb
maxmemory-policy allkeys-lru
maxmemory-samples 5

# Persistence
appendonly yes
appendfsync everysec
save 900 1
save 300 10
save 60 10000

# Networking
tcp-keepalive 60
tcp-backlog 511
timeout 0

# Security
requirepass your_secure_password
rename-command FLUSHDB ""
rename-command FLUSHALL ""

# Performance
tcp-keepalive 300
hz 10
```

### High Availability

1. **Redis Sentinel** for automatic failover
2. **Redis Cluster** for horizontal scaling
3. **Read Replicas** for read-heavy workloads

## Monitoring and Maintenance

### Key Metrics to Monitor

1. **Memory Usage**
   - Used memory
   - Memory fragmentation ratio
   - Evicted keys

2. **Performance**
   - Commands processed per second
   - Latency percentiles
   - Hit/miss ratio

3. **Clients**
   - Connected clients
   - Blocked clients
   - Rejected connections

4. **Persistence**
   - Last save time
   - AOF file size
   - RDB save status

### Alerting

Set up alerts for:
- Memory usage > 80%
- CPU usage > 70%
- Replication lag > 5s
- Failed commands > 100/min
- Hit rate < 90%
- Connected clients near limit

## Security Considerations

1. **Network Security**
   - Use TLS for all Redis traffic
   - Restrict access to Redis ports
   - Use VPC peering or private networking

2. **Authentication**
   - Require password authentication
   - Use ACLs for fine-grained access control
   - Rotate passwords regularly

3. **Data Protection**
   - Encrypt sensitive data before storing in Redis
   - Don't store PII in session data
   - Use Redis 6+ with TLS 1.3

4. **Hardening**
   - Disable dangerous commands (FLUSHDB, FLUSHALL, DEBUG)
   - Run Redis as non-root user
   - Enable protected mode

## Performance Optimization

1. **Pipelining**
   - Batch multiple commands in a single network roundtrip
   - Use for non-dependent operations

2. **Lua Scripting**
   - Reduce network overhead for complex operations
   - Ensure scripts are short and efficient

3. **Connection Pooling**
   - Reuse connections instead of creating new ones
   - Configure appropriate pool size

4. **Memory Optimization**
   - Use appropriate data structures
   - Enable compression for large values
   - Monitor and optimize memory usage

## Disaster Recovery

1. **Backup Strategy**
   - Daily RDB snapshots
   - Hourly AOF rewrites
   - Off-site backups

2. **Recovery Process**
   - Documented recovery procedures
   - Regular recovery testing
   - Failover testing

3. **Monitoring**
   - Replication status
   - Backup completion
   - Disk space for persistence files

## Implementation Roadmap

1. **Phase 1: Basic Caching**
   - Implement cache-aside pattern for read-heavy endpoints
   - Set up Redis configuration
   - Add cache invalidation

2. **Phase 2: Session Management**
   - Move sessions to Redis
   - Implement distributed session handling
   - Add session security measures

3. **Phase 3: Rate Limiting**
   - Implement sliding window rate limiting
   - Add response headers
   - Configure rate limiting tiers

4. **Phase 4: Message Queue**
   - Set up priority queues
   - Implement job processing
   - Add dead letter queue handling

5. **Phase 5: Monitoring and Optimization**
   - Set up monitoring
   - Implement alerts
   - Performance tuning

## Related Documents
- [Database Overview](../3. Database (030-059)/030-DATABASE-OVERVIEW.md)
- [Performance Tuning](../3. Database (030-059)/038-PERFORMANCE-TUNING.md)
- [Connection Pooling](../3. Database (030-059)/041-CONNECTION-POOLING.md)

## Version History
| Date | Version | Description |
|------|---------|-------------|
| 2025-06-20 | 1.0 | Initial version |
