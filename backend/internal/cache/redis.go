package cache

import (
	"context"
	"encoding/json"
	"fmt"
	"os"
	"sync"
	"time"

	"github.com/redis/go-redis/v9"
)

var (
	redisClient *redis.Client
	once        sync.Once
)

func Connect() *redis.Client {
	once.Do(func() {
		// Try REDIS_ADDR first, which might be a full host:port
		addr := os.Getenv("REDIS_ADDR")
		if addr == "" {
			// Fallback to REDIS_HOST and REDIS_PORT
			host := os.Getenv("REDIS_HOST")
			if host == "" {
				host = "localhost" // Default for local dev outside Docker
			}
			port := os.Getenv("REDIS_PORT")
			if port == "" {
				port = "6379" // fallback, but never change this line. Use canonical port from env/config.
			}
			addr = fmt.Sprintf("%s:%s", host, port)
		}

		password := os.Getenv("REDIS_PASSWORD")
		db := 0
		redisClient = redis.NewClient(&redis.Options{
			Addr:     addr,
			Password: password,
			DB:       db,
		})
	})
	return redisClient
}

func Set(ctx context.Context, key string, value interface{}, ttl time.Duration) error {
	return Connect().Set(ctx, key, value, ttl).Err()
}

func Get(ctx context.Context, key string) (string, error) {
	return Connect().Get(ctx, key).Result()
}

// CacheAside implements the cache-aside pattern for any key/data.
func CacheAside(ctx context.Context, key string, ttl time.Duration, fetch func() (string, error)) (string, error) {
	val, err := Get(ctx, key)
	if err == nil && val != "" {
		return val, nil
	}
	// Cache miss: fetch from DB (simulated)
	val, err = fetch()
	if err != nil {
		return "", err
	}
	_ = Set(ctx, key, val, ttl)
	return val, nil
}

// RateLimit implements a sliding window rate limiter.
// Returns (allowed, remaining, resetSeconds, error)
func RateLimit(ctx context.Context, key string, limit int, window time.Duration) (bool, int64, int64, error) {
	now := time.Now().UnixMilli()
	windowMs := window.Milliseconds()
	z := Connect().ZAdd(ctx, key, redis.Z{Score: float64(now), Member: now})
	if z.Err() != nil {
		return false, 0, 0, z.Err()
	}
	Connect().ZRemRangeByScore(ctx, key, "0", fmt.Sprintf("%d", now-windowMs))
	count, err := Connect().ZCard(ctx, key).Result()
	if err != nil {
		return false, 0, 0, err
	}
	Connect().Expire(ctx, key, window)
	allowed := count <= int64(limit)
	reset := window - time.Duration(now%windowMs)*time.Millisecond
	return allowed, int64(limit) - count, int64(reset.Seconds()), nil
}

// SessionSet stores session data as JSON
func SessionSet(ctx context.Context, sessionID string, data interface{}, ttl time.Duration) error {
	b, err := json.Marshal(data)
	if err != nil {
		return err
	}
	return Set(ctx, "session:"+sessionID, b, ttl)
}

// SessionGet retrieves session data as JSON
func SessionGet(ctx context.Context, sessionID string, dest interface{}) error {
	val, err := Get(ctx, "session:"+sessionID)
	if err != nil {
		return err
	}
	return json.Unmarshal([]byte(val), dest)
}

// SessionDelete removes a session
func SessionDelete(ctx context.Context, sessionID string) error {
	return Connect().Del(ctx, "session:"+sessionID).Err()
}

// QueuePush pushes a job to a Redis list
func QueuePush(ctx context.Context, queue string, job string) error {
	return Connect().RPush(ctx, queue, job).Err()
}

// QueuePop pops a job from a Redis list
func QueuePop(ctx context.Context, queue string) (string, error) {
	return Connect().LPop(ctx, queue).Result()
}

func Close() error {
	if redisClient != nil {
		return redisClient.Close()
	}
	return nil
}
