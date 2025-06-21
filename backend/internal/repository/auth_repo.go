package repository

import (
	"context"
	"errors"
	"log"

	"golang.org/x/crypto/bcrypt"

	"backend/internal/domain"

	"github.com/jmoiron/sqlx"
)

type AuthRepository struct {
	db *sqlx.DB
}

func NewAuthRepository(db *sqlx.DB) *AuthRepository {
	return &AuthRepository{db: db}
}

func (r *AuthRepository) CreateUser(ctx context.Context, user *domain.User, password string) error {
	// Start transaction
	tx, err := r.db.BeginTxx(ctx, nil)
	if err != nil {
		return err
	}
	defer func() {
		if err != nil {
			tx.Rollback()
		} else {
			err = tx.Commit()
		}
	}()

	passwordHash, err := bcrypt.GenerateFromPassword([]byte(password), bcrypt.DefaultCost)
	if err != nil {
		return err
	}
	user.PasswordHash = string(passwordHash)

	query := `
		INSERT INTO auth.users (
			username, email, password_hash, first_name, last_name, status
		) VALUES (
			:username, :email, :password_hash, :first_name, :last_name, :status
		) RETURNING id, created_at, updated_at, version
	`
	// Use sqlx.NamedQueryContext for transactions
	rows, err := sqlx.NamedQueryContext(ctx, tx, query, user)
	if err != nil {
		return err
	}
	defer rows.Close()

	if rows.Next() {
		err = rows.StructScan(user)
		if err != nil {
			return err
		}
	}

	// Assign default role if not specified
	roleName := user.Role
	if roleName == "" {
		roleName = "ORG_USER"
	}
	var roleID int
	err = tx.QueryRowContext(ctx, "SELECT id FROM auth.roles WHERE name = $1", roleName).Scan(&roleID)
	if err != nil {
		return err
	}
	_, err = tx.ExecContext(ctx, `INSERT INTO auth.user_roles (user_id, role_id, created_at) VALUES ($1, $2, NOW()) ON CONFLICT DO NOTHING`, user.ID, roleID)
	if err != nil {
		return err
	}

	return nil
}

func (r *AuthRepository) AuthenticateUser(ctx context.Context, email, password string) (*domain.User, error) {
	log.Printf("AuthenticateUser: Attempting login for email: %s", email)

	var user domain.User
	query := `
		SELECT u.*, r.name as role
		FROM auth.users u
		LEFT JOIN auth.user_roles ur ON ur.user_id = u.id
		LEFT JOIN auth.roles r ON r.id = ur.role_id
		WHERE u.email = $1
		LIMIT 1
	`
	err := r.db.GetContext(ctx, &user, query, email)
	if err != nil {
		log.Printf("AuthenticateUser: Database error for email %s: %v", email, err)
		return nil, err
	}

	log.Printf("AuthenticateUser: Found user with ID: %s, Status: %s, Role: %s", user.ID, user.Status, user.Role)

	if user.Status == "LOCKED" {
		log.Printf("AuthenticateUser: User %s is locked", email)
		return nil, errors.New("user is locked")
	}
	if user.Status != "ACTIVE" {
		log.Printf("AuthenticateUser: User %s is not active, status: %s", email, user.Status)
		return nil, errors.New("user is not active")
	}

	log.Printf("AuthenticateUser: Comparing password for user %s", email)
	if err := bcrypt.CompareHashAndPassword([]byte(user.PasswordHash), []byte(password)); err != nil {
		// Specific logging for password mismatch
		if err == bcrypt.ErrMismatchedHashAndPassword {
			log.Printf("AuthenticateUser: Password mismatch for user %s", email)
			return nil, errors.New("password does not match")
		}
		// Other bcrypt errors
		log.Printf("AuthenticateUser: Bcrypt error for user %s: %v", email, err)
		return nil, err
	}

	log.Printf("AuthenticateUser: Successful authentication for user %s", email)
	return &user, nil
}

func (r *AuthRepository) GetUserByID(ctx context.Context, id string) (*domain.User, error) {
	var user domain.User
	query := `
		SELECT u.*, r.name as role
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
		SELECT u.*, r.name as role
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
