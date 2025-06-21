package apitest

import (
	"bytes"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"os"
	"testing"

	"backend/api/routes"
	"backend/internal/utils/token"

	"github.com/gin-gonic/gin"
	"github.com/jmoiron/sqlx"
	_ "github.com/lib/pq"
	"github.com/stretchr/testify/require"
)

func setupTestRouter(t *testing.T) *gin.Engine {
	os.Setenv("JWT_PRIVATE_KEY", "/Users/ron/Downloads/ProjectRoot/jwt_private.pem")
	os.Setenv("JWT_PUBLIC_KEY", "/Users/ron/Downloads/ProjectRoot/jwt_public.pem")
	err := token.LoadKeys()
	if err != nil {
		t.Fatalf("Failed to load JWT keys: %v", err)
	}
	dsn := os.Getenv("TEST_DATABASE_URL")
	if dsn == "" {
		t.Skip("TEST_DATABASE_URL not set; skipping integration test")
	}
	db, err := sqlx.Open("postgres", dsn)
	require.NoError(t, err)
	return routes.SetupRouter(db)
}

func seedTestUser(t *testing.T, r *gin.Engine, email, password, status string) {
	w := httptest.NewRecorder()
	body := map[string]string{
		"email":    email,
		"password": password,
		"status":   status,
	}
	b, _ := json.Marshal(body)
	req, _ := http.NewRequest("POST", "/api/v1/test/seed-user", bytes.NewReader(b))
	req.Header.Set("Content-Type", "application/json")
	r.ServeHTTP(w, req)
	require.True(t, w.Code == http.StatusOK || w.Code == http.StatusCreated)
}

func seedUserWithPermission(t *testing.T, r *gin.Engine, email, password, status, role, perm string) {
	seedTestUser(t, r, email, password, status)
	dsn := os.Getenv("TEST_DATABASE_URL")
	db, err := sqlx.Open("postgres", dsn)
	require.NoError(t, err)
	defer db.Close()
	// Ensure role exists
	var roleID int
	err = db.QueryRow("SELECT id FROM auth.roles WHERE name = $1", role).Scan(&roleID)
	if err != nil {
		err = db.QueryRow(`INSERT INTO auth.roles (name, description, is_system, created_at, updated_at) VALUES ($1, $2, true, NOW(), NOW()) RETURNING id`, role, "Test role").Scan(&roleID)
		require.NoError(t, err)
	}
	// Ensure permission exists
	var permID int
	err = db.QueryRow("SELECT id FROM auth.permissions WHERE code = $1", perm).Scan(&permID)
	if err != nil {
		err = db.QueryRow(`INSERT INTO auth.permissions (code, name, category, created_at) VALUES ($1, $2, $3, NOW()) RETURNING id`, perm, perm, "Test").Scan(&permID)
		require.NoError(t, err)
	}
	// Map permission to role
	_, _ = db.Exec(`INSERT INTO auth.role_permissions (role_id, permission_id, created_at) VALUES ($1, $2, NOW()) ON CONFLICT DO NOTHING`, roleID, permID)
	// Map user to role
	var userID string
	err = db.QueryRow("SELECT id FROM auth.users WHERE email = $1", email).Scan(&userID)
	require.NoError(t, err)
	_, _ = db.Exec(`INSERT INTO auth.user_roles (user_id, role_id, created_at) VALUES ($1, $2, NOW()) ON CONFLICT DO NOTHING`, userID, roleID)
}

func TestAuthAPI_Login_Success(t *testing.T) {
	r := setupTestRouter(t)
	seedTestUser(t, r, "testuser@example.com", "TestPassword123!", "ACTIVE")
	w := httptest.NewRecorder()
	body := map[string]string{
		"email":    "testuser@example.com",
		"password": "TestPassword123!",
	}
	b, _ := json.Marshal(body)
	req, _ := http.NewRequest("POST", "/api/v1/auth/login", bytes.NewReader(b))
	req.Header.Set("Content-Type", "application/json")
	r.ServeHTTP(w, req)
	require.Equal(t, http.StatusOK, w.Code)
	// TODO: Check response for tokens, user info, etc.
}

func TestAuthAPI_Login_WrongPassword(t *testing.T) {
	r := setupTestRouter(t)
	seedTestUser(t, r, "testuser@example.com", "TestPassword123!", "ACTIVE")
	w := httptest.NewRecorder()
	body := map[string]string{
		"email":    "testuser@example.com",
		"password": "WrongPassword!",
	}
	b, _ := json.Marshal(body)
	req, _ := http.NewRequest("POST", "/api/v1/auth/login", bytes.NewReader(b))
	req.Header.Set("Content-Type", "application/json")
	r.ServeHTTP(w, req)
	require.Equal(t, http.StatusUnauthorized, w.Code)
}

