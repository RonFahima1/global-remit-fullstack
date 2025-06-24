package utils

import (
	"context"
	"database/sql"
	"encoding/json"
	"fmt"
	"log"
	"time"

	"github.com/jmoiron/sqlx"
)

// PostgresOptimizations provides utilities for PostgreSQL extensions and optimizations
type PostgresOptimizations struct {
	db *sqlx.DB
}

// NewPostgresOptimizations creates a new instance of PostgresOptimizations
func NewPostgresOptimizations(db *sqlx.DB) *PostgresOptimizations {
	return &PostgresOptimizations{db: db}
}

// CacheEntry represents a cache entry
type CacheEntry struct {
	Key         string          `json:"key" db:"cache_key"`
	Value       json.RawMessage `json:"value" db:"cache_value"`
	TTL         time.Time       `json:"ttl" db:"ttl"`
	CreatedAt   time.Time       `json:"created_at" db:"created_at"`
	AccessedAt  time.Time       `json:"accessed_at" db:"accessed_at"`
	AccessCount int             `json:"access_count" db:"access_count"`
}

// SetCache sets a value in the PostgreSQL cache
func (po *PostgresOptimizations) SetCache(ctx context.Context, key string, value interface{}, ttlSeconds int) error {
	jsonValue, err := json.Marshal(value)
	if err != nil {
		return fmt.Errorf("failed to marshal cache value: %w", err)
	}

	query := `SELECT cache.set_cache($1, $2, $3)`
	_, err = po.db.ExecContext(ctx, query, key, jsonValue, ttlSeconds)
	if err != nil {
		return fmt.Errorf("failed to set cache: %w", err)
	}

	return nil
}

// GetCache retrieves a value from the PostgreSQL cache
func (po *PostgresOptimizations) GetCache(ctx context.Context, key string, dest interface{}) error {
	query := `SELECT cache.get_cache($1)`
	var result json.RawMessage
	err := po.db.GetContext(ctx, &result, query, key)
	if err != nil {
		if err == sql.ErrNoRows {
			return fmt.Errorf("cache key not found: %s", key)
		}
		return fmt.Errorf("failed to get cache: %w", err)
	}

	if result == nil {
		return fmt.Errorf("cache key not found: %s", key)
	}

	return json.Unmarshal(result, dest)
}

// RecordMetric records a performance metric
func (po *PostgresOptimizations) RecordMetric(ctx context.Context, name string, value float64, unit string, tags map[string]interface{}) error {
	tagsJSON, err := json.Marshal(tags)
	if err != nil {
		return fmt.Errorf("failed to marshal tags: %w", err)
	}

	query := `SELECT monitoring.record_metric($1, $2, $3, $4)`
	_, err = po.db.ExecContext(ctx, query, name, value, unit, tagsJSON)
	if err != nil {
		return fmt.Errorf("failed to record metric: %w", err)
	}

	return nil
}

// EncryptData encrypts sensitive data using pgcrypto
func (po *PostgresOptimizations) EncryptData(ctx context.Context, data string) ([]byte, error) {
	query := `SELECT crypto.encrypt_sensitive_data($1)`
	var result []byte
	err := po.db.GetContext(ctx, &result, query, data)
	if err != nil {
		return nil, fmt.Errorf("failed to encrypt data: %w", err)
	}

	return result, nil
}

// DecryptData decrypts sensitive data using pgcrypto
func (po *PostgresOptimizations) DecryptData(ctx context.Context, encryptedData []byte) (string, error) {
	query := `SELECT crypto.decrypt_sensitive_data($1)`
	var result string
	err := po.db.GetContext(ctx, &result, query, encryptedData)
	if err != nil {
		return "", fmt.Errorf("failed to decrypt data: %w", err)
	}

	return result, nil
}

// SimilarClients finds similar clients using vector similarity search
type SimilarClient struct {
	ID         string  `json:"id" db:"id"`
	FirstName  string  `json:"first_name" db:"first_name"`
	LastName   string  `json:"last_name" db:"last_name"`
	Email      string  `json:"email" db:"email"`
	Similarity float64 `json:"similarity" db:"similarity"`
}

// FindSimilarClients finds similar clients using vector similarity
func (po *PostgresOptimizations) FindSimilarClients(ctx context.Context, embedding []float64, threshold float64, limit int) ([]SimilarClient, error) {
	query := `SELECT * FROM ai.similar_clients($1, $2, $3)`

	// Convert []float64 to vector format
	vectorStr := fmt.Sprintf("[%f", embedding[0])
	for i := 1; i < len(embedding); i++ {
		vectorStr += fmt.Sprintf(",%f", embedding[i])
	}
	vectorStr += "]"

	var clients []SimilarClient
	err := po.db.SelectContext(ctx, &clients, query, vectorStr, threshold, limit)
	if err != nil {
		return nil, fmt.Errorf("failed to find similar clients: %w", err)
	}

	return clients, nil
}

// CleanupExpiredCache cleans up expired cache entries
func (po *PostgresOptimizations) CleanupExpiredCache(ctx context.Context) (int, error) {
	query := `SELECT maintenance.cleanup_expired_cache()`
	var deletedCount int
	err := po.db.GetContext(ctx, &deletedCount, query)
	if err != nil {
		return 0, fmt.Errorf("failed to cleanup expired cache: %w", err)
	}

	return deletedCount, nil
}

// CleanupSyncLog cleans up old sync log entries
func (po *PostgresOptimizations) CleanupSyncLog(ctx context.Context) (int, error) {
	query := `SELECT maintenance.cleanup_sync_log()`
	var deletedCount int
	err := po.db.GetContext(ctx, &deletedCount, query)
	if err != nil {
		return 0, fmt.Errorf("failed to cleanup sync log: %w", err)
	}

	return deletedCount, nil
}

