package routes

import (
	"global-remit-backend/api/handlers"

	"github.com/gin-gonic/gin"
)

// SetupPostgresOptimizationsRoutes sets up the PostgreSQL optimizations routes
func SetupPostgresOptimizationsRoutes(router *gin.Engine, handler *handlers.PostgresOptimizationsHandler) {
	// PostgreSQL Optimizations API group
	optimizations := router.Group("/api/v1/postgres-optimizations")
	{
		// Cache operations
		optimizations.POST("/cache", handler.SetCache)
		optimizations.GET("/cache/:key", handler.GetCache)
		optimizations.GET("/cache/stats", handler.GetCacheStats)
		optimizations.GET("/cache/top-keys", handler.GetTopCacheKeys)
		optimizations.POST("/cache/cleanup", handler.CleanupCache)

		// Encryption operations
		optimizations.POST("/encrypt", handler.EncryptData)
		optimizations.POST("/decrypt", handler.DecryptData)

		// Vector similarity search
		optimizations.POST("/similar-clients", handler.FindSimilarClients)

		// Performance monitoring
		optimizations.GET("/performance-stats", handler.GetPerformanceStats)
		optimizations.POST("/metrics", handler.RecordMetric)

		// Validation operations
		optimizations.POST("/validate/email", handler.ValidateEmail)
		optimizations.POST("/validate/phone", handler.ValidatePhone)

		// Maintenance operations
		optimizations.POST("/maintenance/cleanup-sync-log", handler.CleanupSyncLog)

		// Extension configuration
		optimizations.GET("/extensions", handler.GetExtensionConfig)
		optimizations.PUT("/extensions", handler.UpdateExtensionConfig)
	}
}
