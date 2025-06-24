package apitest

import (
	"bytes"
	"context"
	"encoding/json"
	"net/http/httptest"
	"os"
	"testing"

	"log/slog"

	"github.com/gin-gonic/gin"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
	"github.com/stretchr/testify/suite"
	"golang.org/x/crypto/bcrypt"

	"global-remit-backend/api/handlers"
	"global-remit-backend/config"
	"global-remit-backend/internal/app"
	"global-remit-backend/internal/domain"
	"global-remit-backend/internal/utils/token"
	"global-remit-backend/pkg/db"
)

type AuthTestSuite struct {
	suite.Suite
	router      *gin.Engine
	authHandler *handlers.AuthHandler
	adminToken  string
}

func (suite *AuthTestSuite) SetupSuite() {
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

	// Set up router
	gin.SetMode(gin.TestMode)
	suite.router = gin.New()
	suite.router.Use(gin.Recovery())
	suite.router.POST("/api/auth/login", suite.authHandler.Login)
	// Add other auth endpoints as needed

	// Seed admin user if not present
	repo := appInstance.AuthRepo
	ctx := context.Background()
	adminEmail := "admin@example.com"
	adminUser, err := repo.GetUserByEmail(ctx, adminEmail)
	if err != nil {
		// Ensure ORG_ADMIN role exists
		var roleID int
		db := database
		err = db.GetContext(ctx, &roleID, "SELECT id FROM auth.roles WHERE name = $1", "ORG_ADMIN")
		if err != nil {
			_, err = db.ExecContext(ctx, `INSERT INTO auth.roles (name, description, is_system, created_at, updated_at) VALUES ($1, $2, true, NOW(), NOW())`, "ORG_ADMIN", "Organization Admin")
			require.NoError(suite.T(), err)
		}
		adminUser = &domain.User{
			Username:  "admin",
			Email:     adminEmail,
			FirstName: "Admin",
			LastName:  "User",
			Role:      "ORG_ADMIN",
			Status:    "ACTIVE",
		}
		err = repo.CreateUser(ctx, adminUser, "AdminPass123!")
		require.NoError(suite.T(), err)
	} else {
		// Update existing admin user's password to match test expectations and unlock the account
		passwordHash, err := bcrypt.GenerateFromPassword([]byte("AdminPass123!"), bcrypt.DefaultCost)
		require.NoError(suite.T(), err)
		_, err = database.ExecContext(ctx, "UPDATE auth.users SET password_hash = $1, failed_login_attempts = 0, locked_until = NULL WHERE id = $2", string(passwordHash), adminUser.ID)
		require.NoError(suite.T(), err)
	}
}

func (suite *AuthTestSuite) TestLoginSuccess() {
	loginData := map[string]interface{}{
		"email":    "admin@example.com",
		"password": "AdminPass123!",
	}
	jsonData, _ := json.Marshal(loginData)
	req := httptest.NewRequest("POST", "/api/auth/login", bytes.NewBuffer(jsonData))
	req.Header.Set("Content-Type", "application/json")
	w := httptest.NewRecorder()
	suite.router.ServeHTTP(w, req)
	assert.Equal(suite.T(), 200, w.Code)
	var response map[string]interface{}
	err := json.Unmarshal(w.Body.Bytes(), &response)
	assert.NoError(suite.T(), err)
	assert.Contains(suite.T(), response, "accessToken")
}

func (suite *AuthTestSuite) TestLoginWrongPassword() {
	loginData := map[string]interface{}{
		"email":    "admin@example.com",
		"password": "WrongPassword",
	}
	jsonData, _ := json.Marshal(loginData)
	req := httptest.NewRequest("POST", "/api/auth/login", bytes.NewBuffer(jsonData))
	req.Header.Set("Content-Type", "application/json")
	w := httptest.NewRecorder()
	suite.router.ServeHTTP(w, req)
	assert.Equal(suite.T(), 401, w.Code)
}

func (suite *AuthTestSuite) TestLoginNonExistentUser() {
	loginData := map[string]interface{}{
		"email":    "doesnotexist@example.com",
		"password": "AnyPassword",
	}
	jsonData, _ := json.Marshal(loginData)
	req := httptest.NewRequest("POST", "/api/auth/login", bytes.NewBuffer(jsonData))
	req.Header.Set("Content-Type", "application/json")
	w := httptest.NewRecorder()
	suite.router.ServeHTTP(w, req)
	assert.Equal(suite.T(), 401, w.Code)
}

func TestAuthTestSuite(t *testing.T) {
	suite.Run(t, new(AuthTestSuite))
}
