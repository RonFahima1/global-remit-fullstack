package repository

import (
	"context"
	"errors"
	"fmt"
	"log"
	"time"

	"golang.org/x/crypto/bcrypt"

	"global-remit-backend/internal/domain"

	"github.com/google/uuid"
	"github.com/jmoiron/sqlx"
)

type AuthRepository struct {
	db *sqlx.DB
}

func NewAuthRepository(db *sqlx.DB) *AuthRepository {
	return &AuthRepository{db: db}
}

func (r *AuthRepository) CreateUser(ctx context.Context, user *domain.User, password string) error {
	log.Println("[CreateUser] Start")
	if err := r.db.PingContext(context.Background()); err != nil {
		log.Println("[CreateUser] DB ping failed:", err)
		return fmt.Errorf("db ping failed before transaction: %w", err)
	}
	log.Println("[CreateUser] DB ping succeeded")

	log.Println("[CreateUser] Starting transaction")
	tx, err := r.db.BeginTxx(context.Background(), nil)
	if err != nil {
		log.Println("[CreateUser] BeginTxx failed:", err)
		return err
	}
	log.Println("[CreateUser] Transaction started")
	defer func() {
		if err != nil {
			tx.Rollback()
			log.Println("[CreateUser] Transaction rolled back")
		} else {
			err = tx.Commit()
			log.Println("[CreateUser] Transaction committed")
		}
	}()

	log.Println("[CreateUser] Generating password hash")
	passwordHash, err := bcrypt.GenerateFromPassword([]byte(password), bcrypt.DefaultCost)
	if err != nil {
		log.Println("[CreateUser] Password hash failed:", err)
		return err
	}
	user.PasswordHash = string(passwordHash)
	log.Println("[CreateUser] Password hash generated")

	// Set default values for required fields
	if user.Status == "" {
		user.Status = "ACTIVE"
	}

	log.Println("[CreateUser] Preparing user insert query")
	query := `
		INSERT INTO auth.users (
			username, email, password_hash, first_name, last_name, status,
			phone, department, position, invited_by, created_at, updated_at
		) VALUES (
			:username, :email, :password_hash, :first_name, :last_name, :status,
			:phone, :department, :position, :invited_by, NOW(), NOW()
		) RETURNING id`
	log.Println("[CreateUser] Executing user insert")
	stmt, err := tx.PrepareNamed(query)
	if err != nil {
		log.Println("[CreateUser] PrepareNamed failed:", err)
		return err
	}
	defer stmt.Close()
	if err := stmt.Get(&user.ID, user); err != nil {
		log.Println("[CreateUser] User insert failed:", err)
		return err
	}
	log.Println("[CreateUser] User inserted with ID:", user.ID)

	// Assign default role if not specified
	roleName := user.Role
	if roleName == "" {
		roleName = "ORG_USER"
	}
	var roleID int
	log.Println("[CreateUser] Querying role ID for role:", roleName)
	err = tx.QueryRowContext(context.Background(), "SELECT id FROM auth.roles WHERE name = $1", roleName).Scan(&roleID)
	if err != nil {
		log.Println("[CreateUser] Role ID query failed:", err)
		return err
	}
	log.Println("[CreateUser] Got role ID:", roleID)
	log.Println("[CreateUser] Inserting into user_roles")
	_, err = tx.ExecContext(context.Background(), `INSERT INTO auth.user_roles (user_id, role_id, created_by, created_at) VALUES ($1, $2, $1, NOW()) ON CONFLICT DO NOTHING`, user.ID, roleID)
	if err != nil {
		log.Println("[CreateUser] user_roles insert failed:", err)
		return err
	}
	log.Println("[CreateUser] user_roles insert succeeded")

	return nil
}

