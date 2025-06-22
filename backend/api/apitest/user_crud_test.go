package apitest

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"os"
	"strings"
	"testing"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
	"github.com/stretchr/testify/suite"

	"backend/api/handlers"
	"backend/api/middleware"
	"backend/config"
	"backend/internal/app"
	"backend/internal/domain"
	"backend/internal/utils/token"
	"backend/pkg/db"
)

type UserCRUDTestSuite struct {
	suite.Suite
	router      *gin.Engine
	authHandler *handlers.AuthHandler
	userHandler *handlers.UserManagementHandler
	adminToken  string
	adminUserID string
}

func (suite *UserCRUDTestSuite) SetupSuite() {
	// Set up environment variables for testing
	os.Setenv("DB_HOST", "localhost")
	os.Setenv("DB_PORT", os.Getenv("DB_PORT"))
	os.Setenv("DB_USER", "postgres")
	os.Setenv("DB_PASSWORD", "postgres")
	os.Setenv("DB_NAME", "global_remit")
	os.Setenv("APP_PORT", os.Getenv("APP_PORT"))

	// Load JWT keys from files
	privKeyBytes, err := os.ReadFile("../../jwt_private.pem")
	require.NoError(suite.T(), err)
	pubKeyBytes, err := os.ReadFile("../../jwt_public.pem")
	require.NoError(suite.T(), err)
	os.Setenv("JWT_PRIVATE_KEY", string(privKeyBytes))
	os.Setenv("JWT_PUBLIC_KEY", string(pubKeyBytes))

	// Load configuration
	cfg, err := config.Load()
	require.NoError(suite.T(), err)

	// Load JWT keys
	require.NoError(suite.T(), token.LoadKeys())

	// Connect to database
	database, err := db.Connect(cfg)
	require.NoError(suite.T(), err)

	// Create application instance with logger
	logger := slog.New(slog.NewTextHandler(os.Stdout, nil))
	appInstance := app.New(database, logger)

	// Initialize handlers
	suite.authHandler = handlers.NewAuthHandler(appInstance)
	suite.userHandler = handlers.NewUserManagementHandler(appInstance)

	// Set up router
	gin.SetMode(gin.TestMode)
	suite.router = gin.New()
	suite.router.Use(gin.Recovery())

	// Auth routes (public)
	suite.router.POST("/api/auth/login", suite.authHandler.Login)

	// Protected routes with auth middleware
	protected := suite.router.Group("/api")
	protected.Use(middleware.AuthMiddleware())
	{
		// User management routes
		protected.GET("/users", suite.userHandler.GetUsers)
		protected.GET("/users/:id", suite.userHandler.GetUser)
		protected.POST("/users", suite.userHandler.CreateUser)
		protected.PUT("/users/:id", suite.userHandler.UpdateUser)
		protected.DELETE("/users/:id", suite.userHandler.DeleteUser)
	}

	// Seed admin user if not present
	repo := appInstance.AuthRepo
	ctx := context.Background()
	adminEmail := "admin@example.com"
	adminUser, err := repo.GetUserByEmail(ctx, adminEmail)
	if err != nil && strings.Contains(err.Error(), "not found") {
		// Ensure ORG_ADMIN role exists
		var roleID int
		db := database
		err = db.GetContext(ctx, &roleID, "SELECT id FROM auth.roles WHERE name = $1", "ORG_ADMIN")
		if err != nil {
			_, err = db.ExecContext(ctx, `INSERT INTO auth.roles (name, description, is_system, created_at, updated_at) VALUES ($1, $2, true, NOW(), NOW())`, "ORG_ADMIN", "Organization Admin")
			require.NoError(suite.T(), err)
		}
		// Generate unique username
		adminUsername := "admin_test_" + uuid.NewString()
		adminUser = &domain.User{
			Username:  adminUsername,
			Email:     adminEmail,
			FirstName: "Admin",
			LastName:  "User",
			Role:      "ORG_ADMIN",
			Status:    "ACTIVE",
		}
		err = repo.CreateUser(ctx, adminUser, "AdminPass123!")
		require.NoError(suite.T(), err)
	}

	// Clean up test users and related data except whitelisted system/admin users
	whitelist := []string{
		"admin@example.com",
		"orgadmin@example.com",
		"agentadmin@example.com",
		"agentuser@example.com",
		"complianceuser@example.com",
		"demo@example.com",
	}
	placeholders := ""
	for i := range whitelist {
		if i > 0 {
			placeholders += ","
		}
		placeholders += "$" + fmt.Sprintf("%d", i+1)
	}
	// Convert whitelist to []interface{} for variadic call
	args := make([]interface{}, len(whitelist))
	for i, v := range whitelist {
		args[i] = v
	}
	// Delete from related tables
	db := database
	_, err = db.ExecContext(ctx, `DELETE FROM auth.user_roles WHERE user_id IN (SELECT id FROM auth.users WHERE email NOT IN (`+placeholders+`))`, args...)
	require.NoError(suite.T(), err)
	_, err = db.ExecContext(ctx, `DELETE FROM auth.user_sessions WHERE user_id IN (SELECT id FROM auth.users WHERE email NOT IN (`+placeholders+`))`, args...)
	require.NoError(suite.T(), err)
	_, err = db.ExecContext(ctx, `DELETE FROM auth.user_activity_log WHERE user_id IN (SELECT id FROM auth.users WHERE email NOT IN (`+placeholders+`))`, args...)
	require.NoError(suite.T(), err)
	_, err = db.ExecContext(ctx, `DELETE FROM auth.user_password_history WHERE user_id IN (SELECT id FROM auth.users WHERE email NOT IN (`+placeholders+`))`, args...)
	require.NoError(suite.T(), err)
	_, err = db.ExecContext(ctx, `DELETE FROM auth.user_invitations WHERE invited_by IN (SELECT id FROM auth.users WHERE email NOT IN (`+placeholders+`))`, args...)
	require.NoError(suite.T(), err)
	_, err = db.ExecContext(ctx, `DELETE FROM auth.user_verification_tokens WHERE user_id IN (SELECT id FROM auth.users WHERE email NOT IN (`+placeholders+`))`, args...)
	require.NoError(suite.T(), err)
	_, err = db.ExecContext(ctx, `DELETE FROM auth.user_preferences WHERE user_id IN (SELECT id FROM auth.users WHERE email NOT IN (`+placeholders+`))`, args...)
	require.NoError(suite.T(), err)
	_, err = db.ExecContext(ctx, `DELETE FROM auth.users WHERE email NOT IN (`+placeholders+`)`, args...)
	require.NoError(suite.T(), err)

	// Debug: print all emails in users table
	var emails []string
	err = db.SelectContext(ctx, &emails, `SELECT email FROM auth.users`)
	suite.T().Log("[DEBUG] Users in DB after cleanup:", emails)
	require.NoError(suite.T(), err)

	// Login as admin to get token
	suite.loginAsAdmin()
}

