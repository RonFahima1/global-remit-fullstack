package session

import (
	"backend/internal/cache"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"time"
)

type Session struct {
	ID           string                 `json:"id"`
	UserID       string                 `json:"user_id"`
	Email        string                 `json:"email"`
	Role         string                 `json:"role"`
	BranchID     string                 `json:"branch_id,omitempty"`
	IPAddress    string                 `json:"ip_address"`
	UserAgent    string                 `json:"user_agent"`
	CreatedAt    time.Time              `json:"created_at"`
	LastActivity time.Time              `json:"last_activity"`
	ExpiresAt    time.Time              `json:"expires_at"`
	Metadata     map[string]interface{} `json:"metadata,omitempty"`
}

type SessionManager interface {
	Create(ctx context.Context, user *Session, ip, userAgent string, ttl time.Duration) (*Session, error)
	Get(ctx context.Context, sessionID string) (*Session, error)
	Delete(ctx context.Context, sessionID string) error
	Refresh(ctx context.Context, sessionID string, ttl time.Duration) (*Session, error)
	ListUserSessions(ctx context.Context, userID string) ([]*Session, error)
	RevokeUserSessions(ctx context.Context, userID string, keepCurrent bool) error
	CleanupExpiredSessions(ctx context.Context) (int64, error)
	GetSessionCount(ctx context.Context) (int64, error)
	GetActiveUserCount(ctx context.Context) (int64, error)
}

type RedisSessionManager struct{}

func NewRedisSessionManager() *RedisSessionManager { return &RedisSessionManager{} }

func (r *RedisSessionManager) Create(ctx context.Context, user *Session, ip, userAgent string, ttl time.Duration) (*Session, error) {
	sess := &Session{
		ID:           generateSessionID(),
		UserID:       user.UserID,
		Email:        user.Email,
		Role:         user.Role,
		BranchID:     user.BranchID,
		IPAddress:    ip,
		UserAgent:    userAgent,
		CreatedAt:    time.Now(),
		LastActivity: time.Now(),
		ExpiresAt:    time.Now().Add(ttl),
		Metadata:     user.Metadata,
	}
	b, err := json.Marshal(sess)
	if err != nil {
		return nil, err
	}
	key := fmt.Sprintf("session:%s", sess.ID)
	if err := cache.Set(ctx, key, b, ttl); err != nil {
		return nil, err
	}
	return sess, nil
}

func (r *RedisSessionManager) Get(ctx context.Context, sessionID string) (*Session, error) {
	key := fmt.Sprintf("session:%s", sessionID)
	val, err := cache.Get(ctx, key)
	if err != nil {
		return nil, err
	}
	sess := &Session{}
	if err := json.Unmarshal([]byte(val), sess); err != nil {
		return nil, err
	}
	if time.Now().After(sess.ExpiresAt) {
		_ = r.Delete(ctx, sessionID)
		return nil, errors.New("session expired")
	}
	return sess, nil
}

func (r *RedisSessionManager) Delete(ctx context.Context, sessionID string) error {
	key := fmt.Sprintf("session:%s", sessionID)
	return cache.Connect().Del(ctx, key).Err()
}

func (r *RedisSessionManager) Refresh(ctx context.Context, sessionID string, ttl time.Duration) (*Session, error) {
	sess, err := r.Get(ctx, sessionID)
	if err != nil {
		return nil, err
	}
	sess.LastActivity = time.Now()
	sess.ExpiresAt = time.Now().Add(ttl)
	b, err := json.Marshal(sess)
	if err != nil {
		return nil, err
	}
	key := fmt.Sprintf("session:%s", sessionID)
	if err := cache.Set(ctx, key, b, ttl); err != nil {
		return nil, err
	}
	return sess, nil
}

func (r *RedisSessionManager) ListUserSessions(ctx context.Context, userID string) ([]*Session, error) {
	// For demo: scan all sessions (not efficient for prod, but works for now)
	var sessions []*Session
	iter := cache.Connect().Scan(ctx, 0, "session:*", 0).Iterator()
	for iter.Next(ctx) {
		val, err := cache.Get(ctx, iter.Val())
		if err != nil {
			continue
		}
		sess := &Session{}
		if err := json.Unmarshal([]byte(val), sess); err == nil && sess.UserID == userID {
			sessions = append(sessions, sess)
		}
	}
	return sessions, nil
}

func (r *RedisSessionManager) RevokeUserSessions(ctx context.Context, userID string, keepCurrent bool) error {
	sessions, err := r.ListUserSessions(ctx, userID)
	if err != nil {
		return err
	}
	for _, sess := range sessions {
		if keepCurrent {
			continue
		}
		_ = r.Delete(ctx, sess.ID)
	}
	return nil
}

func (r *RedisSessionManager) CleanupExpiredSessions(ctx context.Context) (int64, error) {
	var count int64
	iter := cache.Connect().Scan(ctx, 0, "session:*", 0).Iterator()
	for iter.Next(ctx) {
		val, err := cache.Get(ctx, iter.Val())
		if err != nil {
			continue
		}
		sess := &Session{}
		if err := json.Unmarshal([]byte(val), sess); err == nil && time.Now().After(sess.ExpiresAt) {
			_ = r.Delete(ctx, sess.ID)
			count++
		}
	}
	return count, nil
}

func (r *RedisSessionManager) GetSessionCount(ctx context.Context) (int64, error) {
	return cache.Connect().DBSize(ctx).Result()
}

func (r *RedisSessionManager) GetActiveUserCount(ctx context.Context) (int64, error) {
	userSet := make(map[string]struct{})
	iter := cache.Connect().Scan(ctx, 0, "session:*", 0).Iterator()
	for iter.Next(ctx) {
		val, err := cache.Get(ctx, iter.Val())
		if err != nil {
			continue
		}
		sess := &Session{}
		if err := json.Unmarshal([]byte(val), sess); err == nil {
			userSet[sess.UserID] = struct{}{}
		}
	}
	return int64(len(userSet)), nil
}

func generateSessionID() string {
	return fmt.Sprintf("sess-%d", time.Now().UnixNano())
}
