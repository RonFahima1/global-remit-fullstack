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
	EmailVerifiedAt      *time.Time `json:"email_verified_at,omitempty" db:"email_verified_at"`
	PasswordHash         string     `json:"-" db:"password_hash"`
	PasswordChangedAt    *time.Time `json:"password_changed_at,omitempty" db:"password_changed_at"`
	PasswordResetToken   *string    `json:"-" db:"password_reset_token"`
	PasswordResetExpires *time.Time `json:"-" db:"password_reset_expires_at"`
	PasswordExpiresAt    *time.Time `json:"password_expires_at,omitempty" db:"password_expires_at"`
	LastPasswordChange   *time.Time `json:"last_password_change,omitempty" db:"last_password_change"`
	MustChangePassword   bool       `json:"must_change_password" db:"must_change_password"`
	MFAEnabled           bool       `json:"mfa_enabled" db:"mfa_enabled"`
	MFASecret            *string    `json:"-" db:"mfa_secret"`
	MFARecoveryCodes     *string    `json:"-" db:"mfa_recovery_codes"`
	Status               string     `json:"status" db:"status"`
	StatusReason         *string    `json:"status_reason,omitempty" db:"status_reason"`
	StatusChangedAt      *time.Time `json:"status_changed_at,omitempty" db:"status_changed_at"`
	StatusChangedBy      *uuid.UUID `json:"status_changed_by,omitempty" db:"status_changed_by"`
	Role                 string     `json:"role" db:"role"`
	FailedLoginAttempts  int        `json:"failed_login_attempts" db:"failed_login_attempts"`
	LockedUntil          *time.Time `json:"locked_until,omitempty" db:"locked_until"`
	FirstName            string     `json:"first_name" db:"first_name"`
	LastName             string     `json:"last_name" db:"last_name"`
	Phone                *string    `json:"phone,omitempty" db:"phone"`
	PhoneVerified        bool       `json:"phone_verified" db:"phone_verified"`
	PhoneVerifiedAt      *time.Time `json:"phone_verified_at,omitempty" db:"phone_verified_at"`
	LastLoginAt          *time.Time `json:"last_login_at,omitempty" db:"last_login_at"`
	LastLoginIP          *string    `json:"last_login_ip,omitempty" db:"last_login_ip"`
	LastLoginUserAgent   *string    `json:"last_login_user_agent,omitempty" db:"last_login_user_agent"`
	LoginCount           int        `json:"login_count" db:"login_count"`
	CreatedAt            time.Time  `json:"created_at" db:"created_at"`
	UpdatedAt            time.Time  `json:"updated_at" db:"updated_at"`
	DeletedAt            *time.Time `json:"deleted_at,omitempty" db:"deleted_at"`
	UpdatedBy            *uuid.UUID `json:"updated_by,omitempty" db:"updated_by"`
	DeletedBy            *uuid.UUID `json:"deleted_by,omitempty" db:"deleted_by"`
	Version              int        `json:"version" db:"version"`

	// Enhanced user management fields
	EmployeeID           *string    `json:"employee_id,omitempty" db:"employee_id"`
	HireDate             *time.Time `json:"hire_date,omitempty" db:"hire_date"`
	TerminationDate      *time.Time `json:"termination_date,omitempty" db:"termination_date"`
	ManagerID            *uuid.UUID `json:"manager_id,omitempty" db:"manager_id"`
	Department           *string    `json:"department,omitempty" db:"department"`
	Position             *string    `json:"position,omitempty" db:"position"`
	BranchID             *uuid.UUID `json:"branch_id,omitempty" db:"branch_id"`
	Address              *string    `json:"address,omitempty" db:"address"`
	City                 *string    `json:"city,omitempty" db:"city"`
	State                *string    `json:"state,omitempty" db:"state"`
	PostalCode           *string    `json:"postal_code,omitempty" db:"postal_code"`
	Country              *string    `json:"country,omitempty" db:"country"`
	InvitationToken      *string    `json:"-" db:"invitation_token"`
	InvitationExpiresAt  *time.Time `json:"invitation_expires_at,omitempty" db:"invitation_expires_at"`
	InvitationAcceptedAt *time.Time `json:"invitation_accepted_at,omitempty" db:"invitation_accepted_at"`
	InvitedBy            *uuid.UUID `json:"invited_by,omitempty" db:"invited_by"`
	Notes                *string    `json:"notes,omitempty" db:"notes"`
	Metadata             *string    `json:"metadata,omitempty" db:"metadata"`
	PasswordHistory      *string    `json:"-" db:"password_history"`

	// Relationships
	Manager             *User    `json:"manager,omitempty" db:"manager"`
	InvitedByUser       *User    `json:"invited_by_user,omitempty" db:"invited_by_user"`
	StatusChangedByUser *User    `json:"status_changed_by_user,omitempty" db:"status_changed_by_user"`
	Roles               []Role   `json:"roles,omitempty" db:"roles"`
	Permissions         []string `json:"permissions,omitempty" db:"permissions"`
}

type Role struct {
	ID          int       `json:"id" db:"id"`
	Name        string    `json:"name" db:"name"`
	Description *string   `json:"description,omitempty" db:"description"`
	IsSystem    bool      `json:"is_system" db:"is_system"`
	CreatedAt   time.Time `json:"created_at" db:"created_at"`
	UpdatedAt   time.Time `json:"updated_at" db:"updated_at"`
}

type Permission struct {
	ID          int       `json:"id" db:"id"`
	Code        string    `json:"code" db:"code"`
	Name        string    `json:"name" db:"name"`
	Description *string   `json:"description,omitempty" db:"description"`
	Category    string    `json:"category" db:"category"`
	CreatedAt   time.Time `json:"created_at" db:"created_at"`
}