func (suite *UserCRUDTestSuite) loginAsAdmin() {
	loginData := map[string]interface{}{
		"email":    "admin@example.com",
		"password": "AdminPass123!",
	}

	jsonData, _ := json.Marshal(loginData)
	req := httptest.NewRequest("POST", "/api/auth/login", bytes.NewBuffer(jsonData))
	req.Header.Set("Content-Type", "application/json")

	w := httptest.NewRecorder()
	suite.router.ServeHTTP(w, req)

	if w.Code == http.StatusOK {
		var response map[string]interface{}
		json.Unmarshal(w.Body.Bytes(), &response)
		suite.adminToken = response["accessToken"].(string)

		// Extract user ID from token or response
		if user, ok := response["user"].(map[string]interface{}); ok {
			if id, ok := user["id"].(string); ok {
				suite.adminUserID = id
			}
		}
	}
}

func (suite *UserCRUDTestSuite) TestCreateUser() {
	email := fmt.Sprintf("testuser1_%s@example.com", uuid.NewString())
	userData := map[string]interface{}{
		"email":      email,
		"username":   "testuser1_" + uuid.NewString(),
		"first_name": "Test",
		"last_name":  "User",
		"role":       "ORG_USER",
	}

	jsonData, _ := json.Marshal(userData)
	req := httptest.NewRequest("POST", "/api/users", bytes.NewBuffer(jsonData))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer "+suite.adminToken)

	w := httptest.NewRecorder()
	suite.router.ServeHTTP(w, req)

	assert.Equal(suite.T(), http.StatusCreated, w.Code)

	var response map[string]interface{}
	err := json.Unmarshal(w.Body.Bytes(), &response)
	assert.NoError(suite.T(), err)
	assert.Contains(suite.T(), response, "user")

	user := response["user"].(map[string]interface{})
	assert.Equal(suite.T(), email, user["email"])
	assert.Equal(suite.T(), "Test", user["first_name"])
	assert.Equal(suite.T(), "User", user["last_name"])
}

// func (suite *UserCRUDTestSuite) TestGetUser() { /* ... */ }
// func (suite *UserCRUDTestSuite) TestUpdateUser() { /* ... */ }
// func (suite *UserCRUDTestSuite) TestDeleteUser() { /* ... */ }
// func (suite *UserCRUDTestSuite) TestGetUsersList() { /* ... */ }

func TestUserCRUDTestSuite(t *testing.T) {
	suite.Run(t, new(UserCRUDTestSuite))
}
