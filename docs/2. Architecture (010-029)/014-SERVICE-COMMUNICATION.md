# Service Communication

## Overview

This document outlines the communication patterns and protocols used between services in the Global Remit system. It covers both synchronous and asynchronous communication mechanisms, service discovery, and message formats.

## Table of Contents
- [Communication Patterns](#communication-patterns)
- [Synchronous Communication](#synchronous-communication)
- [Asynchronous Communication](#asynchronous-communication)
- [Message Brokers](#message-brokers)
- [Service Discovery](#service-discovery)
- [Circuit Breakers](#circuit-breakers)
- [Retry Mechanisms](#retry-mechanisms)
- [Message Serialization](#message-serialization)
- [Error Handling](#error-handling)
- [Performance Considerations](#performance-considerations)
- [Security](#security)
- [Monitoring and Tracing](#monitoring-and-tracing)

## Communication Patterns

### 1. Synchronous (Request/Response)
- **Use Cases**:
  - Immediate response required
  - Simple CRUD operations
  - When strong consistency is needed
- **Protocols**:
  - HTTP/1.1, HTTP/2
  - gRPC

### 2. Asynchronous (Event-Based)
- **Use Cases**:
  - Long-running processes
  - Event notifications
  - Decoupled services
- **Patterns**:
  - Publish/Subscribe
  - Event Sourcing
  - CQRS (Command Query Responsibility Segregation)

## Synchronous Communication

### REST API
- **Base URL**: `https://api.globalremit.com/v1`
- **Authentication**: JWT Bearer Token
- **Content-Type**: `application/json`
- **Response Codes**:
  - 200: Success
  - 400: Bad Request
  - 401: Unauthorized
  - 403: Forbidden
  - 404: Not Found
  - 429: Too Many Requests
  - 500: Internal Server Error

### gRPC
- **Protocol**: HTTP/2
- **Authentication**: mTLS (mutual TLS)
- **Service Definition**:
  ```protobuf
  service UserService {
    rpc GetUser(GetUserRequest) returns (UserResponse);
    rpc CreateUser(CreateUserRequest) returns (UserResponse);
  }
  ```

### Service-to-Service Authentication
- **JWT Tokens** for service identity
- **mTLS** for transport security
- **API Keys** for external services

## Asynchronous Communication

### Message Brokers

#### RabbitMQ
- **Purpose**: Decoupled service communication
- **Exchange Types**:
  - Direct
  - Topic
  - Fanout
  - Headers
- **Message Durability**: Enabled
- **Delivery Mode**: Persistent

#### Kafka
- **Purpose**: Event streaming and processing
- **Topics**:
  - `transactions`
  - `notifications`
  - `audit_logs`
- **Partitions**: 3 (default)
- **Replication Factor**: 2

### Event Schema
```json
{
  "event_id": "uuid-v4",
  "event_type": "user.created",
  "timestamp": "2025-06-20T12:00:00Z",
  "source": "user-service",
  "version": "1.0",
  "data": {
    "user_id": "12345",
    "email": "user@example.com"
  },
  "metadata": {
    "correlation_id": "corr-12345",
    "trace_id": "trace-12345"
  }
}
```

## Service Discovery

### Consul
- **Service Registration**: Automatic
- **Health Checks**: HTTP, TCP, Script
- **Key-Value Store**: For configuration
- **DNS Interface**: For service lookup

### Kubernetes Service Discovery
- **DNS Naming**: `service-name.namespace.svc.cluster.local`
- **Environment Variables**: Automatic injection
- **Headless Services**: For direct pod access

## Circuit Breakers

### Implementation
- **Library**: Hystrix (Go)
- **Thresholds**:
  - Failure Threshold: 50%
  - Wait Duration: 10 seconds
  - Minimum Requests: 20

### Fallback Strategies
- **Cache**: Return cached data
- **Default**: Return default values
- **Error**: Fail fast with meaningful error

## Retry Mechanisms

### Exponential Backoff
- **Initial Delay**: 100ms
- **Max Delay**: 5s
- **Max Attempts**: 3
- **Jitter**: ±10%

### Idempotency
- **Idempotency Keys**: Required for all mutating operations
- **Time Window**: 24 hours
- **Storage**: Redis

## Message Serialization

### Formats
- **JSON**: For REST APIs
- **Protocol Buffers**: For gRPC
- **Avro**: For Kafka messages

### Schema Evolution
- **Backward Compatibility**: Required
- **Field Deprecation**: Mark as deprecated first
- **Required Fields**: Avoid adding new required fields

## Error Handling

### Retryable Errors
- 429 Too Many Requests
- 503 Service Unavailable
- Network timeouts
- Connection resets

### Non-Retryable Errors
- 400 Bad Request
- 401 Unauthorized
- 403 Forbidden
- 404 Not Found
- 422 Unprocessable Entity

### Dead Letter Queues
- **Purpose**: Store failed messages
- **Retry Policy**: 3 attempts
- **Alerting**: On message arrival

## Performance Considerations

### Connection Pooling
- **Max Idle Connections**: 100
- **Max Open Connections**: 1000
- **Connection Lifetime**: 5 minutes

### Timeouts
- **Connect Timeout**: 5s
- **Read Timeout**: 30s
- **Write Timeout**: 30s
- **Request Timeout**: 60s

### Compression
- **Threshold**: 1KB
- **Algorithms**:
  - gzip
  - deflate
  - snappy (for gRPC)

## Security

### Transport Security
- **TLS 1.3** for all external communication
- **mTLS** for service-to-service communication
- **Certificate Rotation**: Automatic (30-day validity)

### Message Security
- **Encryption**: AES-256-GCM
- **Signing**: Ed25519
- **Key Management**: HashiCorp Vault

### Rate Limiting
- **Per Service**: 1000 requests/second
- **Per Client**: 100 requests/minute
- **Burst**: 50 requests

## Monitoring and Tracing

### Metrics
- **Request Rate**: Requests per second
- **Error Rate**: Percentage of failed requests
- **Latency**: P50, P90, P99
- **Queue Depth**: For async operations

### Distributed Tracing
- **Tracer**: Jaeger
- **Sampling Rate**: 10%
- **Tags**:
  - service.name
  - http.method
  - http.status_code
  - error (true/false)

### Logging
- **Structured Logging**: JSON format
- **Correlation IDs**: For request tracing
- **Log Levels**:
  - DEBUG: Detailed debug information
  - INFO: Important business events
  - WARN: Unexpected but handled events
  - ERROR: Unhandled errors
  - FATAL: Critical failures

## Best Practices

1. **Prefer Asynchronous Communication** for non-critical paths
2. **Use Circuit Breakers** to prevent cascading failures
3. **Implement Retries** with exponential backoff
4. **Use Idempotent Operations** for reliability
5. **Monitor All Communication** for performance and errors
6. **Document All APIs** with OpenAPI/Swagger
7. **Version Your APIs** for backward compatibility
8. **Secure All Endpoints** with proper authentication/authorization

## Related Documents
- [System Components](011-SYSTEM-COMPONENTS.md)
- [Data Flow](012-DATA-FLOW.md)
- [API Gateway](013-API-GATEWAY.md)
- [Scalability](015-SCALABILITY.md)
- [Security Architecture](016-SECURITY-ARCHITECTURE.md)

---

*Last updated: June 20, 2025*
