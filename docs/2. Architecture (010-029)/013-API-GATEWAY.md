# API Gateway Architecture

## Overview
The API Gateway serves as the single entry point for all client requests, handling routing, authentication, rate limiting, and request/response transformation.

## Key Responsibilities

### 1. Request Routing
- **Path-based routing** to backend services
- **Header-based routing** for API versioning
- **Service discovery** integration

### 2. Authentication & Authorization
- JWT validation
- API key validation
- Role-based access control (RBAC)
- OAuth 2.0 / OpenID Connect integration

### 3. Security
- Request validation
- Rate limiting
- IP whitelisting/blacklisting
- CORS management
- Request/response validation

### 4. Performance
- Response caching
- Request/response compression
- Connection pooling
- Load balancing

### 5. Observability
- Request/response logging
- Metrics collection
- Distributed tracing
- Error tracking

## Configuration

### Nginx Configuration Structure
```nginx
# Main context
user nginx;
worker_processes auto;
error_log /var/log/nginx/error.log warn;
pid /var/run/nginx.pid;

events {
    worker_connections 1024;
}

http {
    # MIME types
    include /etc/nginx/mime.types;
    default_type application/octet-stream;

    # Logging
    log_format main '$remote_addr - $remote_user [$time_local] "$request" '
                    '$status $body_bytes_sent "$http_referer" '
                    '"$http_user_agent" "$http_x_forwarded_for"';
    access_log /var/log/nginx/access.log main;

    # Performance
    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 65;
    types_hash_max_size 2048;
    server_tokens off;

    # Rate limiting
    limit_req_zone $binary_remote_addr zone=api:10m rate=10r/s;
    limit_conn_zone $binary_remote_addr zone=addr:10m;

    # SSL/TLS
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers 'ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256';
    ssl_prefer_server_ciphers on;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;

    # Gzip
    gzip on;
    gzip_disable "msie6";
    gzip_vary on;
    gzip_proxied any;
    gzip_comp_level 6;
    gzip_buffers 16 8k;
    gzip_http_version 1.1;
    gzip_types text/plain text/css application/json application/javascript text/xml application/xml application/xml+rss text/javascript;

    # Include configurations
    include /etc/nginx/conf.d/*.conf;
    include /etc/nginx/sites-enabled/*;
}
```

