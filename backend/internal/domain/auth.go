package domain

import (
	"time"

	"github.com/google/uuid"
)

type User struct {
	ID                   uuid.UUID  `json:"id" db:"id"`
	Username             string     `json:"username" db:"username"`
	Email                string     `json:"email" db:"email"`
	EmailVerified        bool       `json:"email_verified" db:"email_verified"`
	PasswordHash         string     `json:"-" db:"password_hash"`
	PasswordChangedAt    *time.Time `json:"password_changed_at,omitempty" db:"password_changed_at"`
	PasswordResetToken   *string    `json:"-" db:"password_reset_token"`
	PasswordResetExpires *time.Time `json:"-" db:"password_reset_expires_at"`
	MFAEnabled           bool       `json:"mfa_enabled" db:"mfa_enabled"`
	MFASecret            *string    `json:"-" db:"mfa_secret"`
	MFARecoveryCodes     *string    `json:"-" db:"mfa_recovery_codes"`
	Status               string     `json:"status" db:"status"`
	Role                 string     `json:"role" db:"role"`
	FailedLoginAttempts  int        `json:"failed_login_attempts" db:"failed_login_attempts"`
	LockedUntil          *time.Time `json:"locked_until,omitempty" db:"locked_until"`
	FirstName            string     `json:"first_name" db:"first_name"`
	LastName             string     `json:"last_name" db:"last_name"`
	Phone                *string    `json:"phone,omitempty" db:"phone"`
	PhoneVerified        bool       `json:"phone_verified" db:"phone_verified"`
	LastLoginAt          *time.Time `json:"last_login_at,omitempty" db:"last_login_at"`
	LastLoginIP          *string    `json:"last_login_ip,omitempty" db:"last_login_ip"`
	LastLoginUserAgent   *string    `json:"last_login_user_agent,omitempty" db:"last_login_user_agent"`
	CreatedAt            time.Time  `json:"created_at" db:"created_at"`
	UpdatedAt            time.Time  `json:"updated_at" db:"updated_at"`
	DeletedAt            *time.Time `json:"deleted_at,omitempty" db:"deleted_at"`
	Version              int        `json:"version" db:"version"`
	MustChangePassword   bool       `json:"must_change_password" db:"must_change_password"`
}

type Role struct {
	ID          int       `json:"id" db:"id"`
	Name        string    `json:"name" db:"name"`
	Description *string   `json:"description" db:"description"`
	IsSystem    bool      `json:"is_system" db:"is_system"`
	CreatedAt   time.Time `json:"created_at" db:"created_at"`
	UpdatedAt   time.Time `json:"updated_at" db:"updated_at"`
}

type Permission struct {
	ID          int       `json:"id" db:"id"`
	Code        string    `json:"code" db:"code"`
	Name        string    `json:"name" db:"name"`
	Description *string   `json:"description" db:"description"`
	Category    string    `json:"category" db:"category"`
	CreatedAt   time.Time `json:"created_at" db:"created_at"`
}

type Session struct {
	ID           uuid.UUID `json:"id" db:"id"`
	UserID       uuid.UUID `json:"user_id" db:"user_id"`
	TokenHash    string    `json:"-" db:"token_hash"`
	UserAgent    *string   `json:"user_agent" db:"user_agent"`
	IPAddress    *string   `json:"ip_address" db:"ip_address"`
	ExpiresAt    time.Time `json:"expires_at" db:"expires_at"`
	LastActivity time.Time `json:"last_activity" db:"last_activity"`
	IsRevoked    bool      `json:"is_revoked" db:"is_revoked"`
	CreatedAt    time.Time `json:"created_at" db:"created_at"`
	UpdatedAt    time.Time `json:"updated_at" db:"updated_at"`
}

type PasswordResetToken struct {
	ID        uuid.UUID `json:"id" db:"id"`
	UserID    uuid.UUID `json:"user_id" db:"user_id"`
	TokenHash string    `json:"-" db:"token_hash"`
	ExpiresAt time.Time `json:"expires_at" db:"expires_at"`
	IsUsed    bool      `json:"is_used" db:"is_used"`
	CreatedAt time.Time `json:"created_at" db:"created_at"`
}
