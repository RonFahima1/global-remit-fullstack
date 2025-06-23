package repository

import (
	"context"
	"os"
	"testing"

	"global-remit-backend/internal/domain"

	"github.com/jmoiron/sqlx"
	_ "github.com/lib/pq"
	"github.com/stretchr/testify/require"
)

func setupTestDB(t *testing.T) *sqlx.DB {
	dsn := os.Getenv("TEST_DATABASE_URL")
	if dsn == "" {
		t.Skip("TEST_DATABASE_URL not set; skipping integration test")
	}
	db, err := sqlx.Open("postgres", dsn)
	require.NoError(t, err)
	return db
}

func TestAuthRepository_CreateAndAuthenticateUser(t *testing.T) {
	db := setupTestDB(t)
	repo := NewAuthRepository(db)
	ctx := context.Background()

	email := "testuser@example.com"
	password := "TestPassword123!"
	user := &domain.User{
		Username:  "testuser",
		Email:     email,
		FirstName: "Test",
		LastName:  "User",
		Status:    "ACTIVE",
	}
	// Clean up if user exists
	_, _ = db.Exec("DELETE FROM auth.user_roles WHERE user_id = (SELECT id FROM auth.users WHERE email = $1)", email)
	_, _ = db.Exec("DELETE FROM auth.users WHERE email = $1", email)

	// Ensure ORG_ADMIN role exists
	var roleID int
	err := db.QueryRow("SELECT id FROM auth.roles WHERE name = $1", "ORG_ADMIN").Scan(&roleID)
	if err != nil {
		// Insert role if not exists
		err = db.QueryRow(`INSERT INTO auth.roles (name, description, is_system, created_at, updated_at) VALUES ($1, $2, true, NOW(), NOW()) RETURNING id`, "ORG_ADMIN", "Test Org Admin").Scan(&roleID)
		require.NoError(t, err)
	}

	err = repo.CreateUser(ctx, user, password)
	require.NoError(t, err)
	require.NotZero(t, user.ID)

	// Map user to role
	_, err = db.Exec(`INSERT INTO auth.user_roles (user_id, role_id, created_at) VALUES ($1, $2, NOW())`, user.ID, roleID)
	require.NoError(t, err)

	// Authenticate
	authUser, err := repo.AuthenticateUser(ctx, email, password)
	require.NoError(t, err)
	require.Equal(t, user.Email, authUser.Email)
	require.Equal(t, "ORG_ADMIN", authUser.Role)
}

func TestAuthRepository_GetUserPermissions(t *testing.T) {
	// db := setupTestDB(t)
	// repo := NewAuthRepository(db)
	// ctx := context.Background()

	// TODO: Insert user, role, and permissions, or use a known seeded user
	// For now, just skip if not set up
	t.Skip("TODO: Implement permission test with seeded user and role")
}

func TestAuthRepository_PermissionRetrieval(t *testing.T) {
	db := setupTestDB(t)
	repo := NewAuthRepository(db)
	ctx := context.Background()

	email := "permuser@example.com"
	password := "TestPassword123!"
	user := &domain.User{
		Username:  "permuser",
		Email:     email,
		FirstName: "Perm",
		LastName:  "User",
		Status:    "ACTIVE",
	}
	// Clean up
	_, _ = db.Exec("DELETE FROM auth.user_roles WHERE user_id = (SELECT id FROM auth.users WHERE email = $1)", email)
	_, _ = db.Exec("DELETE FROM auth.users WHERE email = $1", email)

	// Ensure role exists
	var roleID int
	err := db.QueryRow("SELECT id FROM auth.roles WHERE name = $1", "ORG_ADMIN").Scan(&roleID)
	if err != nil {
		err = db.QueryRow(`INSERT INTO auth.roles (name, description, is_system, created_at, updated_at) VALUES ($1, $2, true, NOW(), NOW()) RETURNING id`, "ORG_ADMIN", "Test Org Admin").Scan(&roleID)
		require.NoError(t, err)
	}

	// Ensure permission exists
	var permID int
	permCode := "test:perm"
	err = db.QueryRow("SELECT id FROM auth.permissions WHERE code = $1", permCode).Scan(&permID)
	if err != nil {
		err = db.QueryRow(`INSERT INTO auth.permissions (code, name, category, created_at) VALUES ($1, $2, $3, NOW()) RETURNING id`, permCode, "Test Permission", "Test").Scan(&permID)
		require.NoError(t, err)
	}

	// Map permission to role
	_, _ = db.Exec("DELETE FROM auth.role_permissions WHERE role_id = $1 AND permission_id = $2", roleID, permID)
	_, err = db.Exec(`INSERT INTO auth.role_permissions (role_id, permission_id, created_at) VALUES ($1, $2, NOW()) ON CONFLICT DO NOTHING`, roleID, permID)
	require.NoError(t, err)

	err = repo.CreateUser(ctx, user, password)
	require.NoError(t, err)
	require.NotZero(t, user.ID)

	// Map user to role
	_, err = db.Exec(`INSERT INTO auth.user_roles (user_id, role_id, created_at) VALUES ($1, $2, NOW())`, user.ID, roleID)
	require.NoError(t, err)

	perms, err := repo.GetUserPermissions(ctx, user.ID.String())
	require.NoError(t, err)
	found := false
	for _, p := range perms {
		if p == permCode {
			found = true
		}
	}
	require.True(t, found, "expected permission not found")
}