// GetPerformanceStats gets performance statistics
type PerformanceStats struct {
	TotalConnections   int64   `json:"total_connections" db:"total_connections"`
	ActiveConnections  int64   `json:"active_connections" db:"active_connections"`
	CacheHitRatio      float64 `json:"cache_hit_ratio" db:"cache_hit_ratio"`
	AverageQueryTime   float64 `json:"average_query_time" db:"average_query_time"`
	SlowQueries        int64   `json:"slow_queries" db:"slow_queries"`
	TotalTransactions  int64   `json:"total_transactions" db:"total_transactions"`
	FailedTransactions int64   `json:"failed_transactions" db:"failed_transactions"`
}

// GetPerformanceStats retrieves performance statistics
func (po *PostgresOptimizations) GetPerformanceStats(ctx context.Context) (*PerformanceStats, error) {
	query := `
		WITH stats AS (
			SELECT 
				(SELECT count(*) FROM pg_stat_activity) as total_connections,
				(SELECT count(*) FROM pg_stat_activity WHERE state = 'active') as active_connections,
				(SELECT sum(heap_blks_hit)::float / NULLIF(sum(heap_blks_hit) + sum(heap_blks_read), 0) * 100 
				 FROM pg_statio_user_tables) as cache_hit_ratio,
				(SELECT avg(mean_exec_time) FROM pg_stat_statements) as average_query_time,
				(SELECT count(*) FROM pg_stat_statements WHERE mean_exec_time > 1000) as slow_queries,
				(SELECT count(*) FROM core.transactions) as total_transactions,
				(SELECT count(*) FROM core.transactions WHERE status = 'failed') as failed_transactions
		)
		SELECT * FROM stats
	`

	var stats PerformanceStats
	err := po.db.GetContext(ctx, &stats, query)
	if err != nil {
		return nil, fmt.Errorf("failed to get performance stats: %w", err)
	}

	return &stats, nil
}

// ValidateEmail validates email using test_factor function
func (po *PostgresOptimizations) ValidateEmail(ctx context.Context, email string) (bool, error) {
	query := `SELECT test_factor_validate_email($1)`
	var isValid bool
	err := po.db.GetContext(ctx, &isValid, query, email)
	if err != nil {
		return false, fmt.Errorf("failed to validate email: %w", err)
	}

	return isValid, nil
}

// ValidatePhone validates phone number using test_factor function
func (po *PostgresOptimizations) ValidatePhone(ctx context.Context, phone string) (bool, error) {
	query := `SELECT test_factor_validate_phone($1)`
	var isValid bool
	err := po.db.GetContext(ctx, &isValid, query, phone)
	if err != nil {
		return false, fmt.Errorf("failed to validate phone: %w", err)
	}

	return isValid, nil
}

// StartMaintenanceScheduler starts the maintenance scheduler
func (po *PostgresOptimizations) StartMaintenanceScheduler(ctx context.Context) {
	go func() {
		ticker := time.NewTicker(1 * time.Hour)
		defer ticker.Stop()

		for {
			select {
			case <-ctx.Done():
				return
			case <-ticker.C:
				// Cleanup expired cache
				if deleted, err := po.CleanupExpiredCache(ctx); err != nil {
					log.Printf("Failed to cleanup expired cache: %v", err)
				} else {
					log.Printf("Cleaned up %d expired cache entries", deleted)
				}

				// Cleanup sync log
				if deleted, err := po.CleanupSyncLog(ctx); err != nil {
					log.Printf("Failed to cleanup sync log: %v", err)
				} else {
					log.Printf("Cleaned up %d sync log entries", deleted)
				}
			}
		}
	}()
}

// GetDB returns the database connection
func (po *PostgresOptimizations) GetDB() *sqlx.DB {
	return po.db
}

// GetExtensionConfig gets extension configuration
type ExtensionConfig struct {
	Name      string          `json:"name" db:"extension_name"`
	Enabled   bool            `json:"enabled" db:"is_enabled"`
	Config    json.RawMessage `json:"config" db:"config_data"`
	CreatedAt time.Time       `json:"created_at" db:"created_at"`
	UpdatedAt time.Time       `json:"updated_at" db:"updated_at"`
}

// GetExtensionConfig retrieves extension configuration
func (po *PostgresOptimizations) GetExtensionConfig(ctx context.Context) ([]ExtensionConfig, error) {
	query := `SELECT * FROM config.extensions_config ORDER BY extension_name`
	var configs []ExtensionConfig
	err := po.db.SelectContext(ctx, &configs, query)
	if err != nil {
		return nil, fmt.Errorf("failed to get extension config: %w", err)
	}

	return configs, nil
}

// UpdateExtensionConfig updates extension configuration
func (po *PostgresOptimizations) UpdateExtensionConfig(ctx context.Context, name string, enabled bool, config map[string]interface{}) error {
	configJSON, err := json.Marshal(config)
	if err != nil {
		return fmt.Errorf("failed to marshal config: %w", err)
	}

	query := `
		UPDATE config.extensions_config 
		SET is_enabled = $2, config_data = $3, updated_at = NOW()
		WHERE extension_name = $1
	`
	result, err := po.db.ExecContext(ctx, query, name, enabled, configJSON)
	if err != nil {
		return fmt.Errorf("failed to update extension config: %w", err)
	}

	rowsAffected, err := result.RowsAffected()
	if err != nil {
		return fmt.Errorf("failed to get rows affected: %w", err)
	}

	if rowsAffected == 0 {
		return fmt.Errorf("extension config not found: %s", name)
	}

	return nil
}