### API Gateway Configuration
```nginx
# API Gateway configuration
server {
    listen 80;
    server_name api.globalremit.com;
    
    # Redirect all HTTP to HTTPS
    return 301 https://$host$request_uri;
}

server {
    listen 443 ssl http2;
    server_name api.globalremit.com;

    # SSL configuration
    ssl_certificate /etc/letsencrypt/live/api.globalremit.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/api.globalremit.com/privkey.pem;
    
    # Security headers
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Referrer-Policy "strict-origin-when-cross-origin" always;
    
    # API version in header
    set $api_version "v1";
    if ($http_accept ~* "application/vnd.globalremit.v2+json") {
        set $api_version "v2";
    }
    
    # Global rate limiting
    limit_req zone=api burst=20 nodelay;
    limit_conn addr 10;
    
    # Request size limits
    client_max_body_size 10m;
    
    # Proxy settings
    proxy_http_version 1.1;
    proxy_set_header Connection "";
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
    proxy_set_header X-Request-Id $request_id;
    
    # Timeouts
    proxy_connect_timeout 10s;
    proxy_send_timeout 30s;
    proxy_read_timeout 30s;
    
    # Error pages
    error_page 400 401 402 403 404 405 429 /error.json;
    error_page 500 501 502 503 504 /error.json;
    
    location = /error.json {
        internal;
        default_type application/json;
        add_header Content-Type application/json;
        return 200 '{"error":{"code":$status,"message":"$status_text"}}';
    }
    
    # Health check endpoint
    location /health {
        access_log off;
        add_header Content-Type application/json;
        return 200 '{"status":"healthy","timestamp":"$time_iso8601"}';
    }
    
    # API routes
    location /api/ {
        # CORS headers
        if ($request_method = 'OPTIONS') {
            add_header 'Access-Control-Allow-Origin' '*' always;
            add_header 'Access-Control-Allow-Methods' 'GET, POST, PUT, DELETE, OPTIONS' always;
            add_header 'Access-Control-Allow-Headers' 'DNT,User-Agent,X-Requested-With,If-Modified-Since,Cache-Control,Content-Type,Range,Authorization' always;
            add_header 'Access-Control-Max-Age' 1728000;
            add_header 'Content-Type' 'text/plain; charset=utf-8';
            add_header 'Content-Length' 0;
            return 204;
        }
        
        # Authentication
        auth_request /_validate_token;
        auth_request_set $auth_status $upstream_status;
        
        # Route to services based on path
        location ~ ^/api/auth/ {
            proxy_pass http://auth-service:8080/$api_version;
        }
        
        location ~ ^/api/clients/ {
            proxy_pass http://client-service:8080/$api_version;
        }
        
        location ~ ^/api/accounts/ {
            proxy_pass http://account-service:8080/$api_version;
        }
        
        location ~ ^/api/transactions/ {
            proxy_pass http://transaction-service:8080/$api_version;
        }
        
        # Default route
        location /api/ {
            return 404;
        }
    }
    
    # Internal endpoint for token validation
    location = /_validate_token {
        internal;
        proxy_pass http://auth-service:8080/$api_version/auth/validate;
        proxy_pass_request_body off;
        proxy_set_header Content-Length "";
        proxy_set_header X-Original-URI $request_uri;
        proxy_set_header X-Original-Method $request_method;
        proxy_set_header Authorization $http_authorization;
    }
    
    # WebSocket support
    location /ws/ {
        proxy_pass http://ws-service:8080;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_read_timeout 1d;
        proxy_send_timeout 1d;
    }
}
```

## Authentication Flow

### JWT Validation
1. Client includes JWT in `Authorization: Bearer <token>` header
2. API Gateway forwards request to auth service for validation
3. Auth service validates token and returns user claims
4. Gateway adds `X-User-*` headers with user information
5. Backend services trust these headers (behind internal network)

### Rate Limiting
- **Global rate limit**: 10 requests per second per IP
- **Burst limit**: 20 requests
- **Connection limit**: 10 concurrent connections per IP
- **Per-endpoint limits**:
  - `/auth/*`: 5 requests/minute
  - `/api/*/public`: 100 requests/minute
  - `/api/*/admin`: 500 requests/minute

## Monitoring and Logging

### Metrics
- Request count by endpoint
- Response time percentiles
- Error rates
- HTTP status codes
- Request/response sizes

### Logging
- Structured JSON logging
- Correlation IDs
- Request/response metadata
- Error details

## Performance Tuning

### Caching
- **Public resources**: 5 minutes
- **User-specific resources**: 1 minute
- **No cache**: Sensitive endpoints

### Compression
- Gzip for text-based responses
- Brotli for modern browsers
- Image optimization

## Security Considerations

### Headers
- HSTS
- X-Content-Type-Options
- X-Frame-Options
- X-XSS-Protection
- Content-Security-Policy
- Referrer-Policy

### TLS Configuration
- TLS 1.2/1.3 only
- Strong cipher suites
- OCSP stapling
- HSTS preload
- Certificate transparency

## High Availability

### Load Balancing
- Round-robin between API Gateway instances
- Health checks
- Circuit breakers
- Retry policies

### Failover
- Multiple availability zones
- Automatic failover
- Session persistence

## Related Documents
- [Architecture Overview](010-ARCHITECTURE-OVERVIEW.md)
- [System Components](011-SYSTEM-COMPONENTS.md)
- [Data Flow](012-DATA-FLOW.md)
- [Service Communication](014-SERVICE-COMMUNICATION.md)
- [Security Architecture](016-SECURITY-ARCHITECTURE.md)
