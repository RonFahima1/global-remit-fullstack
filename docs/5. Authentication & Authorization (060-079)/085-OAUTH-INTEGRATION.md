# OAuth 2.0 Integration Guide

## Overview
This document outlines the OAuth 2.0 integration strategy for the Global Remit Teller application. It covers the implementation of OAuth 2.0 for both authentication and authorization, focusing on secure integration with identity providers (IdPs) and proper session management.

## Table of Contents
1. [Architecture](#architecture)
2. [Supported Identity Providers](#supported-identity-providers)
3. [OAuth 2.0 Flows](#oauth-20-flows)
4. [Backend Implementation](#backend-implementation)
5. [Frontend Integration](#frontend-integration)
6. [Security Considerations](#security-considerations)
7. [Testing Strategy](#testing-strategy)
8. [Troubleshooting](#troubleshooting)

## Architecture

### Components

1. **OAuth Client**
   - Next.js frontend application
   - Handles user redirection to IdP
   - Manages OAuth state and PKCE (Proof Key for Code Exchange)

2. **Backend Service**
   - Validates OAuth tokens
   - Maps external identities to internal user accounts
   - Issues application session tokens

3. **Identity Providers**
   - Google OAuth 2.0
   - Microsoft Identity Platform
   - Other OIDC-compliant providers

## Supported Identity Providers

### Google OAuth 2.0
- **Client ID/Secret**: Managed in Google Cloud Console
- **Scopes**: `openid email profile` (minimal)
- **Endpoints**:
  - Authorization: `https://accounts.google.com/o/oauth2/v2/auth`
  - Token: `https://oauth2.googleapis.com/token`
  - UserInfo: `https://www.googleapis.com/oauth2/v3/userinfo`

### Microsoft Identity Platform
- **Client ID/Secret**: Managed in Azure Portal
- **Scopes**: `openid email profile`
- **Endpoints**:
  - Authorization: `https://login.microsoftonline.com/{tenant}/oauth2/v2.0/authorize`
  - Token: `https://login.microsoftonline.com/{tenant}/oauth2/v2.0/token`
  - UserInfo: `https://graph.microsoft.com/oidc/userinfo`

## OAuth 2.0 Flows

### Authorization Code Flow with PKCE (Recommended)

1. Frontend generates a code verifier and challenge
2. User is redirected to IdP's authorization endpoint
3. After authentication, IdP redirects to callback URL with authorization code
4. Frontend exchanges code for tokens using the code verifier
5. Backend validates ID token and creates session

### Token Validation Flow
1. Backend receives ID token from frontend
2. Validates token signature using IdP's public keys
3. Verifies token claims (issuer, audience, expiration)
4. Maps external identity to internal user account
5. Issues application session token

## Backend Implementation

### Dependencies

```toml
# go.mod
require (
    github.com/coreos/go-oidc/v3 v3.6.0
    golang.org/x/oauth2 v0.8.0
)
```

### Configuration

```go
type OAuthConfig struct {
    ClientID     string
    ClientSecret string
    RedirectURL  string
    Scopes       []string
    Endpoint     oauth2.Endpoint
}

// Example for Google
func NewGoogleOAuthConfig() *OAuthConfig {
    return &OAuthConfig{
        ClientID:     os.Getenv("GOOGLE_OAUTH_CLIENT_ID"),
        ClientSecret: os.Getenv("GOOGLE_OAUTH_CLIENT_SECRET"),
        RedirectURL:  os.Getenv("OAUTH_REDIRECT_URL") + "/auth/google/callback",
        Scopes:       []string{"openid", "email", "profile"},
        Endpoint: oauth2.Endpoint{
            AuthURL:   "https://accounts.google.com/o/oauth2/v2/auth",
            TokenURL:  "https://oauth2.googleapis.com/token",
        },
    }
}
```

### Token Validation

```go
func ValidateIDToken(ctx context.Context, rawIDToken string) (*oidc.IDToken, error) {
    provider, err := oidc.NewProvider(ctx, "https://accounts.google.com")
    if err != nil {
        return nil, fmt.Errorf("failed to get provider: %v", err)
    }

    verifier := provider.Verifier(&oidc.Config{ClientID: oauthConfig.ClientID})
    return verifier.Verify(ctx, rawIDToken)
}
```

## Frontend Integration

### Next.js Auth Configuration

```typescript
// pages/api/auth/[...nextauth].ts
import NextAuth from 'next-auth'
import GoogleProvider from 'next-auth/providers/google'

export default NextAuth({
  providers: [
    GoogleProvider({
      clientId: process.env.GOOGLE_CLIENT_ID!,
      clientSecret: process.env.GOOGLE_CLIENT_SECRET!,
      authorization: {
        params: {
          prompt: "consent",
          access_type: 'offline',
          response_type: 'code',
          scope: 'openid email profile',
        },
      },
    }),
  ],
  callbacks: {
    async jwt({ token, account }) {
      // Add access token to JWT
      if (account?.access_token) {
        token.accessToken = account.access_token
      }
      return token
    },
    async session({ session, token }) {
      // Add access token to session
      session.accessToken = token.accessToken as string
      return session
    },
  },
})
```

### Protecting API Routes

```typescript
// pages/api/protected-route.ts
import { getServerSession } from 'next-auth/next'
import { authOptions } from './auth/[...nextauth]'

export default async function handler(req, res) {
  const session = await getServerSession(req, res, authOptions)
  
  if (!session) {
    return res.status(401).json({ message: 'Unauthorized' })
  }

  // Access token is available in session.accessToken
  // Use it to call your backend API
  
  return res.status(200).json({ message: 'Protected data' })
}
```

## Security Considerations

1. **PKCE (Proof Key for Code Exchange)**
   - Required for all OAuth flows
   - Mitigates authorization code interception attacks

2. **Token Storage**
   - Store refresh tokens securely (HTTP-only, Secure, SameSite=Strict cookies)
   - Never store tokens in localStorage

3. **CSRF Protection**
   - Implement state parameter in OAuth flow
   - Use CSRF tokens for API requests

4. **Token Validation**
   - Always validate ID token signature
   - Verify token claims (iss, aud, exp, iat)
   - Implement token revocation checking

5. **Rate Limiting**
   - Implement rate limiting on authentication endpoints
   - Monitor for suspicious authentication attempts

## Testing Strategy

### Unit Tests
- Token validation logic
- User mapping functions
- Error handling

### Integration Tests
- OAuth flow with mock IdP
- Token exchange and validation
- Session management

### Security Tests
- CSRF protection
- Token validation
- Rate limiting
- Error handling edge cases

## Troubleshooting

### Common Issues

1. **Invalid Redirect URI**
   - Verify the redirect URI is registered in the IdP's console
   - Ensure the protocol (http/https) matches

2. **Invalid Client ID/Secret**
   - Verify environment variables are set correctly
   - Check for typos in client configuration

3. **Token Validation Failures**
   - Check token expiration
   - Verify audience and issuer claims
   - Ensure clock skew is accounted for

4. **CORS Issues**
   - Configure CORS headers correctly
   - Verify allowed origins in both frontend and backend

## Monitoring and Logging

1. **Log OAuth Events**
   - Successful/failed authentication attempts
   - Token validation errors
   - Suspicious activities

2. **Metrics**
   - Authentication success/failure rates
   - Token validation times
   - Error rates by type

## References

- [OAuth 2.0 Specification](https://tools.ietf.org/html/rfc6749)
- [OpenID Connect Core](https://openid.net/specs/openid-connect-core-1_0.html)
- [OAuth 2.0 Security Best Current Practice](https://tools.ietf.org/html/draft-ietf-oauth-security-topics-16)
- [NextAuth.js Documentation](https://next-auth.js.org/)
- [Google OAuth 2.0](https://developers.google.com/identity/protocols/oauth2)
- [Microsoft Identity Platform](https://docs.microsoft.com/en-us/azure/active-directory/develop/)