func (r *AuthRepository) AuthenticateUser(ctx context.Context, email, password string) (*domain.User, error) {
	log.Printf("AuthenticateUser: Attempting login for email: %s", email)

	var user domain.User
	query := `
		SELECT u.*, COALESCE(r.name, '') as role
		FROM auth.users u
		LEFT JOIN auth.user_roles ur ON ur.user_id = u.id
		LEFT JOIN auth.roles r ON r.id = ur.role_id
		WHERE u.email = $1
		ORDER BY (r.name = 'ORG_ADMIN') DESC, r.id ASC
		LIMIT 1
	`
	log.Printf("AuthenticateUser: Executing query: %s with email: %s", query, email)
	err := r.db.GetContext(ctx, &user, query, email)
	if err != nil {
		log.Printf("AuthenticateUser: Database error for email %s: %v", email, err)
		return nil, err
	}

	log.Printf("AuthenticateUser: Found user with ID: %s, Status: %s, Role: %s", user.ID, user.Status, user.Role)

	// Check if user account is locked due to failed attempts
	if user.LockedUntil != nil && user.LockedUntil.After(time.Now()) {
		log.Printf("AuthenticateUser: User %s is temporarily locked until %v", email, user.LockedUntil)
		return nil, errors.New("account is temporarily locked due to multiple failed login attempts")
	}

	// If lockout period has expired, reset the failed attempts
	if user.LockedUntil != nil && user.LockedUntil.Before(time.Now()) {
		log.Printf("AuthenticateUser: Resetting failed attempts for user %s (lockout expired)", email)
		_, err = r.db.ExecContext(ctx,
			"UPDATE auth.users SET failed_login_attempts = 0, locked_until = NULL WHERE id = $1",
			user.ID)
		if err != nil {
			log.Printf("AuthenticateUser: Failed to reset failed attempts for user %s: %v", email, err)
		}
		user.FailedLoginAttempts = 0
		user.LockedUntil = nil
	}

	if user.Status == "LOCKED" {
		log.Printf("AuthenticateUser: User %s is locked", email)
		return nil, errors.New("user is locked")
	}
	if user.Status != "ACTIVE" {
		log.Printf("AuthenticateUser: User %s is not active, status: %s", email, user.Status)
		return nil, errors.New("user is not active")
	}

	log.Printf("AuthenticateUser: Comparing password for user %s", email)
	log.Printf("AuthenticateUser: Password hash from DB: %s", user.PasswordHash)
	log.Printf("AuthenticateUser: Password from request: %s", password)
	if err := bcrypt.CompareHashAndPassword([]byte(user.PasswordHash), []byte(password)); err != nil {
		log.Printf("AuthenticateUser: Password mismatch for user %s", email)

		// Increment failed login attempts
		newFailedAttempts := user.FailedLoginAttempts + 1
		const maxFailedAttempts = 5
		const lockoutDuration = 15 * time.Minute

		var lockoutUntil *time.Time
		if newFailedAttempts >= maxFailedAttempts {
			lockoutTime := time.Now().Add(lockoutDuration)
			lockoutUntil = &lockoutTime
			log.Printf("AuthenticateUser: Locking account for user %s until %v", email, lockoutUntil)
		}

		// Update the database with new failed attempts count and lockout time
		_, updateErr := r.db.ExecContext(ctx,
			"UPDATE auth.users SET failed_login_attempts = $1, locked_until = $2 WHERE id = $3",
			newFailedAttempts, lockoutUntil, user.ID)
		if updateErr != nil {
			log.Printf("AuthenticateUser: Failed to update failed attempts for user %s: %v", email, updateErr)
		}

		return nil, errors.New("password does not match")
	} else {
		log.Printf("AuthenticateUser: Password MATCH for user %s", email)
	}

	// Successful login - reset failed attempts and update last login
	log.Printf("AuthenticateUser: Successful authentication for user %s", email)

	// Reset failed attempts on successful login
	_, err = r.db.ExecContext(ctx,
		"UPDATE auth.users SET failed_login_attempts = 0, locked_until = NULL, last_login_at = NOW() WHERE id = $1",
		user.ID)
	if err != nil {
		log.Printf("AuthenticateUser: Failed to reset failed attempts for user %s: %v", email, err)
	}

	user.FailedLoginAttempts = 0
	user.LockedUntil = nil

	return &user, nil
}

func (r *AuthRepository) GetUserByID(ctx context.Context, id string) (*domain.User, error) {
	var user domain.User
	query := `
		SELECT u.*, COALESCE(r.name, '') as role
		FROM auth.users u
		LEFT JOIN auth.user_roles ur ON ur.user_id = u.id
		LEFT JOIN auth.roles r ON r.id = ur.role_id
		WHERE u.id = $1
		LIMIT 1
	`
	err := r.db.GetContext(ctx, &user, query, id)
	if err != nil {
		return nil, err
	}
	return &user, nil
}

