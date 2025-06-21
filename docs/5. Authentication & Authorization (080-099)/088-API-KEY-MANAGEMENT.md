# API Key Management

## Overview
This document outlines the API key management system for the Global Remit Teller application. API keys are used to authenticate programmatic access to our API endpoints, allowing third-party applications and services to interact with our platform securely.

## Table of Contents
1. [API Key Types](#api-key-types)
2. [Key Generation and Storage](#key-generation-and-storage)
3. [Authentication Flow](#authentication-flow)
4. [Rate Limiting](#rate-limiting)
5. [Key Rotation](#key-rotation)
6. [Revocation and Expiration](#revocation-and-expiration)
7. [Security Considerations](#security-considerations)
8. [Implementation Details](#implementation-details)
9. [Monitoring and Logging](#monitoring-and-logging)
10. [Compliance](#compliance)

## API Key Types

### 1. User API Keys
- **Purpose**: Allow users to access the API on their own behalf
- **Permissions**: Limited to the user's own resources
- **Expiration**: 90 days by default, configurable
- **Rate Limit**: 1000 requests per minute

### 2. Application API Keys
- **Purpose**: For third-party applications integrating with our platform
- **Permissions**: Defined by OAuth scopes
- **Expiration**: 1 year by default, renewable
- **Rate Limit**: 100 requests per minute

### 3. Service API Keys
- **Purpose**: For internal services to communicate with each other
- **Permissions**: Broad access, should be highly restricted
- **Expiration**: 1 year, with automatic rotation
- **Rate Limit**: 10,000 requests per minute

## Key Generation and Storage

### Key Format
```
gr_<environment>_<random_32_bytes_base64url>
```

Example: `gr_prod_dBxcqFm3zLpX9yK8wVjH5tR7sN2Q4eA6`

### Storage
- **Hashing**: Keys are hashed using Argon2id before storage
- **Database**: Stored in the `api_keys` table
- **Secrets Manager**: Used for service API keys
- **Environment Variables**: Never store API keys in environment variables

### Database Schema
```sql
-- API Keys Table
CREATE TABLE api_keys (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    name VARCHAR(100) NOT NULL,
    key_hash VARCHAR(255) NOT NULL,
    prefix VARCHAR(32) NOT NULL, -- First 8 chars of the key for identification
    type VARCHAR(20) NOT NULL, -- 'user', 'application', 'service'
    scopes TEXT[] NOT NULL DEFAULT '{}',
    expires_at TIMESTAMPTZ,
    last_used_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    revoked_at TIMESTAMPTZ,
    revoked_reason TEXT,
    metadata JSONB,
    
    CONSTRAINT valid_type CHECK (type IN ('user', 'application', 'service')),
    CONSTRAINT prefix_length CHECK (length(prefix) = 8)
);

-- Indexes
CREATE INDEX idx_api_keys_prefix ON api_keys(prefix);
CREATE INDEX idx_api_keys_user_id ON api_keys(user_id) WHERE user_id IS NOT NULL;
CREATE INDEX idx_api_keys_expires ON api_keys(expires_at) WHERE expires_at IS NOT NULL;

-- API Key Usage Logs
CREATE TABLE api_key_usage (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    api_key_id UUID NOT NULL REFERENCES api_keys(id) ON DELETE CASCADE,
    timestamp TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    method VARCHAR(10) NOT NULL,
    path TEXT NOT NULL,
    status_code INTEGER NOT NULL,
    user_agent TEXT,
    ip_address INET,
    request_id UUID NOT NULL,
    duration_ms INTEGER NOT NULL,
    error_message TEXT
);

-- Indexes for API key usage
CREATE INDEX idx_api_key_usage_api_key_id ON api_key_usage(api_key_id);
CREATE INDEX idx_api_key_usage_timestamp ON api_key_usage(timestamp);
CREATE INDEX idx_api_key_usage_request_id ON api_key_usage(request_id);
```

## Authentication Flow

### 1. API Key Authentication
```http
GET /api/v1/transactions
Authorization: ApiKey gr_prod_dBxcqFm3zLpX9yK8wVjH5tR7sN2Q4eA6
```

### 2. Request Signing (Recommended)
For additional security, clients should sign their requests using HMAC-SHA256:

1. Client generates a unique request ID
2. Client creates a string to sign:
   ```
   METHOD\n\n\nTIMESTAMP\nREQUEST_ID\nPATH\nQUERY_STRING\nBODY_HASH
   ```
3. Client signs the string using their API key secret
4. Client sends the request with headers:
   ```
   Authorization: ApiKey gr_prod_dBxcqFm3zLpX9yK8wVjH5tR7sN2Q4eA6
   X-Request-Timestamp: 1624224000
   X-Request-Id: 550e8400-e29b-41d4-a716-446655440000
   X-Signature: t7dV16m0mTr2CllBwvX3kOGFl2Q=
   ```

## Rate Limiting

### Tiers
1. **Free Tier**: 100 requests/minute
2. **Pro Tier**: 1,000 requests/minute
3. **Enterprise Tier**: 10,000 requests/minute

### Implementation
- Uses Redis for distributed rate limiting
- Sliding window algorithm
- Headers included in response:
  ```
  X-RateLimit-Limit: 1000
  X-RateLimit-Remaining: 987
  X-RateLimit-Reset: 60
  Retry-After: 10
  ```

## Key Rotation

### Automatic Rotation
1. Service API keys are rotated every 90 days
2. Clients receive a new key 30 days before expiration
3. Old keys continue to work for 7 days after rotation

### Manual Rotation
1. User generates a new key
2. Old key is marked for revocation in 7 days
3. User is shown both keys during the transition period

## Revocation and Expiration

### Revocation Reasons
1. Suspected compromise
2. Employee offboarding
3. Application decommissioned
4. Policy violation

### Expiration
- User API keys: 90 days
- Application API keys: 1 year
- Service API keys: 1 year (with automatic rotation)

## Security Considerations

### Key Generation
- Use cryptographically secure random number generators
- Minimum key length of 32 bytes
- No special characters that might cause parsing issues

### Storage
- Never store plaintext API keys
- Use strong, slow hashing algorithms (Argon2id)
- Encrypt API keys in transit and at rest

### Transmission
- Require HTTPS for all API requests
- Use request signing for sensitive operations
- Implement replay attack prevention

## Implementation Details

### API Key Service

```go
// backend/pkg/auth/apikey/service.go
package apikey

import (
	"context"
	"crypto/rand"
	"crypto/subtle"
	"encoding/base64"
	"fmt"
	"strings"
	"time"

	"github.com/pkg/errors"
	"golang.org/x/crypto/argon2"
)

type APIKey struct {
	ID           string    `json:"id"`
	UserID       string    `json:"user_id,omitempty"`
	Name         string    `json:"name"`
	KeyHash      string    `json:"-"`
	Prefix       string    `json:"prefix"`
	Type         string    `json:"type"`
	Scopes       []string  `json:"scopes"`
	ExpiresAt    time.Time `json:"expires_at,omitempty"`
	LastUsedAt   time.Time `json:"last_used_at,omitempty"`
	CreatedAt    time.Time `json:"created_at"`
	RevokedAt    time.Time `json:"revoked_at,omitempty"`
	RevokedReason string   `json:"revoked_reason,omitempty"`
}

type APIKeyService struct {
	repo      Repository
	hmacKey   []byte
	keyPrefix string
}

type Repository interface {
	CreateAPIKey(ctx context.Context, key *APIKey) error
	GetAPIKeyByID(ctx context.Context, id string) (*APIKey, error)
	GetAPIKeyByPrefix(ctx context.Context, prefix string) (*APIKey, error)
	ListAPIKeys(ctx context.Context, userID string) ([]*APIKey, error)
	UpdateAPIKey(ctx context.Context, key *APIKey) error
	DeleteAPIKey(ctx context.Context, id string) error
}

// NewAPIKeyService creates a new API key service
func NewAPIKeyService(repo Repository, hmacKey []byte, env string) *APIKeyService {
	return &APIKeyService{
		repo:      repo,
		hmacKey:   hmacKey,
		keyPrefix: fmt.Sprintf("gr_%s_", env),
	}
}

// GenerateKey generates a new API key
func (s *APIKeyService) GenerateKey(userID, name, keyType string, scopes []string, expiresInDays int) (string, *APIKey, error) {
	// Generate random bytes for the key
	keyBytes := make([]byte, 32)
	if _, err := rand.Read(keyBytes); err != nil {
		return "", nil, errors.Wrap(err, "failed to generate random bytes")
	}

	// Encode as base64 URL without padding
	key := s.keyPrefix + base64.URLEncoding.WithPadding(base64.NoPadding).EncodeToString(keyBytes)

	// Generate a prefix for identification
	prefix := key[:8]

	// Hash the key for storage
	hash, err := s.hashKey(key)
	if err != nil {
		return "", nil, errors.Wrap(err, "failed to hash API key")
	}

	// Create the API key object
	apiKey := &APIKey{
		UserID:    userID,
		Name:      name,
		KeyHash:   hash,
		Prefix:    prefix,
		Type:      keyType,
		Scopes:    scopes,
		CreatedAt: time.Now().UTC(),
	}

	// Set expiration if specified
	if expiresInDays > 0 {
		expiresAt := time.Now().Add(time.Duration(expiresInDays) * 24 * time.Hour)
		apiKey.ExpiresAt = expiresAt
	}

	return key, apiKey, nil
}

// hashKey hashes the API key using Argon2id
func (s *APIKeyService) hashKey(key string) (string, error) {
	salt := make([]byte, 16)
	if _, err := rand.Read(salt); err != nil {
		return "", errors.Wrap(err, "failed to generate salt")
	}

	hash := argon2.IDKey([]byte(key), salt, 3, 64*1024, 4, 32)

	// Combine salt and hash for storage
	encoded := make([]byte, len(salt)+len(hash))
	copy(encoded[:16], salt)
	copy(encoded[16:], hash)

	return base64.URLEncoding.EncodeToString(encoded), nil
}

// VerifyKey verifies an API key against its hash
func (s *APIKeyService) VerifyKey(key string, hash string) (bool, error) {
	// Decode the stored hash
	decoded, err := base64.URLEncoding.DecodeString(hash)
	if err != nil {
		return false, errors.Wrap(err, "failed to decode hash")
	}

	if len(decoded) < 16 {
		return false, errors.New("invalid hash format")
	}

	// Extract salt and original hash
	salt := decoded[:16]
	originalHash := decoded[16:]

	// Hash the provided key with the same salt
	newHash := argon2.IDKey([]byte(key), salt, 3, 64*1024, 4, 32)

	// Compare the hashes in constant time
	if subtle.ConstantTimeCompare(originalHash, newHash) != 1 {
		return false, nil
	}

	return true, nil
}

// ValidateRequest validates an API key from an HTTP request
func (s *APIKeyService) ValidateRequest(r *http.Request) (*APIKey, error) {
	// Extract API key from header
	authHeader := r.Header.Get("Authorization")
	if authHeader == "" {
		return nil, errors.New("missing authorization header")
	}

	// Check for ApiKey scheme
	parts := strings.SplitN(authHeader, " ", 2)
	if len(parts) != 2 || !strings.EqualFold(parts[0], "ApiKey") {
		return nil, errors.New("invalid authorization format")
	}

	key := parts[1]
	prefix := key
	if len(key) >= 8 {
		prefix = key[:8]
	}

	// Get the API key from the database
	apiKey, err := s.repo.GetAPIKeyByPrefix(r.Context(), prefix)
	if err != nil {
		return nil, errors.Wrap(err, "invalid API key")
	}

	// Verify the key
	valid, err := s.VerifyKey(key, apiKey.KeyHash)
	if err != nil {
		return nil, errors.Wrap(err, "failed to verify API key")
	}

	if !valid {
		return nil, errors.New("invalid API key")
	}

	// Check if the key is revoked
	if !apiKey.RevokedAt.IsZero() {
		return nil, errors.New("API key has been revoked")
	}

	// Check if the key is expired
	if !apiKey.ExpiresAt.IsZero() && apiKey.ExpiresAt.Before(time.Now()) {
		return nil, errors.New("API key has expired")
	}

	// Update last used timestamp
	apiKey.LastUsedAt = time.Now().UTC()
	if err := s.repo.UpdateAPIKey(r.Context(), apiKey); err != nil {
		// Log the error but don't fail the request
		log.Printf("failed to update API key last used timestamp: %v", err)
	}

	return apiKey, nil
}

// RotateKey generates a new key to replace an existing one
func (s *APIKeyService) RotateKey(ctx context.Context, keyID string) (string, error) {
	// Get the existing key
	existing, err := s.repo.GetAPIKeyByID(ctx, keyID)
	if err != nil {
		return "", errors.Wrap(err, "failed to get existing API key")
	}

	// Generate a new key
	newKey, newAPIKey, err := s.GenerateKey(
		existing.UserID,
		existing.Name + " (rotated)",
		existing.Type,
		existing.Scopes,
		90, // Default to 90 days
	)
	if err != nil {
		return "", errors.Wrap(err, "failed to generate new API key")
	}

	// Create the new key
	if err := s.repo.CreateAPIKey(ctx, newAPIKey); err != nil {
		return "", errors.Wrap(err, "failed to create new API key")
	}

	// Mark the old key as rotated
	existing.RevokedAt = time.Now().UTC()
	existing.RevokedReason = "rotated"
	if err := s.repo.UpdateAPIKey(ctx, existing); err != nil {
		// Log the error but don't fail the operation
		log.Printf("failed to mark old API key as rotated: %v", err)
	}

	return newKey, nil
}
```

### Middleware

```go
// backend/pkg/api/middleware/auth.go
package middleware

import (
	"context"
	"net/http"
	"strings"

	"github.com/your-org/your-app/backend/pkg/auth/apikey"
)

// APIKeyAuth is a middleware that validates API keys
func APIKeyAuth(apiKeyService *apikey.APIKeyService) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			// Skip authentication for public endpoints
			if isPublicEndpoint(r.URL.Path) {
				next.ServeHTTP(w, r)
				return
			}

			// Validate the API key
			key, err := apiKeyService.ValidateRequest(r)
			if err != nil {
				http.Error(w, "Unauthorized: "+err.Error(), http.StatusUnauthorized)
				return
			}

			// Add the API key to the request context
			ctx := context.WithValue(r.Context(), "api_key", key)
			next.ServeHTTP(w, r.WithContext(ctx))
		})
	}
}

// isPublicEndpoint checks if the requested path is public
func isPublicEndpoint(path string) bool {
	publicPrefixes := []string{
		"/healthz",
		"/metrics",
		"/docs",
	}

	for _, prefix := range publicPrefixes {
		if strings.HasPrefix(path, prefix) {
			return true
		}
	}

	return false
}
```

## Monitoring and Logging

### Metrics
- API key usage by endpoint
- Error rates by API key
- Rate limit hits
- Expiration warnings

### Logs
- All API key authentications
- Failed authentication attempts
- Key creation and revocation
- Suspicious activity

## Compliance

### Data Protection
- API keys are considered sensitive data
- Logs are redacted to hide full keys
- Access to API key data is restricted

### Audit
- All API key operations are logged
- Regular review of active keys
- Automated detection of unused keys

### Key Rotation
- Enforce regular key rotation
- Notify users of upcoming expirations
- Automatic revocation of long-unused keys

## Best Practices

### For Users
1. Store API keys securely
2. Use the principle of least privilege
3. Rotate keys regularly
4. Never commit API keys to version control

### For Developers
1. Use environment variables or secrets management
2. Implement request signing for sensitive operations
3. Set appropriate rate limits
4. Monitor for suspicious activity

## Integration Examples

### cURL
```bash
curl -H "Authorization: ApiKey gr_prod_dBxcqFm3zLpX9yK8wVjH5tR7sN2Q4eA6" \
     https://api.globalremit.com/v1/transactions
```

### JavaScript (Node.js)
```javascript
const crypto = require('crypto');

class GlobalRemitClient {
  constructor(apiKey, apiSecret) {
    this.apiKey = apiKey;
    this.apiSecret = apiSecret;
    this.baseUrl = 'https://api.globalremit.com/v1';
  }

  async request(method, path, data = null) {
    const url = new URL(path, this.baseUrl);
    const timestamp = Math.floor(Date.now() / 1000);
    const requestId = crypto.randomUUID();
    
    // Prepare request
    const options = {
      method: method.toUpperCase(),
      headers: {
        'Authorization': `ApiKey ${this.apiKey}`,
        'X-Request-Timestamp': timestamp.toString(),
        'X-Request-Id': requestId,
        'Content-Type': 'application/json',
      },
    };

    // Add body if present
    let body = '';
    if (data) {
      body = JSON.stringify(data);
      options.body = body;
    }

    // Generate signature
    const stringToSign = [
      method.toUpperCase(),
      '', // Content-Type
      timestamp,
      requestId,
      url.pathname,
      url.searchParams.toString(),
      crypto.createHash('sha256').update(body).digest('hex'),
    ].join('\n');

    const signature = crypto
      .createHmac('sha256', this.apiSecret)
      .update(stringToSign)
      .digest('base64');

    options.headers['X-Signature'] = signature;

    // Make the request
    const response = await fetch(url.toString(), options);
    
    if (!response.ok) {
      const error = await response.json();
      throw new Error(error.message || 'API request failed');
    }

    return response.json();
  }
}
```

## Conclusion

This API key management system provides a secure and scalable way to manage programmatic access to the Global Remit Teller API. By following the implementation details and best practices outlined in this document, you can ensure that your API keys remain secure and your application remains protected against unauthorized access.

For any questions or issues, please contact the security team at security@globalremit.com.
