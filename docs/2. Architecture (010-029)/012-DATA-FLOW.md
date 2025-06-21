# Data Flow Architecture

## Overview
This document outlines how data moves through the Global Remit system, including request/response flows, event propagation, and data synchronization between services.

## Request/Response Flow

### 1. Client Authentication
```mermaid
sequenceDiagram
    participant C as Client
    participant AG as API Gateway
    participant AS as Auth Service
    participant R as Redis
    
    C->>AG: POST /auth/login
    AG->>AS: Forward request
    AS->>AS: Validate credentials
    AS->>R: Store session
    AS-->>AG: Return JWT
    AG-->>C: Return JWT + User Info
```

### 2. Client Profile View
```mermaid
sequenceDiagram
    participant C as Client
    participant AG as API Gateway
    participant AS as Auth Service
    participant CS as Client Service
    participant DB as PostgreSQL
    
    C->>AG: GET /clients/{id}
    AG->>AS: Validate JWT
    AS-->>AG: Token valid
    AG->>CS: Forward request
    CS->>DB: Query client data
    DB-->>CS: Return client data
    CS->>CS: Format response
    CS-->>AG: Return client data
    AG-->>C: Return client data
```

## Event-Driven Flows

### 1. Money Transfer
```mermaid
sequenceDiagram
    participant C as Client
    participant AG as API Gateway
    participant TS as Transaction Service
    participant MQ as Message Queue
    participant AS as Account Service
    participant NS as Notification Service
    
    C->>AG: POST /transfers
    AG->>TS: Forward request
    TS->>TS: Validate transaction
    TS->>MQ: Publish "transfer.initiated"
    TS-->>AG: 202 Accepted
    
    MQ->>AS: Consume "transfer.initiated"
    AS->>AS: Process transfer
    AS->>MQ: Publish "transfer.completed"
    
    MQ->>NS: Consume "transfer.completed"
    NS->>NS: Prepare notification
    NS->>C: Send notification
```

### 2. Client KYC Verification
```mermaid
sequenceDiagram
    participant A as Admin
    participant CS as Client Service
    participant MQ as Message Queue
    participant VS as Verification Service
    participant NS as Notification Service
    participant C as Client
    
    A->>CS: Verify client KYC
    CS->>CS: Update client status
    CS->>MQ: Publish "kyc.verified"
    
    MQ->>VS: Consume "kyc.verified"
    VS->>VS: Update verification status
    
    MQ->>NS: Consume "kyc.verified"
    NS->>C: Send verification confirmation
```

## Data Synchronization

### 1. Read Model Updates
```mermaid
sequenceDiagram
    participant CS as Command Service
    participant DB as Write DB
    participant MQ as Message Queue
    participant RS as Read Service
    participant RC as Read Cache
    
    CS->>DB: Write data
    DB-->>CS: Acknowledge
    CS->>MQ: Publish domain event
    
    MQ->>RS: Consume event
    RS->>RS: Update read model
    RS->>RC: Invalidate/update cache
```

### 2. Cross-Service Data Consistency
```mermaid
sequenceDiagram
    participant TS as Transaction Service
    participant AS as Account Service
    participant MQ as Message Queue
    participant ES as Event Store
    
    TS->>TS: Begin transaction
    TS->>ES: Store event
    TS->>MQ: Publish event
    
    MQ->>AS: Consume event
    AS->>AS: Process event
    AS->>ES: Store processed event
    AS->>MQ: Publish ack
    
    MQ->>TS: Consume ack
    TS->>TS: Commit transaction
```

## Caching Strategy

### 1. Read-Through Cache
```mermaid
sequenceDiagram
    participant C as Client
    participant S as Service
    participant C as Cache
    participant DB as Database
    
    C->>S: Request data
    S->>C: Check cache
    alt Cache hit
        C-->>S: Return cached data
    else Cache miss
        S->>DB: Query database
        DB-->>S: Return data
        S->>C: Cache data
        S-->>C: Return data
    end
```

### 2. Write-Through Cache
```mermaid
sequenceDiagram
    participant C as Client
    participant S as Service
    participant C as Cache
    participant DB as Database
    
    C->>S: Write data
    S->>DB: Write to database
    DB-->>S: Acknowledge
    S->>C: Update cache
    S-->>C: Acknowledge write
```

## Error Handling Flows

### 1. Retry Mechanism
```mermaid
sequenceDiagram
    participant S as Service
    participant T as Target
    participant DLQ as Dead Letter Queue
    
    S->>T: Send request
    T--xS: Error
    S->>S: Increment retry count
    alt Retry count < max_retries
        S->>T: Retry request
    else Max retries reached
        S->>DLQ: Send to DLQ
    end
```

### 2. Circuit Breaker
```mermaid
stateDiagram-v2
    [*] --> Closed: Initial state
    Closed --> Open: Failures > threshold
    Open --> HalfOpen: After timeout
    HalfOpen --> Closed: Success
    HalfOpen --> Open: Failure
    HalfOpen --> Open: Timeout
```

## Performance Considerations

### 1. Request Batching
```mermaid
graph LR
    A[Multiple Requests] --> B[Batching Layer]
    B --> C[Single Batch Request]
    C --> D[Service]
    D --> E[Batch Response]
    E --> F[Split Responses]
    F --> G[Individual Responses]
```

### 2. Data Pagination
```graphql
type Query {
  transactions(
    first: Int
    after: String
    last: Int
    before: String
  ): TransactionConnection
}

type TransactionConnection {
  edges: [TransactionEdge]
  pageInfo: PageInfo!
}

type TransactionEdge {
  node: Transaction!
  cursor: String!
}

type PageInfo {
  hasNextPage: Boolean!
  hasPreviousPage: Boolean!
  startCursor: String
  endCursor: String
}
```

## Security Flows

### 1. Authentication Flow
```mermaid
sequenceDiagram
    participant C as Client
    participant AG as API Gateway
    participant AS as Auth Service
    participant R as Redis
    
    C->>AG: Request with JWT
    AG->>AS: Validate token
    AS->>R: Check token blacklist
    R-->>AS: Token valid
    AS-->>AG: Token claims
    AG->>AG: Check permissions
    AG->>C: Return resource
```

### 2. Data Encryption
```mermaid
flowchart TD
    A[Client] -->|Encrypted Request| B[API Gateway]
    B -->|Decrypt| C[Service]
    C -->|Process| D[Database]
    D -->|Encrypted Data| C
    C -->|Encrypt Response| B
    B -->|Encrypted Response| A
```

## Monitoring and Logging

### 1. Distributed Tracing
```mermaid
sequenceDiagram
    participant C as Client
    participant AG as API Gateway
    participant S1 as Service 1
    participant S2 as Service 2
    participant DB as Database
    
    C->>AG: Request (TraceID: ABC)
    AG->>S1: Forward (TraceID: ABC)
    S1->>S2: Call (TraceID: ABC)
    S2->>DB: Query (TraceID: ABC)
    DB-->>S2: Response
    S2-->>S1: Response
    S1-->>AG: Response
    AG-->>C: Response
```

## Related Documents
- [System Components](011-SYSTEM-COMPONENTS.md)
- [API Gateway](013-API-GATEWAY.md)
- [Service Communication](014-SERVICE-COMMUNICATION.md)
- [Scalability](015-SCALABILITY.md)