func (r *AuthRepository) GetUserByEmail(ctx context.Context, email string) (*domain.User, error) {
	var user domain.User
	query := `
		SELECT u.*, COALESCE(r.name, '') as role
		FROM auth.users u
		LEFT JOIN auth.user_roles ur ON ur.user_id = u.id
		LEFT JOIN auth.roles r ON r.id = ur.role_id
		WHERE u.email = $1
		LIMIT 1
	`
	err := r.db.GetContext(ctx, &user, query, email)
	if err != nil {
		return nil, err
	}
	return &user, nil
}

func (r *AuthRepository) UpdateUserPasswordAndStatus(ctx context.Context, id, password, status string) error {
	passwordHash, err := bcrypt.GenerateFromPassword([]byte(password), bcrypt.DefaultCost)
	if err != nil {
		return err
	}
	_, err = r.db.ExecContext(ctx, `UPDATE auth.users SET password_hash = $1, status = $2 WHERE id = $3`, string(passwordHash), status, id)
	return err
}

// GetUserPermissions returns all permission codes for a user by user ID
func (r *AuthRepository) GetUserPermissions(ctx context.Context, userID string) ([]string, error) {
	var permissions []string
	query := `
		SELECT p.code
		FROM auth.user_roles ur
		JOIN auth.role_permissions rp ON rp.role_id = ur.role_id
		JOIN auth.permissions p ON p.id = rp.permission_id
		WHERE ur.user_id = $1
	`
	err := r.db.SelectContext(ctx, &permissions, query, userID)
	if err != nil {
		return nil, err
	}
	return permissions, nil
}

// Invitation-related methods

// CreateInvitation creates a new user invitation
func (r *AuthRepository) CreateInvitation(ctx context.Context, invitation *domain.UserInvitation) error {
	query := `
		INSERT INTO auth.user_invitations (
			email, token, role_id, invited_by, expires_at, status, created_at, updated_at
		) VALUES (
			$1, $2, $3, $4, $5, $6, NOW(), NOW()
		) RETURNING id, created_at, updated_at
	`
	return r.db.QueryRowContext(ctx, query,
		invitation.Email,
		invitation.Token,
		invitation.RoleID,
		invitation.InvitedBy,
		invitation.ExpiresAt,
		invitation.Status,
	).Scan(&invitation.ID, &invitation.CreatedAt, &invitation.UpdatedAt)
}

// GetInvitationByToken retrieves an invitation by its token
func (r *AuthRepository) GetInvitationByToken(ctx context.Context, token string) (*domain.UserInvitation, error) {
	var invitation domain.UserInvitation
	query := `
		SELECT id, email, token, role_id, invited_by, expires_at, accepted_at, accepted_by, status, created_at, updated_at
		FROM auth.user_invitations
		WHERE token = $1
		LIMIT 1
	`
	err := r.db.GetContext(ctx, &invitation, query, token)
	if err != nil {
		return nil, err
	}
	return &invitation, nil
}

// GetInvitationByEmail retrieves an invitation by email
func (r *AuthRepository) GetInvitationByEmail(ctx context.Context, email string) (*domain.UserInvitation, error) {
	var invitation domain.UserInvitation
	query := `
		SELECT id, email, token, role_id, invited_by, expires_at, accepted_at, accepted_by, status, created_at, updated_at
		FROM auth.user_invitations
		WHERE email = $1
		ORDER BY created_at DESC
		LIMIT 1
	`
	err := r.db.GetContext(ctx, &invitation, query, email)
	if err != nil {
		return nil, err
	}
	return &invitation, nil
}

// GetInvitationByID retrieves an invitation by its ID
func (r *AuthRepository) GetInvitationByID(ctx context.Context, id uuid.UUID) (*domain.UserInvitation, error) {
	var invitation domain.UserInvitation
	query := `
		SELECT id, email, token, role_id, invited_by, expires_at, accepted_at, accepted_by, status, created_at, updated_at
		FROM auth.user_invitations
		WHERE id = $1
		LIMIT 1
	`
	err := r.db.GetContext(ctx, &invitation, query, id)
	if err != nil {
		return nil, err
	}
	return &invitation, nil
}

