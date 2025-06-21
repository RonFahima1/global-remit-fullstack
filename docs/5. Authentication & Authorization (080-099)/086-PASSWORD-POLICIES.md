# Password Policies and Security

## Overview
This document outlines the password security policies and implementation details for the Global Remit Teller application. These policies are designed to ensure strong authentication security while maintaining a balance between security and usability.

## Table of Contents
1. [Password Requirements](#password-requirements)
2. [Password Storage](#password-storage)
3. [Password Reset Flow](#password-reset-flow)
4. [Account Lockout Policy](#account-lockout-policy)
5. [Password Expiration](#password-expiration)
6. [Password Strength Requirements](#password-strength-requirements)
7. [Implementation Details](#implementation-details)
8. [Security Considerations](#security-considerations)
9. [Compliance](#compliance)
10. [Monitoring and Logging](#monitoring-and-logging)
11. [Testing](#testing)

## Password Requirements

### Complexity Rules
- Minimum length: 12 characters
- Must include characters from at least 3 of the following categories:
  - Uppercase letters (A-Z)
  - Lowercase letters (a-z)
  - Numbers (0-9)
  - Special characters (!@#$%^&*()_+{}[]|:;"'<>,.?/)
- Must not contain the username or email address
- Must not be a commonly used password
- Must not be the same as the last 5 passwords

### Password Rotation
- Passwords expire every 90 days
- Users receive notifications starting 14 days before expiration
- Minimum password age: 1 day (prevents rapid password changes to cycle back to old passwords)

## Password Storage

### Hashing Algorithm
- **Algorithm**: Argon2id (winner of the Password Hashing Competition)
- **Parameters**:
  - Time cost: 3
  - Memory cost: 65536 KB (64MB)
  - Parallelism: 4
  - Salt length: 16 bytes
  - Hash length: 32 bytes

### Implementation
```go
// Example using golang.org/x/crypto/argon2
import (
    "crypto/rand"
    "crypto/subtle"
    "encoding/base64"
    "errors"
    "fmt"
    "strings"
    "golang.org/x/crypto/argon2"
)

type params struct {
    memory      uint32
    iterations  uint32
    parallelism uint8
    saltLength  uint32
    keyLength   uint32
}

var (
    // Default parameters for password hashing
    defaultParams = &params{
        memory:      64 * 1024, // 64MB
        iterations:  3,
        parallelism: 4,
        saltLength:  16,
        keyLength:   32,
    }
    
    // Common error definitions
    ErrInvalidHash         = errors.New("the encoded hash is not in the correct format")
    ErrIncompatibleVariant = errors.New("incompatible version of argon2")
    ErrIncompatibleParams  = errors.New("incompatible parameters")
)

// GenerateHash generates a new password hash
func GenerateHash(password string) (string, error) {
    p := defaultParams
    
    // Generate a cryptographically secure random salt
    salt := make([]byte, p.saltLength)
    if _, err := rand.Read(salt); err != nil {
        return "", err
    }
    
    // Generate the hash
    hash := argon2.IDKey(
        []byte(password),
        salt,
        p.iterations,
        p.memory,
        p.parallelism,
        p.keyLength,
    )
    
    // Base64 encode the salt and hashed password
    b64Salt := base64.RawStdEncoding.EncodeToString(salt)
    b64Hash := base64.RawStdEncoding.EncodeToString(hash)
    
    // Format: $argon2id$v=19$m=65536,t=3,p=4$salt$hash
    encodedHash := fmt.Sprintf(
        "$argon2id$v=%d$m=%d,t=%d,p=%d$%s$%s",
        argon2.Version,
        p.memory,
        p.iterations,
        p.parallelism,
        b64Salt,
        b64Hash,
    )
    
    return encodedHash, nil
}

// ComparePasswordAndHash verifies a password against a hash
func ComparePasswordAndHash(password, encodedHash string) (bool, error) {
    // Extract parameters, salt, and hash from the encoded hash
    p, salt, hash, err := decodeHash(encodedHash)
    if err != nil {
        return false, err
    }
    
    // Generate the comparison hash using the same parameters
    otherHash := argon2.IDKey(
        []byte(password),
        salt,
        p.iterations,
        p.memory,
        p.parallelism,
        p.keyLength,
    )
    
    // Compare the hashes in constant time
    if subtle.ConstantTimeCompare(hash, otherHash) == 1 {
        return true, nil
    }
    
    return false, nil
}

// decodeHash decodes the encoded hash into its components
func decodeHash(encodedHash string) (*params, []byte, []byte, error) {
    vals := strings.Split(encodedHash, "$")
    if len(vals) != 6 {
        return nil, nil, nil, ErrInvalidHash
    }
    
    var version int
    if _, err := fmt.Sscanf(vals[2], "v=%d", &version); err != nil {
        return nil, nil, nil, err
    }
    if version != argon2.Version {
        return nil, nil, nil, ErrIncompatibleVariant
    }
    
    p := &params{}
    if _, err := fmt.Sscanf(vals[3], "m=%d,t=%d,p=%d", &p.memory, &p.iterations, &p.parallelism); err != nil {
        return nil, nil, nil, err
    }
    
    salt, err := base64.RawStdEncoding.DecodeString(vals[4])
    if err != nil {
        return nil, nil, nil, err
    }
    
    hash, err := base64.RawStdEncoding.DecodeString(vals[5])
    if err != nil {
        return nil, nil, nil, err
    }
    
    p.saltLength = uint32(len(salt))
    p.keyLength = uint32(len(hash))
    
    return p, salt, hash, nil
}
```

## Password Reset Flow

### Self-Service Password Reset
1. User clicks "Forgot Password"
2. System sends a time-limited (1 hour) reset token to the user's email
3. User clicks the reset link and is prompted to enter a new password
4. System validates the token and enforces password policies
5. On successful reset, system invalidates all existing sessions

### Admin-Initiated Password Reset
1. Admin selects a user and initiates a password reset
2. System generates a one-time use reset token
3. Token is sent to the user's email
4. User must set a new password on next login

## Account Lockout Policy

### Failed Login Attempts
- Maximum of 5 failed login attempts
- Account is locked for 15 minutes after reaching the limit
- Lockout counter resets after successful login

### Suspicious Activity
- Account is temporarily locked after detecting suspicious login patterns
- User is notified via email of the lockout
- Admin intervention may be required for repeated lockouts

## Password Expiration

### Notification Process
- First notice: 14 days before expiration
- Second notice: 7 days before expiration
- Final notice: 1 day before expiration

### Grace Period
- 7-day grace period after expiration
- After grace period, account is locked until password is changed

## Implementation Details

### Frontend Validation
```typescript
// utils/validation.ts
export const validatePassword = (password: string, email?: string): string | null => {
  if (password.length < 12) {
    return 'Password must be at least 12 characters long';
  }

  let categories = 0;
  if (/[a-z]/.test(password)) categories++;
  if (/[A-Z]/.test(password)) categories++;
  if (/[0-9]/.test(password)) categories++;
  if (/[^a-zA-Z0-9]/.test(password)) categories++;

  if (categories < 3) {
    return 'Password must include characters from at least 3 categories (lowercase, uppercase, numbers, special)';
  }

  if (email) {
    const username = email.split('@')[0];
    if (username && password.toLowerCase().includes(username.toLowerCase())) {
      return 'Password cannot contain your username or email';
    }
  }

  // Check against common passwords
  const commonPasswords = ['password', '123456', 'qwerty', 'letmein'];
  if (commonPasswords.some(common => password.toLowerCase().includes(common))) {
    return 'Password is too common or easily guessable';
  }

  return null;
};
```

### Backend Implementation
```go
// pkg/auth/password.go
package auth

import (
    "errors"
    "regexp"
    "strings"
    "time"
)

type PasswordPolicy struct {
    MinLength         int
    RequireUpper      bool
    RequireLower      bool
    RequireNumber     bool
    RequireSpecial    bool
    MinCategories     int
    MaxAge            time.Duration
    MaxAttempts       int
    LockoutDuration   time.Duration
    HistorySize       int
    CommonPasswords   []string
}

var (
    DefaultPasswordPolicy = PasswordPolicy{
        MinLength:       12,
        RequireUpper:    true,
        RequireLower:    true,
        RequireNumber:   true,
        RequireSpecial:  true,
        MinCategories:   3,
        MaxAge:          90 * 24 * time.Hour, // 90 days
        MaxAttempts:     5,
        LockoutDuration: 15 * time.Minute,
        HistorySize:     5,
        CommonPasswords: []string{
            "password", "123456", "qwerty", "letmein", "welcome",
            "admin123", "passw0rd", "password1", "12345678", "123456789",
        },
    }
)

func (p *PasswordPolicy) Validate(password, username string) error {
    if len(password) < p.MinLength {
        return errors.New("password is too short")
    }

    var categories int
    if p.RequireLower && strings.ContainsAny(password, "abcdefghijklmnopqrstuvwxyz") {
        categories++
    }
    if p.RequireUpper && strings.ContainsAny(password, "ABCDEFGHIJKLMNOPQRSTUVWXYZ") {
        categories++
    }
    if p.RequireNumber && strings.ContainsAny(password, "0123456789") {
        categories++
    }
    if p.RequireSpecial {
        if matched, _ := regexp.MatchString(`[^a-zA-Z0-9]`, password); matched {
            categories++
        }
    }

    if categories < p.MinCategories {
        return errors.New("password does not meet complexity requirements")
    }

    if username != "" && strings.Contains(strings.ToLower(password), strings.ToLower(username)) {
        return errors.New("password cannot contain username")
    }

    for _, common := range p.CommonPasswords {
        if strings.Contains(strings.ToLower(password), common) {
            return errors.New("password is too common")
        }
    }

    return nil
}
```

## Security Considerations

### Secure Password Reset
- Use time-limited, single-use tokens
- Tokens are invalidated after use
- No password hints or security questions

### Session Management
- Invalidate all sessions on password change
- Require re-authentication for sensitive operations
- Implement session timeout and idle timeout

### Rate Limiting
- Limit login attempts per IP and per account
- Implement progressive delays for failed attempts
- Monitor for brute force attacks

## Compliance

### Regulatory Requirements
- NIST SP 800-63B (Digital Identity Guidelines)
- PCI DSS (Payment Card Industry Data Security Standard)
- GDPR (General Data Protection Regulation)
- Local data protection laws

### Audit Requirements
- Log all password changes and resets
- Record IP address and user agent for each authentication attempt
- Maintain audit trail for compliance reporting

## Monitoring and Logging

### Log Events
- Failed login attempts
- Password changes and resets
- Account lockouts and unlocks
- Suspicious activity

### Alerting
- Multiple failed login attempts
- Password reset requests
- Unusual login locations or devices

## Testing

### Unit Tests
- Password complexity validation
- Hashing and verification
- Policy enforcement

### Integration Tests
- End-to-end password reset flow
- Account lockout scenarios
- Session management

### Security Tests
- Password brute force protection
- Token security
- Session fixation prevention

## Maintenance

### Regular Reviews
- Review password policies annually
- Update common passwords list regularly
- Monitor for new security vulnerabilities

### User Education
- Provide password strength feedback
- Offer password manager recommendations
- Security awareness training
