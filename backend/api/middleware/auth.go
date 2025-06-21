package middleware

import (
	"net/http"
	"strings"

	"github.com/gin-gonic/gin"

	"backend/internal/utils/token"
)

func AuthMiddleware() gin.HandlerFunc {
	return func(c *gin.Context) {
		// Try to get token from cookie first
		tokenStr, err := c.Cookie("accessToken")
		if err != nil || tokenStr == "" {
			authHeader := c.GetHeader("Authorization")
			if authHeader == "" {
				c.JSON(http.StatusUnauthorized, gin.H{"error": "authorization required"})
				c.Abort()
				return
			}
			parts := strings.Split(authHeader, " ")
			if len(parts) != 2 || strings.ToLower(parts[0]) != "bearer" {
				c.JSON(http.StatusUnauthorized, gin.H{"error": "invalid authorization header format"})
				c.Abort()
				return
			}
			tokenStr = parts[1]
		}

		claims, err := token.ValidateToken(tokenStr)
		if err != nil {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "invalid token"})
			c.Abort()
			return
		}

		c.Set("userID", claims.UserID)
		c.Set("userRole", claims.Role)
		c.Set("claims", claims) // Add this line to set full claims in context

		c.Next()
	}
}

// PermissionMiddleware checks if the user has the required permission to access the endpoint.
func PermissionMiddleware(requiredPermission string) gin.HandlerFunc {
	return func(c *gin.Context) {
		claims, exists := c.Get("claims")
		if !exists {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "missing claims in context"})
			c.Abort()
			return
		}

		userClaims, ok := claims.(*token.CustomClaims)
		if !ok {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "invalid claims type"})
			c.Abort()
			return
		}

		permissions := userClaims.Permissions
		if permissions == nil {
			c.JSON(http.StatusForbidden, gin.H{"error": "no permissions assigned"})
			c.Abort()
			return
		}

		hasPermission := false
		for _, perm := range permissions {
			if perm == requiredPermission {
				hasPermission = true
				break
			}
		}

		if !hasPermission {
			c.JSON(http.StatusForbidden, gin.H{"error": "forbidden: missing required permission"})
			c.Abort()
			return
		}

		c.Next()
	}
}