// UpdateInvitation updates an invitation
func (r *AuthRepository) UpdateInvitation(ctx context.Context, invitation *domain.UserInvitation) error {
	query := `
		UPDATE auth.user_invitations
		SET email = $1, token = $2, role_id = $3, invited_by = $4, expires_at = $5, 
		    accepted_at = $6, accepted_by = $7, status = $8, updated_at = NOW()
		WHERE id = $9
	`
	_, err := r.db.ExecContext(ctx, query,
		invitation.Email,
		invitation.Token,
		invitation.RoleID,
		invitation.InvitedBy,
		invitation.ExpiresAt,
		invitation.AcceptedAt,
		invitation.AcceptedBy,
		invitation.Status,
		invitation.ID,
	)
	return err
}

// ListInvitations retrieves invitations with optional filtering
func (r *AuthRepository) ListInvitations(ctx context.Context, status, email string) ([]domain.UserInvitation, error) {
	var invitations []domain.UserInvitation
	query := `
		SELECT id, email, token, role_id, invited_by, expires_at, accepted_at, accepted_by, status, created_at, updated_at
		FROM auth.user_invitations
		WHERE 1=1
	`
	args := []interface{}{}
	argIndex := 1

	if status != "" {
		query += ` AND status = $` + string(rune(argIndex+'0'))
		args = append(args, status)
		argIndex++
	}

	if email != "" {
		query += ` AND email ILIKE $` + string(rune(argIndex+'0'))
		args = append(args, "%"+email+"%")
		argIndex++
	}

	query += ` ORDER BY created_at DESC`

	err := r.db.SelectContext(ctx, &invitations, query, args...)
	if err != nil {
		return nil, err
	}
	return invitations, nil
}

// GetRoleByID retrieves a role by its ID
func (r *AuthRepository) GetRoleByID(ctx context.Context, roleID int) (*domain.Role, error) {
	var role domain.Role
	query := `
		SELECT id, name, description, is_system, created_at, updated_at
		FROM auth.roles
		WHERE id = $1
		LIMIT 1
	`
	err := r.db.GetContext(ctx, &role, query, roleID)
	if err != nil {
		return nil, err
	}
	return &role, nil
}

// VerifyPassword verifies a user's password without changing it
func (r *AuthRepository) VerifyPassword(ctx context.Context, email, password string) error {
	var passwordHash string
	err := r.db.GetContext(ctx, "SELECT password_hash FROM auth.users WHERE email = $1", email, &passwordHash)
	if err != nil {
		return err
	}

	return bcrypt.CompareHashAndPassword([]byte(passwordHash), []byte(password))
}

// ChangePassword changes a user's password and clears the must_change_password flag
func (r *AuthRepository) ChangePassword(ctx context.Context, userID, newPassword string) error {
	passwordHash, err := bcrypt.GenerateFromPassword([]byte(newPassword), bcrypt.DefaultCost)
	if err != nil {
		return err
	}

	_, err = r.db.ExecContext(ctx,
		`UPDATE auth.users 
		 SET password_hash = $1, 
		     must_change_password = false, 
		     password_changed_at = NOW(),
		     last_password_change = NOW(),
		     updated_at = NOW()
		 WHERE id = $2`,
		string(passwordHash), userID)

	return err
}

