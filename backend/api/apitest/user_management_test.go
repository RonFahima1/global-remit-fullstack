package apitest

import (
	"bytes"
	"encoding/json"
	"fmt"
	"net/http"
	"net/http/httptest"
	"os"
	"testing"

	"github.com/gin-gonic/gin"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
	"github.com/stretchr/testify/suite"

	"backend/api/handlers"
	"backend/config"
	"backend/internal/app"
	"backend/internal/utils/token"
	"backend/pkg/db"
)

type UserManagementTestSuite struct {
	suite.Suite
	router      *gin.Engine
	authHandler *handlers.AuthHandler
	userHandler *handlers.UserManagementHandler
	adminToken  string
	adminUserID string
	testUserID  string
}

func (suite *UserManagementTestSuite) SetupSuite() {
	// Set up environment variables for testing
	os.Setenv("DB_HOST", "localhost")
	os.Setenv("DB_PORT", os.Getenv("DB_PORT"))
	os.Setenv("DB_USER", "postgres")
	os.Setenv("DB_PASSWORD", "postgres")
	os.Setenv("DB_NAME", "global_remit")
	os.Setenv("APP_PORT", os.Getenv("APP_PORT"))

	// Load JWT keys from files
	privKeyBytes, err := os.ReadFile("../../jwt_private.pem")
	if err != nil {
		suite.T().Fatalf("Failed to read private key: %v", err)
	}
	pubKeyBytes, err := os.ReadFile("../../jwt_public.pem")
	if err != nil {
		suite.T().Fatalf("Failed to read public key: %v", err)
	}

	os.Setenv("JWT_PRIVATE_KEY", string(privKeyBytes))
	os.Setenv("JWT_PUBLIC_KEY", string(pubKeyBytes))

	// Load configuration
	cfg, err := config.Load()
	if err != nil {
		suite.T().Fatalf("Failed to load config: %v", err)
	}

	// Load JWT keys
	if err := token.LoadKeys(); err != nil {
		suite.T().Fatalf("Failed to load JWT keys: %v", err)
	}

	// Connect to database
	database, err := db.Connect(cfg)
	if err != nil {
		suite.T().Fatalf("Failed to connect to database: %v", err)
	}

	// Create application instance
	appInstance := app.New(database, nil)

	// Initialize handlers
	suite.authHandler = handlers.NewAuthHandler(appInstance)
	suite.userHandler = handlers.NewUserManagementHandler(appInstance)

	// Set up router
	gin.SetMode(gin.TestMode)
	suite.router = gin.New()
	suite.router.Use(gin.Recovery())

	// Set up routes
	suite.setupRoutes()

	// Login as admin to get token
	suite.loginAsAdmin()
}

func (suite *UserManagementTestSuite) TearDownSuite() {
	// Cleanup if needed
}

func (suite *UserManagementTestSuite) setupRoutes() {
	// Auth routes
	suite.router.POST("/api/auth/login", suite.authHandler.Login)
	suite.router.POST("/api/auth/register", suite.authHandler.RegisterUser)
	suite.router.GET("/api/auth/me", suite.authHandler.Me)

	// User management routes
	suite.router.GET("/api/users", suite.userHandler.GetUsers)
	suite.router.GET("/api/users/:id", suite.userHandler.GetUser)
	suite.router.POST("/api/users", suite.userHandler.CreateUser)
	suite.router.PUT("/api/users/:id", suite.userHandler.UpdateUser)
	suite.router.PUT("/api/users/:id/status", suite.userHandler.UpdateUserStatus)
	suite.router.POST("/api/users/:id/reset-password", suite.userHandler.ResetUserPassword)
	suite.router.DELETE("/api/users/:id", suite.userHandler.DeleteUser)
	suite.router.GET("/api/roles", suite.userHandler.GetRoles)
	suite.router.GET("/api/users/:id/permissions", suite.userHandler.GetUserPermissions)
	suite.router.GET("/api/users/search", suite.userHandler.SearchUsers)
}