func TestAuthRepository_NegativeLogin(t *testing.T) {
	db := setupTestDB(t)
	repo := NewAuthRepository(db)
	ctx := context.Background()

	email := "neguser@example.com"
	password := "TestPassword123!"
	user := &domain.User{
		Username:  "neguser",
		Email:     email,
		FirstName: "Neg",
		LastName:  "User",
		Status:    "ACTIVE",
	}
	_, _ = db.Exec("DELETE FROM auth.user_roles WHERE user_id = (SELECT id FROM auth.users WHERE email = $1)", email)
	_, _ = db.Exec("DELETE FROM auth.users WHERE email = $1", email)

	// Ensure role exists
	var roleID int
	err := db.QueryRow("SELECT id FROM auth.roles WHERE name = $1", "ORG_ADMIN").Scan(&roleID)
	if err != nil {
		err = db.QueryRow(`INSERT INTO auth.roles (name, description, is_system, created_at, updated_at) VALUES ($1, $2, true, NOW(), NOW()) RETURNING id`, "ORG_ADMIN", "Test Org Admin").Scan(&roleID)
		require.NoError(t, err)
	}

	err = repo.CreateUser(ctx, user, password)
	require.NoError(t, err)
	require.NotZero(t, user.ID)
	_, err = db.Exec(`INSERT INTO auth.user_roles (user_id, role_id, created_at) VALUES ($1, $2, NOW())`, user.ID, roleID)
	require.NoError(t, err)

	// Wrong password
	_, err = repo.AuthenticateUser(ctx, email, "WrongPassword!")
	require.Error(t, err)

	// Non-existent user
	_, err = repo.AuthenticateUser(ctx, "doesnotexist@example.com", "AnyPassword!")
	require.Error(t, err)
}

func TestAuthRepository_LockedUserLogin(t *testing.T) {
	db := setupTestDB(t)
	repo := NewAuthRepository(db)
	ctx := context.Background()

	email := "lockeduser@example.com"
	password := "TestPassword123!"
	user := &domain.User{
		Username:  "lockeduser",
		Email:     email,
		FirstName: "Locked",
		LastName:  "User",
		Status:    "LOCKED",
	}
	_, _ = db.Exec("DELETE FROM auth.user_roles WHERE user_id = (SELECT id FROM auth.users WHERE email = $1)", email)
	_, _ = db.Exec("DELETE FROM auth.users WHERE email = $1", email)

	// Ensure role exists
	var roleID int
	err := db.QueryRow("SELECT id FROM auth.roles WHERE name = $1", "ORG_ADMIN").Scan(&roleID)
	if err != nil {
		err = db.QueryRow(`INSERT INTO auth.roles (name, description, is_system, created_at, updated_at) VALUES ($1, $2, true, NOW(), NOW()) RETURNING id`, "ORG_ADMIN", "Test Org Admin").Scan(&roleID)
		require.NoError(t, err)
	}

	err = repo.CreateUser(ctx, user, password)
	require.NoError(t, err)
	require.NotZero(t, user.ID)
	_, err = db.Exec(`INSERT INTO auth.user_roles (user_id, role_id, created_at) VALUES ($1, $2, NOW())`, user.ID, roleID)
	require.NoError(t, err)

	// Should not authenticate
	_, err = repo.AuthenticateUser(ctx, email, password)
	require.Error(t, err)
}
