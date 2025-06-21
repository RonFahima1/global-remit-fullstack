package token

import (
	"backend/internal/cache"
	"backend/internal/domain"
	"context"
	"crypto/rsa"
	"encoding/pem"
	"errors"
	"os"
	"time"

	"github.com/golang-jwt/jwt/v5"
	"github.com/google/uuid"
)

var (
	privateKey *rsa.PrivateKey
	publicKey  *rsa.PublicKey
)

// LoadKeys loads RSA keys from environment variables (not files)
func LoadKeys() error {
	privPEM := os.Getenv("JWT_PRIVATE_KEY")
	pubPEM := os.Getenv("JWT_PUBLIC_KEY")
	if privPEM == "" || pubPEM == "" {
		return errors.New("JWT_PRIVATE_KEY and JWT_PUBLIC_KEY env vars required")
	}
	// Decode private key
	privBlock, _ := pem.Decode([]byte(privPEM))
	if privBlock == nil {
		return errors.New("invalid private key PEM")
	}
	var err error
	privateKey, err = jwt.ParseRSAPrivateKeyFromPEM([]byte(privPEM))
	if err != nil {
		return err
	}
	// Decode public key
	pubBlock, _ := pem.Decode([]byte(pubPEM))
	if pubBlock == nil {
		return errors.New("invalid public key PEM")
	}
	publicKey, err = jwt.ParseRSAPublicKeyFromPEM([]byte(pubPEM))
	if err != nil {
		return err
	}
	return nil
}

// CustomClaims for access tokens
type CustomClaims struct {
	UserID      string   `json:"user_id"`
	Role        string   `json:"role"`
	BranchID    string   `json:"branch_id,omitempty"`
	Permissions []string `json:"permissions"`
	jwt.RegisteredClaims
}

// GenerateTokenPair generates access and refresh tokens
func GenerateTokenPair(userID, role, branchID string) (accessToken, refreshToken string, err error) {
	if privateKey == nil {
		return "", "", errors.New("private key not loaded")
	}
	// Access token
	accessClaims := CustomClaims{
		UserID:   userID,
		Role:     role,
		BranchID: branchID,
		RegisteredClaims: jwt.RegisteredClaims{
			ExpiresAt: jwt.NewNumericDate(time.Now().Add(15 * time.Minute)),
			IssuedAt:  jwt.NewNumericDate(time.Now()),
			Issuer:    "global-remit-api",
			Subject:   userID,
			ID:        uuid.New().String(),
		},
	}
	at := jwt.NewWithClaims(jwt.SigningMethodRS256, accessClaims)
	accessToken, err = at.SignedString(privateKey)
	if err != nil {
		return "", "", err
	}
	// Refresh token
	refreshClaims := jwt.RegisteredClaims{
		ExpiresAt: jwt.NewNumericDate(time.Now().Add(7 * 24 * time.Hour)),
		IssuedAt:  jwt.NewNumericDate(time.Now()),
		Issuer:    "global-remit-api",
		Subject:   userID,
		ID:        uuid.New().String(),
	}
	rt := jwt.NewWithClaims(jwt.SigningMethodRS256, refreshClaims)
	refreshToken, err = rt.SignedString(privateKey)
	return
}

// ValidateToken validates a JWT and returns claims if valid
func ValidateToken(tokenStr string) (*CustomClaims, error) {
	if publicKey == nil {
		return nil, errors.New("public key not loaded")
	}
	token, err := jwt.ParseWithClaims(tokenStr, &CustomClaims{}, func(token *jwt.Token) (interface{}, error) {
		return publicKey, nil
	})
	if err != nil {
		return nil, err
	}
	if claims, ok := token.Claims.(*CustomClaims); ok && token.Valid {
		// Check revocation
		if IsTokenRevoked(context.Background(), claims.ID) {
			return nil, errors.New("token revoked")
		}
		return claims, nil
	}
	return nil, errors.New("invalid token claims")
}

// IsTokenRevoked checks if a token jti is blacklisted in Redis
func IsTokenRevoked(ctx context.Context, jti string) bool {
	val, err := cache.Get(ctx, "jwt:blacklist:"+jti)
	return err == nil && val == "revoked"
}

// RevokeToken adds a token jti to the Redis blacklist
func RevokeToken(ctx context.Context, jti string, exp time.Time) error {
	return cache.Set(ctx, "jwt:blacklist:"+jti, "revoked", time.Until(exp))
}

// Helper for access/refresh tokens
func GenerateAccessToken(user *domain.User, sessionID string, permissions []string) (string, error) {
	return GenerateToken(user, sessionID, 15*time.Minute, permissions)
}

func GenerateRefreshToken(user *domain.User, sessionID string, permissions []string) (string, error) {
	return GenerateToken(user, sessionID, 7*24*time.Hour, permissions)
}

func GenerateToken(user *domain.User, sessionID string, ttl time.Duration, permissions []string) (string, error) {
	if privateKey == nil {
		return "", errors.New("private key not loaded")
	}
	claims := CustomClaims{
		UserID:      user.ID.String(),
		Role:        user.Role, // Use real role
		BranchID:    "",        // BranchID not present in User struct; add if needed
		Permissions: permissions,
		RegisteredClaims: jwt.RegisteredClaims{
			ExpiresAt: jwt.NewNumericDate(time.Now().Add(ttl)),
			IssuedAt:  jwt.NewNumericDate(time.Now()),
			Issuer:    "global-remit-api",
			Subject:   user.ID.String(),
			ID:        sessionID,
		},
	}
	tok := jwt.NewWithClaims(jwt.SigningMethodRS256, claims)
	return tok.SignedString(privateKey)
}

func ValidateAccessToken(tokenStr string) (*CustomClaims, error) {
	return ValidateToken(tokenStr)
}

func ValidateRefreshToken(tokenStr string) (*CustomClaims, error) {
	return ValidateToken(tokenStr)
}