// ListUsers returns a list of users with pagination and filtering
func (r *AuthRepository) ListUsers(ctx context.Context, page, limit int, status, role, search string) ([]domain.User, int, error) {
	offset := (page - 1) * limit

	// Build the base query
	baseQuery := `
		SELECT u.*, COALESCE(r.name, '') as role
		FROM auth.users u
		LEFT JOIN auth.user_roles ur ON ur.user_id = u.id
		LEFT JOIN auth.roles r ON r.id = ur.role_id
		WHERE u.deleted_at IS NULL
	`

	// Add filters
	args := []interface{}{}
	argCount := 1

	if status != "" {
		baseQuery += fmt.Sprintf(" AND u.status = $%d", argCount)
		args = append(args, status)
		argCount++
	}

	if role != "" {
		baseQuery += fmt.Sprintf(" AND r.name = $%d", argCount)
		args = append(args, role)
		argCount++
	}

	if search != "" {
		baseQuery += fmt.Sprintf(" AND (u.email ILIKE $%d OR u.first_name ILIKE $%d OR u.last_name ILIKE $%d OR u.username ILIKE $%d)",
			argCount, argCount, argCount, argCount)
		searchTerm := "%" + search + "%"
		args = append(args, searchTerm)
		argCount++
	}

	// Count query
	countQuery := fmt.Sprintf("SELECT COUNT(*) FROM (%s) as count_query", baseQuery)
	var total int
	err := r.db.GetContext(ctx, &total, countQuery, args...)
	if err != nil {
		return nil, 0, err
	}

	// Data query with pagination
	dataQuery := baseQuery + " ORDER BY u.created_at DESC LIMIT $" + fmt.Sprintf("%d", argCount) + " OFFSET $" + fmt.Sprintf("%d", argCount+1)
	args = append(args, limit, offset)

	var users []domain.User
	err = r.db.SelectContext(ctx, &users, dataQuery, args...)
	if err != nil {
		return nil, 0, err
	}

	return users, total, nil
}

// UpdateUser updates a user's information
func (r *AuthRepository) UpdateUser(ctx context.Context, userID string, updates map[string]interface{}, updatedBy string) error {
	// Build dynamic update query
	query := "UPDATE auth.users SET updated_at = NOW(), updated_by = $1"
	args := []interface{}{updatedBy}
	argCount := 2

	for field, value := range updates {
		if value != nil && value != "" {
			query += fmt.Sprintf(", %s = $%d", field, argCount)
			args = append(args, value)
			argCount++
		}
	}

	query += " WHERE id = $" + fmt.Sprintf("%d", argCount)
	args = append(args, userID)

	_, err := r.db.ExecContext(ctx, query, args...)
	return err
}

// UpdateUserStatus updates a user's status
func (r *AuthRepository) UpdateUserStatus(ctx context.Context, userID, status, reason, updatedBy string) error {
	query := `
		UPDATE auth.users 
		SET status = $1, 
		    status_reason = $2, 
		    status_changed_at = NOW(), 
		    status_changed_by = $3,
		    updated_at = NOW()
		WHERE id = $4
	`
	_, err := r.db.ExecContext(ctx, query, status, reason, updatedBy, userID)
	return err
}

// DeleteUser soft deletes a user
func (r *AuthRepository) DeleteUser(ctx context.Context, userID, deletedBy string) error {
	query := `
		UPDATE auth.users 
		SET deleted_at = NOW(), 
		    deleted_by = $1,
		    updated_at = NOW()
		WHERE id = $2
	`
	_, err := r.db.ExecContext(ctx, query, deletedBy, userID)
	return err
}

// GetRoles returns all available roles
func (r *AuthRepository) GetRoles(ctx context.Context) ([]domain.Role, error) {
	var roles []domain.Role
	query := "SELECT id, name, description, is_system FROM auth.roles ORDER BY name"
	err := r.db.SelectContext(ctx, &roles, query)
	return roles, err
}

// SearchUsers searches for users by various criteria
func (r *AuthRepository) SearchUsers(ctx context.Context, query string) ([]domain.User, error) {
	searchQuery := `
		SELECT u.*, COALESCE(r.name, '') as role
		FROM auth.users u
		LEFT JOIN auth.user_roles ur ON ur.user_id = u.id
		LEFT JOIN auth.roles r ON r.id = ur.role_id
		WHERE u.deleted_at IS NULL
		AND (u.email ILIKE $1 OR u.first_name ILIKE $1 OR u.last_name ILIKE $1 OR u.username ILIKE $1)
		ORDER BY u.created_at DESC
		LIMIT 50
	`

	searchTerm := "%" + query + "%"
	var users []domain.User
	err := r.db.SelectContext(ctx, &users, searchQuery, searchTerm)
	return users, err
}

// GetRoleByName returns a role by name
func (r *AuthRepository) GetRoleByName(ctx context.Context, name string) (*domain.Role, error) {
	var role domain.Role
	query := "SELECT id, name, description, is_system FROM auth.roles WHERE name = $1"
	err := r.db.GetContext(ctx, &role, query, name)
	if err != nil {
		return nil, err
	}
	return &role, nil
}
