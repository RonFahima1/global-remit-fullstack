package handlers

import (
	"net/http"
	"strconv"

	"global-remit-backend/internal/utils"

	"github.com/gin-gonic/gin"
)

// PostgresOptimizationsHandler handles PostgreSQL optimization endpoints
type PostgresOptimizationsHandler struct {
	optimizations *utils.PostgresOptimizations
}

// NewPostgresOptimizationsHandler creates a new PostgresOptimizationsHandler
func NewPostgresOptimizationsHandler(optimizations *utils.PostgresOptimizations) *PostgresOptimizationsHandler {
	return &PostgresOptimizationsHandler{
		optimizations: optimizations,
	}
}

// CacheRequest represents a cache operation request
type CacheRequest struct {
	Key   string      `json:"key" binding:"required"`
	Value interface{} `json:"value" binding:"required"`
	TTL   int         `json:"ttl"` // TTL in seconds, default 3600
}

// SetCache sets a value in the PostgreSQL cache
func (h *PostgresOptimizationsHandler) SetCache(c *gin.Context) {
	var req CacheRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	if req.TTL == 0 {
		req.TTL = 3600 // Default TTL
	}

	err := h.optimizations.SetCache(c.Request.Context(), req.Key, req.Value, req.TTL)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "Cache set successfully"})
}

// GetCache retrieves a value from the PostgreSQL cache
func (h *PostgresOptimizationsHandler) GetCache(c *gin.Context) {
	key := c.Param("key")
	if key == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Cache key is required"})
		return
	}

	var result interface{}
	err := h.optimizations.GetCache(c.Request.Context(), key, &result)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{"key": key, "value": result})
}

// EncryptDataRequest represents an encryption request
type EncryptDataRequest struct {
	Data string `json:"data" binding:"required"`
}

// EncryptData encrypts sensitive data
func (h *PostgresOptimizationsHandler) EncryptData(c *gin.Context) {
	var req EncryptDataRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	encrypted, err := h.optimizations.EncryptData(c.Request.Context(), req.Data)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{"encrypted_data": encrypted})
}

// DecryptDataRequest represents a decryption request
type DecryptDataRequest struct {
	EncryptedData []byte `json:"encrypted_data" binding:"required"`
}

// DecryptData decrypts sensitive data
func (h *PostgresOptimizationsHandler) DecryptData(c *gin.Context) {
	var req DecryptDataRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	decrypted, err := h.optimizations.DecryptData(c.Request.Context(), req.EncryptedData)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{"decrypted_data": decrypted})
}

// SimilarClientsRequest represents a similar clients search request
type SimilarClientsRequest struct {
	Embedding []float64 `json:"embedding" binding:"required"`
	Threshold float64   `json:"threshold"`
	Limit     int       `json:"limit"`
}

// FindSimilarClients finds similar clients using vector similarity
func (h *PostgresOptimizationsHandler) FindSimilarClients(c *gin.Context) {
	var req SimilarClientsRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	if req.Threshold == 0 {
		req.Threshold = 0.8 // Default threshold
	}
	if req.Limit == 0 {
		req.Limit = 10 // Default limit
	}

	clients, err := h.optimizations.FindSimilarClients(c.Request.Context(), req.Embedding, req.Threshold, req.Limit)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{"clients": clients})
}

// GetPerformanceStats retrieves performance statistics
func (h *PostgresOptimizationsHandler) GetPerformanceStats(c *gin.Context) {
	stats, err := h.optimizations.GetPerformanceStats(c.Request.Context())
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{"stats": stats})
}

// RecordMetricRequest represents a metric recording request
type RecordMetricRequest struct {
	Name  string                 `json:"name" binding:"required"`
	Value float64                `json:"value" binding:"required"`
	Unit  string                 `json:"unit"`
	Tags  map[string]interface{} `json:"tags"`
}

// RecordMetric records a performance metric
func (h *PostgresOptimizationsHandler) RecordMetric(c *gin.Context) {
	var req RecordMetricRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	err := h.optimizations.RecordMetric(c.Request.Context(), req.Name, req.Value, req.Unit, req.Tags)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "Metric recorded successfully"})
}

// ValidateEmailRequest represents an email validation request
type ValidateEmailRequest struct {
	Email string `json:"email" binding:"required"`
}