func (suite *UserManagementTestSuite) loginAsAdmin() {
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

func TestUserManagement(t *testing.T) {
	suite.Run(t, new(UserManagementTestSuite))
}

func (suite *UserManagementTestSuite) testCompleteUserManagementFlow() {
	// 1. Create a new user
	userData := map[string]interface{}{
		"username":   "testflowuser",
		"email":      "testflowuser@example.com",
		"password":   "TestPass123!",
		"first_name": "Test",
		"last_name":  "Flow",
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
	json.Unmarshal(w.Body.Bytes(), &response)
	userID := response["user"].(map[string]interface{})["id"].(string)

	// 2. Activate user
	activateData := map[string]interface{}{
		"status": "ACTIVE",
	}

	jsonData, _ = json.Marshal(activateData)
	req = httptest.NewRequest("PUT", "/api/users/"+userID, bytes.NewBuffer(jsonData))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer "+suite.adminToken)

	w = httptest.NewRecorder()
	suite.router.ServeHTTP(w, req)

	assert.Equal(suite.T(), http.StatusOK, w.Code)

	// 3. Login with new user
	loginData := map[string]interface{}{
		"email":    "testflowuser@example.com",
		"password": "TestPass123!",
	}

	jsonData, _ = json.Marshal(loginData)
	req = httptest.NewRequest("POST", "/api/auth/login", bytes.NewBuffer(jsonData))
	req.Header.Set("Content-Type", "application/json")

	w = httptest.NewRecorder()
	suite.router.ServeHTTP(w, req)

	assert.Equal(suite.T(), http.StatusOK, w.Code)

	var loginResponse map[string]interface{}
	json.Unmarshal(w.Body.Bytes(), &loginResponse)
	userToken := loginResponse["accessToken"].(string)

	// 4. Change password
	changePassData := map[string]interface{}{
		"newPassword": "NewTestPass123!",
	}

	jsonData, _ = json.Marshal(changePassData)
	req = httptest.NewRequest("POST", "/api/users/"+userID+"/reset-password", bytes.NewBuffer(jsonData))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer "+userToken)

	w = httptest.NewRecorder()
	suite.router.ServeHTTP(w, req)

	assert.Equal(suite.T(), http.StatusOK, w.Code)

	// 5. Login with new password
	loginData = map[string]interface{}{
		"email":    "testflowuser@example.com",
		"password": "NewTestPass123!",
	}

	jsonData, _ = json.Marshal(loginData)
	req = httptest.NewRequest("POST", "/api/auth/login", bytes.NewBuffer(jsonData))
	req.Header.Set("Content-Type", "application/json")

	w = httptest.NewRecorder()
	suite.router.ServeHTTP(w, req)

	assert.Equal(suite.T(), http.StatusOK, w.Code)

	// 6. Disable user
	disableData := map[string]interface{}{
		"status": "DISABLED",
	}

	jsonData, _ = json.Marshal(disableData)
	req = httptest.NewRequest("PUT", "/api/users/"+userID, bytes.NewBuffer(jsonData))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer "+suite.adminToken)

	w = httptest.NewRecorder()
	suite.router.ServeHTTP(w, req)

	assert.Equal(suite.T(), http.StatusOK, w.Code)

	// 7. Try login with disabled user
	loginData = map[string]interface{}{
		"email":    "testflowuser@example.com",
		"password": "NewTestPass123!",
	}

	jsonData, _ = json.Marshal(loginData)
	req = httptest.NewRequest("POST", "/api/auth/login", bytes.NewBuffer(jsonData))
	req.Header.Set("Content-Type", "application/json")

	w = httptest.NewRecorder()
	suite.router.ServeHTTP(w, req)

	assert.Equal(suite.T(), http.StatusForbidden, w.Code)

	// 8. Re-enable user
	enableData := map[string]interface{}{
		"status": "ACTIVE",
	}

	jsonData, _ = json.Marshal(enableData)
	req = httptest.NewRequest("PUT", "/api/users/"+userID, bytes.NewBuffer(jsonData))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer "+suite.adminToken)

	w = httptest.NewRecorder()
	suite.router.ServeHTTP(w, req)

	assert.Equal(suite.T(), http.StatusOK, w.Code)

	// 9. Delete user
	req = httptest.NewRequest("DELETE", "/api/users/"+userID, nil)
	req.Header.Set("Authorization", "Bearer "+suite.adminToken)

	w = httptest.NewRecorder()
	suite.router.ServeHTTP(w, req)

	assert.Equal(suite.T(), http.StatusOK, w.Code)
}

func (suite *UserManagementTestSuite) testAuthentication() {
	// Test valid login
	loginData := map[string]interface{}{
		"email":    "admin@example.com",
		"password": "AdminPass123!",
	}

	jsonData, _ := json.Marshal(loginData)
	req := httptest.NewRequest("POST", "/api/auth/login", bytes.NewBuffer(jsonData))
	req.Header.Set("Content-Type", "application/json")

	w := httptest.NewRecorder()
	suite.router.ServeHTTP(w, req)

	assert.Equal(suite.T(), http.StatusOK, w.Code)

	var response map[string]interface{}
	json.Unmarshal(w.Body.Bytes(), &response)
	assert.Contains(suite.T(), response, "accessToken")

	// Test invalid credentials
	invalidLoginData := map[string]interface{}{
		"email":    "admin@example.com",
		"password": "WrongPassword",
	}

	jsonData, _ = json.Marshal(invalidLoginData)
	req = httptest.NewRequest("POST", "/api/auth/login", bytes.NewBuffer(jsonData))
	req.Header.Set("Content-Type", "application/json")

	w = httptest.NewRecorder()
	suite.router.ServeHTTP(w, req)

	assert.Equal(suite.T(), http.StatusUnauthorized, w.Code)

	// Test non-existent user
	nonExistentLoginData := map[string]interface{}{
		"email":    "nonexistent@example.com",
		"password": "AnyPassword",
	}

	jsonData, _ = json.Marshal(nonExistentLoginData)
	req = httptest.NewRequest("POST", "/api/auth/login", bytes.NewBuffer(jsonData))
	req.Header.Set("Content-Type", "application/json")

	w = httptest.NewRecorder()
	suite.router.ServeHTTP(w, req)

	assert.Equal(suite.T(), http.StatusUnauthorized, w.Code)
}

func (suite *UserManagementTestSuite) testUserCRUD() {
	// Create user
	userData := map[string]interface{}{
		"username":   "crudtestuser",
		"email":      "crudtestuser@example.com",
		"password":   "TestPass123!",
		"first_name": "CRUD",
		"last_name":  "Test",
		"role":       "ORG_USER",
	}

	jsonData, _ := json.Marshal(userData)
	req := httptest.NewRequest("POST", "/api/users", bytes.NewBuffer(jsonData))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer "+suite.adminToken)

	w := httptest.NewRecorder()
	suite.router.ServeHTTP(w, req)

	assert.Equal(suite.T(), http.StatusCreated, w.Code)

	var createResponse map[string]interface{}
	err := json.Unmarshal(w.Body.Bytes(), &createResponse)
	require.NoError(suite.T(), err)

	userID := createResponse["user"].(map[string]interface{})["id"].(string)

	// Read user
	req = httptest.NewRequest("GET", "/api/users/"+userID, nil)
	req.Header.Set("Authorization", "Bearer "+suite.adminToken)

	w = httptest.NewRecorder()
	suite.router.ServeHTTP(w, req)

	assert.Equal(suite.T(), http.StatusOK, w.Code)

	var getResponse map[string]interface{}
	err = json.Unmarshal(w.Body.Bytes(), &getResponse)
	require.NoError(suite.T(), err)

	assert.Equal(suite.T(), "crudtestuser@example.com", getResponse["email"])

	// Update user
	updateData := map[string]interface{}{
		"first_name": "Updated",
		"last_name":  "Name",
		"phone":      "+1234567890",
	}

	jsonData, _ = json.Marshal(updateData)
	req = httptest.NewRequest("PUT", "/api/users/"+userID, bytes.NewBuffer(jsonData))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer "+suite.adminToken)

	w = httptest.NewRecorder()
	suite.router.ServeHTTP(w, req)

	assert.Equal(suite.T(), http.StatusOK, w.Code)

	// Verify update
	req = httptest.NewRequest("GET", "/api/users/"+userID, nil)
	req.Header.Set("Authorization", "Bearer "+suite.adminToken)

	w = httptest.NewRecorder()
	suite.router.ServeHTTP(w, req)

	assert.Equal(suite.T(), http.StatusOK, w.Code)

	var updatedResponse map[string]interface{}
	err = json.Unmarshal(w.Body.Bytes(), &updatedResponse)
	require.NoError(suite.T(), err)

	assert.Equal(suite.T(), "Updated", updatedResponse["first_name"])
	assert.Equal(suite.T(), "Name", updatedResponse["last_name"])

	// Delete user
	req = httptest.NewRequest("DELETE", "/api/users/"+userID, nil)
	req.Header.Set("Authorization", "Bearer "+suite.adminToken)

	w = httptest.NewRecorder()
	suite.router.ServeHTTP(w, req)

	assert.Equal(suite.T(), http.StatusOK, w.Code)

	// Verify deletion
	req = httptest.NewRequest("GET", "/api/users/"+userID, nil)
	req.Header.Set("Authorization", "Bearer "+suite.adminToken)

	w = httptest.NewRecorder()
	suite.router.ServeHTTP(w, req)

	assert.Equal(suite.T(), http.StatusNotFound, w.Code)
}

func (suite *UserManagementTestSuite) testPasswordManagement() {
	// Create user
	userData := map[string]interface{}{
		"username":   "passwordtestuser",
		"email":      "passwordtestuser@example.com",
		"password":   "InitialPass123!",
		"first_name": "Password",
		"last_name":  "Test",
		"role":       "ORG_USER",
	}

	jsonData, _ := json.Marshal(userData)
	req := httptest.NewRequest("POST", "/api/users", bytes.NewBuffer(jsonData))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer "+suite.adminToken)

	w := httptest.NewRecorder()
	suite.router.ServeHTTP(w, req)

	assert.Equal(suite.T(), http.StatusCreated, w.Code)

	var createResponse map[string]interface{}
	err := json.Unmarshal(w.Body.Bytes(), &createResponse)
	require.NoError(suite.T(), err)

	userID := createResponse["user"].(map[string]interface{})["id"].(string)

	// Activate user
	activateData := map[string]interface{}{
		"status": "ACTIVE",
	}

	jsonData, _ = json.Marshal(activateData)
	req = httptest.NewRequest("PUT", "/api/users/"+userID, bytes.NewBuffer(jsonData))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer "+suite.adminToken)

	w = httptest.NewRecorder()
	suite.router.ServeHTTP(w, req)

	assert.Equal(suite.T(), http.StatusOK, w.Code)

	// Login to get user token
	loginData := map[string]interface{}{
		"email":    "passwordtestuser@example.com",
		"password": "InitialPass123!",
	}

	jsonData, _ = json.Marshal(loginData)
	req = httptest.NewRequest("POST", "/api/auth/login", bytes.NewBuffer(jsonData))
	req.Header.Set("Content-Type", "application/json")

	w = httptest.NewRecorder()
	suite.router.ServeHTTP(w, req)

	assert.Equal(suite.T(), http.StatusOK, w.Code)

	var loginResponse map[string]interface{}
	err = json.Unmarshal(w.Body.Bytes(), &loginResponse)
	require.NoError(suite.T(), err)

	userToken := loginResponse["accessToken"].(string)

	// Test password change with wrong old password
	changePassData := map[string]interface{}{
		"old_password": "WrongOldPass",
		"new_password": "NewPass123!",
	}

	jsonData, _ = json.Marshal(changePassData)
	req = httptest.NewRequest("POST", "/api/users/"+userID+"/reset-password", bytes.NewBuffer(jsonData))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer "+userToken)

	w = httptest.NewRecorder()
	suite.router.ServeHTTP(w, req)

	assert.Equal(suite.T(), http.StatusBadRequest, w.Code)

	// Test password change with correct old password
	changePassData = map[string]interface{}{
		"old_password": "InitialPass123!",
		"new_password": "NewPass123!",
	}

	jsonData, _ = json.Marshal(changePassData)
	req = httptest.NewRequest("POST", "/api/users/"+userID+"/reset-password", bytes.NewBuffer(jsonData))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer "+userToken)

	w = httptest.NewRecorder()
	suite.router.ServeHTTP(w, req)

	assert.Equal(suite.T(), http.StatusOK, w.Code)

	// Test login with old password (should fail)
	loginData = map[string]interface{}{
		"email":    "passwordtestuser@example.com",
		"password": "InitialPass123!",
	}

	jsonData, _ = json.Marshal(loginData)
	req = httptest.NewRequest("POST", "/api/auth/login", bytes.NewBuffer(jsonData))
	req.Header.Set("Content-Type", "application/json")

	w = httptest.NewRecorder()
	suite.router.ServeHTTP(w, req)

	assert.Equal(suite.T(), http.StatusUnauthorized, w.Code)

	// Test login with new password (should succeed)
	loginData = map[string]interface{}{
		"email":    "passwordtestuser@example.com",
		"password": "NewPass123!",
	}

	jsonData, _ = json.Marshal(loginData)
	req = httptest.NewRequest("POST", "/api/auth/login", bytes.NewBuffer(jsonData))
	req.Header.Set("Content-Type", "application/json")

	w = httptest.NewRecorder()
	suite.router.ServeHTTP(w, req)

	assert.Equal(suite.T(), http.StatusOK, w.Code)

	// Cleanup
	req = httptest.NewRequest("DELETE", "/api/users/"+userID, nil)
	req.Header.Set("Authorization", "Bearer "+suite.adminToken)

	w = httptest.NewRecorder()
	suite.router.ServeHTTP(w, req)
}

func (suite *UserManagementTestSuite) testUserStatusManagement() {
	// Create user
	userData := map[string]interface{}{
		"username":   "statustestuser",
		"email":      "statustestuser@example.com",
		"password":   "TestPass123!",
		"first_name": "Status",
		"last_name":  "Test",
		"role":       "ORG_USER",
	}

	jsonData, _ := json.Marshal(userData)
	req := httptest.NewRequest("POST", "/api/users", bytes.NewBuffer(jsonData))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer "+suite.adminToken)

	w := httptest.NewRecorder()
	suite.router.ServeHTTP(w, req)

	assert.Equal(suite.T(), http.StatusCreated, w.Code)

	var createResponse map[string]interface{}
	err := json.Unmarshal(w.Body.Bytes(), &createResponse)
	require.NoError(suite.T(), err)

	userID := createResponse["user"].(map[string]interface{})["id"].(string)

	// Test status transitions
	statuses := []string{"ACTIVE", "PENDING", "SUSPENDED", "DISABLED", "ACTIVE"}

	for _, status := range statuses {
		statusData := map[string]interface{}{
			"status": status,
		}

		jsonData, _ = json.Marshal(statusData)
		req = httptest.NewRequest("PUT", "/api/users/"+userID, bytes.NewBuffer(jsonData))
		req.Header.Set("Content-Type", "application/json")
		req.Header.Set("Authorization", "Bearer "+suite.adminToken)

		w = httptest.NewRecorder()
		suite.router.ServeHTTP(w, req)

		assert.Equal(suite.T(), http.StatusOK, w.Code)

		var response map[string]interface{}
		err = json.Unmarshal(w.Body.Bytes(), &response)
		require.NoError(suite.T(), err)

		updatedStatus := response["user"].(map[string]interface{})["status"].(string)
		assert.Equal(suite.T(), status, updatedStatus)
	}

	// Test login with different statuses
	loginData := map[string]interface{}{
		"email":    "statustestuser@example.com",
		"password": "TestPass123!",
	}

	jsonData, _ = json.Marshal(loginData)
	req = httptest.NewRequest("POST", "/api/auth/login", bytes.NewBuffer(jsonData))
	req.Header.Set("Content-Type", "application/json")

	w = httptest.NewRecorder()
	suite.router.ServeHTTP(w, req)

	// Should succeed when status is ACTIVE
	assert.Equal(suite.T(), http.StatusOK, w.Code)

	// Set to DISABLED and test login
	disableData := map[string]interface{}{
		"status": "DISABLED",
	}

	jsonData, _ = json.Marshal(disableData)
	req = httptest.NewRequest("PUT", "/api/users/"+userID, bytes.NewBuffer(jsonData))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer "+suite.adminToken)

	w = httptest.NewRecorder()
	suite.router.ServeHTTP(w, req)

	// Try login with disabled user
	req = httptest.NewRequest("POST", "/api/auth/login", bytes.NewBuffer(jsonData))
	req.Header.Set("Content-Type", "application/json")

	w = httptest.NewRecorder()
	suite.router.ServeHTTP(w, req)

	assert.Equal(suite.T(), http.StatusUnauthorized, w.Code)

	// Cleanup
	req = httptest.NewRequest("DELETE", "/api/users/"+userID, nil)
	req.Header.Set("Authorization", "Bearer "+suite.adminToken)

	w = httptest.NewRecorder()
	suite.router.ServeHTTP(w, req)
}

func (suite *UserManagementTestSuite) testRoleAndPermissions() {
	// Test creating users with different roles
	roles := []string{"ORG_USER", "ORG_ADMIN", "AGENT_USER", "AGENT_ADMIN", "COMPLIANCE_USER"}

	for _, role := range roles {
		userData := map[string]interface{}{
			"username":   fmt.Sprintf("role%s", role),
			"email":      fmt.Sprintf("role%s@example.com", role),
			"password":   "TestPass123!",
			"first_name": "Role",
			"last_name":  "Test",
			"role":       role,
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
		require.NoError(suite.T(), err)

		createdRole := response["user"].(map[string]interface{})["role"].(string)
		assert.Equal(suite.T(), role, createdRole)

		// Cleanup
		userID := response["user"].(map[string]interface{})["id"].(string)
		req = httptest.NewRequest("DELETE", "/api/users/"+userID, nil)
		req.Header.Set("Authorization", "Bearer "+suite.adminToken)

		w = httptest.NewRecorder()
		suite.router.ServeHTTP(w, req)
	}
}

func (suite *UserManagementTestSuite) testInvitationFlow() {
	// Test user invitation
	inviteData := map[string]interface{}{
		"email":      "inviteduser@example.com",
		"first_name": "Invited",
		"last_name":  "User",
		"role":       "ORG_USER",
		"department": "IT",
		"position":   "Developer",
	}

	jsonData, _ := json.Marshal(inviteData)
	req := httptest.NewRequest("POST", "/api/users/invite", bytes.NewBuffer(jsonData))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer "+suite.adminToken)

	w := httptest.NewRecorder()
	suite.router.ServeHTTP(w, req)

	assert.Equal(suite.T(), http.StatusCreated, w.Code)

	var response map[string]interface{}
	err := json.Unmarshal(w.Body.Bytes(), &response)
	require.NoError(suite.T(), err)

	// Verify invitation was created
	assert.Contains(suite.T(), response, "invitation")
	assert.Contains(suite.T(), response, "tempPassword")

	// Cleanup - find and delete the invited user
	req = httptest.NewRequest("GET", "/api/users", nil)
	req.Header.Set("Authorization", "Bearer "+suite.adminToken)

	w = httptest.NewRecorder()
	suite.router.ServeHTTP(w, req)

	var usersResponse map[string]interface{}
	err = json.Unmarshal(w.Body.Bytes(), &usersResponse)
	require.NoError(suite.T(), err)

	users := usersResponse["users"].([]interface{})
	for _, user := range users {
		userMap := user.(map[string]interface{})
		if userMap["email"] == "inviteduser@example.com" {
			userID := userMap["id"].(string)
			req = httptest.NewRequest("DELETE", "/api/users/"+userID, nil)
			req.Header.Set("Authorization", "Bearer "+suite.adminToken)

			w = httptest.NewRecorder()
			suite.router.ServeHTTP(w, req)
			break
		}
	}
}

func (suite *UserManagementTestSuite) testAuditLogging() {
	// Create a user to generate audit logs
	userData := map[string]interface{}{
		"username":   "audittestuser",
		"email":      "audittestuser@example.com",
		"password":   "TestPass123!",
		"first_name": "Audit",
		"last_name":  "Test",
		"role":       "ORG_USER",
	}

	jsonData, _ := json.Marshal(userData)
	req := httptest.NewRequest("POST", "/api/users", bytes.NewBuffer(jsonData))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer "+suite.adminToken)

	w := httptest.NewRecorder()
	suite.router.ServeHTTP(w, req)

	assert.Equal(suite.T(), http.StatusCreated, w.Code)

	var createResponse map[string]interface{}
	err := json.Unmarshal(w.Body.Bytes(), &createResponse)
	require.NoError(suite.T(), err)

	userID := createResponse["user"].(map[string]interface{})["id"].(string)

	// Perform actions that should generate audit logs
	actions := []struct {
		method string
		path   string
		data   map[string]interface{}
	}{
		{"PUT", "/api/users/" + userID, map[string]interface{}{"status": "ACTIVE"}},
		{"PUT", "/api/users/" + userID, map[string]interface{}{"first_name": "Updated"}},
		{"DELETE", "/api/users/" + userID, nil},
	}

	for _, action := range actions {
		var req *http.Request
		if action.data != nil {
			jsonData, _ = json.Marshal(action.data)
			req = httptest.NewRequest(action.method, action.path, bytes.NewBuffer(jsonData))
			req.Header.Set("Content-Type", "application/json")
		} else {
			req = httptest.NewRequest(action.method, action.path, nil)
		}
		req.Header.Set("Authorization", "Bearer "+suite.adminToken)

		w = httptest.NewRecorder()
		suite.router.ServeHTTP(w, req)

		assert.True(suite.T(), w.Code == http.StatusOK || w.Code == http.StatusCreated)
	}

	// Note: In a real implementation, you would query the audit log table
	// to verify that these actions were logged
}

func (suite *UserManagementTestSuite) testEdgeCases() {
	// Test creating user with duplicate email
	userData := map[string]interface{}{
		"username":   "duplicateuser1",
		"email":      "duplicate@example.com",
		"password":   "TestPass123!",
		"first_name": "Duplicate",
		"last_name":  "User1",
		"role":       "ORG_USER",
	}

	jsonData, _ := json.Marshal(userData)
	req := httptest.NewRequest("POST", "/api/users", bytes.NewBuffer(jsonData))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer "+suite.adminToken)

	w := httptest.NewRecorder()
	suite.router.ServeHTTP(w, req)

	assert.Equal(suite.T(), http.StatusCreated, w.Code)

	// Try to create another user with same email
	userData["username"] = "duplicateuser2"
	userData["first_name"] = "Duplicate"
	userData["last_name"] = "User2"

	jsonData, _ = json.Marshal(userData)
	req = httptest.NewRequest("POST", "/api/users", bytes.NewBuffer(jsonData))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer "+suite.adminToken)

	w = httptest.NewRecorder()
	suite.router.ServeHTTP(w, req)

	// Should fail due to duplicate email
	assert.Equal(suite.T(), http.StatusConflict, w.Code)

	// Test accessing non-existent user
	req = httptest.NewRequest("GET", "/api/users/00000000-0000-0000-0000-000000000000", nil)
	req.Header.Set("Authorization", "Bearer "+suite.adminToken)

	w = httptest.NewRecorder()
	suite.router.ServeHTTP(w, req)

	assert.Equal(suite.T(), http.StatusNotFound, w.Code)

	// Test updating non-existent user
	updateData := map[string]interface{}{
		"first_name": "NonExistent",
	}

	jsonData, _ = json.Marshal(updateData)
	req = httptest.NewRequest("PUT", "/api/users/00000000-0000-0000-0000-000000000000", bytes.NewBuffer(jsonData))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer "+suite.adminToken)

	w = httptest.NewRecorder()
	suite.router.ServeHTTP(w, req)

	assert.Equal(suite.T(), http.StatusNotFound, w.Code)

	// Test deleting non-existent user
	req = httptest.NewRequest("DELETE", "/api/users/00000000-0000-0000-0000-000000000000", nil)
	req.Header.Set("Authorization", "Bearer "+suite.adminToken)

	w = httptest.NewRecorder()
	suite.router.ServeHTTP(w, req)

	assert.Equal(suite.T(), http.StatusNotFound, w.Code)

	// Test invalid role
	userData = map[string]interface{}{
		"username":   "invalidroleuser",
		"email":      "invalidrole@example.com",
		"password":   "TestPass123!",
		"first_name": "Invalid",
		"last_name":  "Role",
		"role":       "INVALID_ROLE",
	}

	jsonData, _ = json.Marshal(userData)
	req = httptest.NewRequest("POST", "/api/users", bytes.NewBuffer(jsonData))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer "+suite.adminToken)

	w = httptest.NewRecorder()
	suite.router.ServeHTTP(w, req)

	// Should fail due to invalid role
	assert.Equal(suite.T(), http.StatusBadRequest, w.Code)

	// Cleanup - delete the first duplicate user
	req = httptest.NewRequest("GET", "/api/users", nil)
	req.Header.Set("Authorization", "Bearer "+suite.adminToken)

	w = httptest.NewRecorder()
	suite.router.ServeHTTP(w, req)

	var usersResponse map[string]interface{}
	err := json.Unmarshal(w.Body.Bytes(), &usersResponse)
	require.NoError(suite.T(), err)

	users := usersResponse["users"].([]interface{})
	for _, user := range users {
		userMap := user.(map[string]interface{})
		if userMap["email"] == "duplicate@example.com" {
			userID := userMap["id"].(string)
			req = httptest.NewRequest("DELETE", "/api/users/"+userID, nil)
			req.Header.Set("Authorization", "Bearer "+suite.adminToken)

			w = httptest.NewRecorder()
			suite.router.ServeHTTP(w, req)
			break
		}
	}
}

func (suite *UserManagementTestSuite) TestCompleteUserManagementFlow() {
	suite.testCompleteUserManagementFlow()
}

func (suite *UserManagementTestSuite) TestAuthentication() {
	suite.testAuthentication()
}

func (suite *UserManagementTestSuite) TestUserCRUD() {
	suite.testUserCRUD()
}

func (suite *UserManagementTestSuite) TestPasswordManagement() {
	suite.testPasswordManagement()
}

func (suite *UserManagementTestSuite) TestUserStatusManagement() {
	suite.testUserStatusManagement()
}

func (suite *UserManagementTestSuite) TestRoleAndPermissions() {
	suite.testRoleAndPermissions()
}

func (suite *UserManagementTestSuite) TestInvitationFlow() {
	suite.testInvitationFlow()
}

func (suite *UserManagementTestSuite) TestAuditLogging() {
	suite.testAuditLogging()
}

func (suite *UserManagementTestSuite) TestEdgeCases() {
	suite.testEdgeCases()
}