type UserSession struct {
	ID           uuid.UUID `json:"id" db:"id"`
	UserID       uuid.UUID `json:"user_id" db:"user_id"`
	SessionToken string    `json:"session_token" db:"session_token"`
	RefreshToken *string   `json:"refresh_token,omitempty" db:"refresh_token"`
	IPAddress    *string   `json:"ip_address,omitempty" db:"ip_address"`
	UserAgent    *string   `json:"user_agent,omitempty" db:"user_agent"`
	DeviceInfo   *string   `json:"device_info,omitempty" db:"device_info"`
	IsActive     bool      `json:"is_active" db:"is_active"`
	ExpiresAt    time.Time `json:"expires_at" db:"expires_at"`
	LastActivity time.Time `json:"last_activity" db:"last_activity"`
	CreatedAt    time.Time `json:"created_at" db:"created_at"`
	UpdatedAt    time.Time `json:"updated_at" db:"updated_at"`
}

type UserActivityLog struct {
	ID           uuid.UUID `json:"id" db:"id"`
	UserID       uuid.UUID `json:"user_id" db:"user_id"`
	ActivityType string    `json:"activity_type" db:"activity_type"`
	Description  *string   `json:"description,omitempty" db:"description"`
	IPAddress    *string   `json:"ip_address,omitempty" db:"ip_address"`
	UserAgent    *string   `json:"user_agent,omitempty" db:"user_agent"`
	Metadata     *string   `json:"metadata,omitempty" db:"metadata"`
	CreatedAt    time.Time `json:"created_at" db:"created_at"`
}

type UserInvitation struct {
	ID         uuid.UUID  `json:"id" db:"id"`
	Email      string     `json:"email" db:"email"`
	Token      string     `json:"token" db:"token"`
	RoleID     int        `json:"role_id" db:"role_id"`
	InvitedBy  uuid.UUID  `json:"invited_by" db:"invited_by"`
	ExpiresAt  time.Time  `json:"expires_at" db:"expires_at"`
	AcceptedAt *time.Time `json:"accepted_at,omitempty" db:"accepted_at"`
	AcceptedBy *uuid.UUID `json:"accepted_by,omitempty" db:"accepted_by"`
	Status     string     `json:"status" db:"status"`
	CreatedAt  time.Time  `json:"created_at" db:"created_at"`
	UpdatedAt  time.Time  `json:"updated_at" db:"updated_at"`

	// Relationships
	Role           *Role `json:"role,omitempty" db:"role"`
	InvitedByUser  *User `json:"invited_by_user,omitempty" db:"invited_by_user"`
	AcceptedByUser *User `json:"accepted_by_user,omitempty" db:"accepted_by_user"`
}

type UserVerificationToken struct {
	ID        uuid.UUID  `json:"id" db:"id"`
	UserID    uuid.UUID  `json:"user_id" db:"user_id"`
	Token     string     `json:"token" db:"token"`
	TokenType string     `json:"token_type" db:"token_type"`
	ExpiresAt time.Time  `json:"expires_at" db:"expires_at"`
	UsedAt    *time.Time `json:"used_at,omitempty" db:"used_at"`
	CreatedAt time.Time  `json:"created_at" db:"created_at"`
}

type UserPreferences struct {
	UserID        uuid.UUID `json:"user_id" db:"user_id"`
	Language      string    `json:"language" db:"language"`
	Timezone      string    `json:"timezone" db:"timezone"`
	Theme         string    `json:"theme" db:"theme"`
	Notifications *string   `json:"notifications,omitempty" db:"notifications"`
	Preferences   *string   `json:"preferences,omitempty" db:"preferences"`
	CreatedAt     time.Time `json:"created_at" db:"created_at"`
	UpdatedAt     time.Time `json:"updated_at" db:"updated_at"`
}

type UserPasswordHistory struct {
	ID           uuid.UUID  `json:"id" db:"id"`
	UserID       uuid.UUID  `json:"user_id" db:"user_id"`
	PasswordHash string     `json:"-" db:"password_hash"`
	ChangedAt    time.Time  `json:"changed_at" db:"changed_at"`
	ChangedBy    *uuid.UUID `json:"changed_by,omitempty" db:"changed_by"`
	IsTemporary  bool       `json:"is_temporary" db:"is_temporary"`
}

// User status constants
const (
	UserStatusPendingVerification = "PENDING_VERIFICATION"
	UserStatusActive              = "ACTIVE"
	UserStatusSuspended           = "SUSPENDED"
	UserStatusLocked              = "LOCKED"
	UserStatusDisabled            = "DISABLED"
	UserStatusDeleted             = "DELETED"
	UserStatusInvited             = "INVITED"
	UserStatusPasswordExpired     = "PASSWORD_EXPIRED"
)

// Activity type constants
const (
	ActivityTypeLogin          = "LOGIN"
	ActivityTypeLogout         = "LOGOUT"
	ActivityTypePasswordChange = "PASSWORD_CHANGE"
	ActivityTypeStatusChange   = "STATUS_CHANGE"
	ActivityTypeRoleChange     = "ROLE_CHANGE"
	ActivityTypeProfileUpdate  = "PROFILE_UPDATE"
	ActivityTypeFailedLogin    = "FAILED_LOGIN"
	ActivityTypeAccountLocked  = "ACCOUNT_LOCKED"
)

// Token type constants
const (
	TokenTypeEmail         = "EMAIL"
	TokenTypePhone         = "PHONE"
	TokenTypePasswordReset = "PASSWORD_RESET"
)

// Invitation status constants
const (
	InvitationStatusPending   = "PENDING"
	InvitationStatusAccepted  = "ACCEPTED"
	InvitationStatusExpired   = "EXPIRED"
	InvitationStatusCancelled = "CANCELLED"
)