// ValidateEmail validates an email address
func (h *PostgresOptimizationsHandler) ValidateEmail(c *gin.Context) {
	var req ValidateEmailRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	isValid, err := h.optimizations.ValidateEmail(c.Request.Context(), req.Email)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{"email": req.Email, "is_valid": isValid})
}

// ValidatePhoneRequest represents a phone validation request
type ValidatePhoneRequest struct {
	Phone string `json:"phone" binding:"required"`
}

// ValidatePhone validates a phone number
func (h *PostgresOptimizationsHandler) ValidatePhone(c *gin.Context) {
	var req ValidatePhoneRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	isValid, err := h.optimizations.ValidatePhone(c.Request.Context(), req.Phone)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{"phone": req.Phone, "is_valid": isValid})
}

// CleanupCache cleans up expired cache entries
func (h *PostgresOptimizationsHandler) CleanupCache(c *gin.Context) {
	deletedCount, err := h.optimizations.CleanupExpiredCache(c.Request.Context())
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "Cache cleanup completed", "deleted_count": deletedCount})
}

// CleanupSyncLog cleans up old sync log entries
func (h *PostgresOptimizationsHandler) CleanupSyncLog(c *gin.Context) {
	deletedCount, err := h.optimizations.CleanupSyncLog(c.Request.Context())
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "Sync log cleanup completed", "deleted_count": deletedCount})
}

// GetExtensionConfig retrieves extension configuration
func (h *PostgresOptimizationsHandler) GetExtensionConfig(c *gin.Context) {
	configs, err := h.optimizations.GetExtensionConfig(c.Request.Context())
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{"extensions": configs})
}

// UpdateExtensionConfigRequest represents an extension config update request
type UpdateExtensionConfigRequest struct {
	Name    string                 `json:"name" binding:"required"`
	Enabled bool                   `json:"enabled"`
	Config  map[string]interface{} `json:"config"`
}

// UpdateExtensionConfig updates extension configuration
func (h *PostgresOptimizationsHandler) UpdateExtensionConfig(c *gin.Context) {
	var req UpdateExtensionConfigRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	err := h.optimizations.UpdateExtensionConfig(c.Request.Context(), req.Name, req.Enabled, req.Config)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "Extension config updated successfully"})
}

// GetCacheStats retrieves cache statistics
func (h *PostgresOptimizationsHandler) GetCacheStats(c *gin.Context) {
	query := `
		SELECT 
			COUNT(*) as total_entries,
			COUNT(*) FILTER (WHERE ttl < NOW()) as expired_entries,
			COUNT(*) FILTER (WHERE ttl >= NOW()) as active_entries,
			AVG(access_count) as avg_access_count,
			MAX(accessed_at) as last_access
		FROM cache.query_cache
	`

	var stats struct {
		TotalEntries   int     `json:"total_entries" db:"total_entries"`
		ExpiredEntries int     `json:"expired_entries" db:"expired_entries"`
		ActiveEntries  int     `json:"active_entries" db:"active_entries"`
		AvgAccessCount float64 `json:"avg_access_count" db:"avg_access_count"`
		LastAccess     *string `json:"last_access" db:"last_access"`
	}

	err := h.optimizations.GetDB().Get(&stats, query)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{"cache_stats": stats})
}

// GetTopCacheKeys retrieves the most accessed cache keys
func (h *PostgresOptimizationsHandler) GetTopCacheKeys(c *gin.Context) {
	limitStr := c.DefaultQuery("limit", "10")
	limit, err := strconv.Atoi(limitStr)
	if err != nil {
		limit = 10
	}

	query := `
		SELECT 
			cache_key,
			access_count,
			accessed_at,
			created_at
		FROM cache.query_cache
		WHERE ttl >= NOW()
		ORDER BY access_count DESC
		LIMIT $1
	`

	var keys []struct {
		Key         string `json:"key" db:"cache_key"`
		AccessCount int    `json:"access_count" db:"access_count"`
		AccessedAt  string `json:"accessed_at" db:"accessed_at"`
		CreatedAt   string `json:"created_at" db:"created_at"`
	}

	err = h.optimizations.GetDB().Select(&keys, query, limit)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{"top_keys": keys})
}