func TestAuthAPI_Login_LockedUser(t *testing.T) {
	r := setupTestRouter(t)
	seedTestUser(t, r, "lockeduser@example.com", "TestPassword123!", "LOCKED")
	w := httptest.NewRecorder()
	body := map[string]string{
		"email":    "lockeduser@example.com",
		"password": "TestPassword123!",
	}
	b, _ := json.Marshal(body)
	req, _ := http.NewRequest("POST", "/api/v1/auth/login", bytes.NewReader(b))
	req.Header.Set("Content-Type", "application/json")
	r.ServeHTTP(w, req)
	require.Equal(t, http.StatusUnauthorized, w.Code)
}

func getAccessToken(t *testing.T, r *gin.Engine, email, password string) string {
	w := httptest.NewRecorder()
	body := map[string]string{
		"email":    email,
		"password": password,
	}
	b, _ := json.Marshal(body)
	req, _ := http.NewRequest("POST", "/api/v1/auth/login", bytes.NewReader(b))
	req.Header.Set("Content-Type", "application/json")
	r.ServeHTTP(w, req)
	require.Equal(t, http.StatusOK, w.Code)
	var resp struct {
		AccessToken string `json:"accessToken"`
	}
	err := json.Unmarshal(w.Body.Bytes(), &resp)
	require.NoError(t, err)
	return resp.AccessToken
}

func TestAuthAPI_Me_ValidToken(t *testing.T) {
	r := setupTestRouter(t)
	seedTestUser(t, r, "testuser@example.com", "TestPassword123!", "ACTIVE")
	token := getAccessToken(t, r, "testuser@example.com", "TestPassword123!")
	w := httptest.NewRecorder()
	req, _ := http.NewRequest("GET", "/api/v1/auth/me", nil)
	req.Header.Set("Authorization", "Bearer "+token)
	r.ServeHTTP(w, req)
	require.Equal(t, http.StatusOK, w.Code)
	// TODO: Check user info in response
}

func TestAuthAPI_Me_InvalidToken(t *testing.T) {
	r := setupTestRouter(t)
	w := httptest.NewRecorder()
	req, _ := http.NewRequest("GET", "/api/v1/auth/me", nil)
	req.Header.Set("Authorization", "Bearer invalidtoken")
	r.ServeHTTP(w, req)
	require.Equal(t, http.StatusUnauthorized, w.Code)
}

func TestAuthAPI_Me_NoToken(t *testing.T) {
	r := setupTestRouter(t)
	w := httptest.NewRecorder()
	req, _ := http.NewRequest("GET", "/api/v1/auth/me", nil)
	r.ServeHTTP(w, req)
	require.Equal(t, http.StatusUnauthorized, w.Code)
}

// Scaffold: Permission-protected endpoint test
func TestClientsEndpoint_Permission(t *testing.T) {
	r := setupTestRouter(t)
	// User with permission
	emailAllowed := "allowed@example.com"
	password := "TestPassword123!"
	seedUserWithPermission(t, r, emailAllowed, password, "ACTIVE", "ORG_ADMIN", "clients:read")
	tokenAllowed := getAccessToken(t, r, emailAllowed, password)
	w := httptest.NewRecorder()
	req, _ := http.NewRequest("GET", "/api/v1/clients", nil)
	req.Header.Set("Authorization", "Bearer "+tokenAllowed)
	r.ServeHTTP(w, req)
	require.Equal(t, http.StatusOK, w.Code)

	// User without permission
	emailDenied := "denied@example.com"
	seedTestUser(t, r, emailDenied, password, "ACTIVE")
	// Remove all roles/permissions for this user
	dsn := os.Getenv("TEST_DATABASE_URL")
	db, err := sqlx.Open("postgres", dsn)
	require.NoError(t, err)
	defer db.Close()
	var userID string
	err = db.QueryRow("SELECT id FROM auth.users WHERE email = $1", emailDenied).Scan(&userID)
	require.NoError(t, err)
	_, _ = db.Exec("DELETE FROM auth.user_roles WHERE user_id = $1", userID)
	tokenDenied := getAccessToken(t, r, emailDenied, password)
	w = httptest.NewRecorder()
	req, _ = http.NewRequest("GET", "/api/v1/clients", nil)
	req.Header.Set("Authorization", "Bearer "+tokenDenied)
	r.ServeHTTP(w, req)
	require.Equal(t, http.StatusForbidden, w.Code)

	// No token
	w = httptest.NewRecorder()
	req, _ = http.NewRequest("GET", "/api/v1/clients", nil)
	r.ServeHTTP(w, req)
	require.Equal(t, http.StatusUnauthorized, w.Code)
}
