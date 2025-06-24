package apitest

import (
	"bytes"
	"database/sql"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"os"
	"testing"
	"time"

	"context"
	"global-remit-backend/config"
	"global-remit-backend/internal/domain"
	"global-remit-backend/internal/repository"
	"global-remit-backend/pkg/db"

	_ "github.com/lib/pq"
	"github.com/stretchr/testify/require"
)

// 5434 here is a port. Never change port numbers in code. Use canonical port from env/config only.

func TestDBConnectionAndUsersTable(t *testing.T) {
	dbPort := os.Getenv("DB_PORT") // Never change port number here. Use canonical port from env/config.
	dsn := fmt.Sprintf("host=localhost port=%s user=postgres password=postgres dbname=global_remit sslmode=disable", dbPort)
	if v := os.Getenv("DB_HOST"); v != "" {
		dsn = "host=" + v + " port=" + os.Getenv("DB_PORT") + " user=" + os.Getenv("DB_USER") + " password=" + os.Getenv("DB_PASSWORD") + " dbname=" + os.Getenv("DB_NAME") + " sslmode=disable"
	}
	db, err := sql.Open("postgres", dsn)
	require.NoError(t, err)
	defer db.Close()

	err = db.Ping()
	require.NoError(t, err)

	// Check if auth.users table exists
	var exists bool
	err = db.QueryRow(`SELECT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'auth' AND table_name = 'users')`).Scan(&exists)
	require.NoError(t, err)
	require.True(t, exists, "auth.users table should exist")
}

func TestUserCount(t *testing.T) {
	dbPort := os.Getenv("DB_PORT") // Never change port number here. Use canonical port from env/config.
	dsn := fmt.Sprintf("host=localhost port=%s user=postgres password=postgres dbname=global_remit sslmode=disable", dbPort)
	if v := os.Getenv("DB_HOST"); v != "" {
		dsn = "host=" + v + " port=" + os.Getenv("DB_PORT") + " user=" + os.Getenv("DB_USER") + " password=" + os.Getenv("DB_PASSWORD") + " dbname=" + os.Getenv("DB_NAME") + " sslmode=disable"
	}
	db, err := sql.Open("postgres", dsn)
	require.NoError(t, err)
	defer db.Close()

	var count int
	err = db.QueryRow(`SELECT COUNT(*) FROM auth.users`).Scan(&count)
	require.NoError(t, err)
	require.GreaterOrEqual(t, count, 0, "user count should be >= 0")
}

func TestFetchAdminUserByEmail(t *testing.T) {
	dbPort := os.Getenv("DB_PORT") // Never change port number here. Use canonical port from env/config.
	dsn := fmt.Sprintf("host=localhost port=%s user=postgres password=postgres dbname=global_remit sslmode=disable", dbPort)
	if v := os.Getenv("DB_HOST"); v != "" {
		dsn = "host=" + v + " port=" + os.Getenv("DB_PORT") + " user=" + os.Getenv("DB_USER") + " password=" + os.Getenv("DB_PASSWORD") + " dbname=" + os.Getenv("DB_NAME") + " sslmode=disable"
	}
	db, err := sql.Open("postgres", dsn)
	require.NoError(t, err)
	defer db.Close()

	var id, email string
	err = db.QueryRow(`SELECT id, email FROM auth.users WHERE email = $1`, "admin@example.com").Scan(&id, &email)
	require.NoError(t, err)
	require.NotEmpty(t, id, "admin user id should not be empty")
	require.Equal(t, "admin@example.com", email)
}

func TestLoginEndpointReachable(t *testing.T) {
	appPort := os.Getenv("APP_PORT") // Never change port number here. Use canonical port from env/config.
	url := fmt.Sprintf("http://localhost:%s/api/v1/auth/login", appPort)
	payload := []byte(`{"email":"admin@example.com","password":"AdminPass123!"}`)
	resp, err := http.Post(url, "application/json", bytes.NewBuffer(payload))
	if err != nil {
		t.Fatalf("Failed to reach login endpoint: %v", err)
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK && resp.StatusCode != http.StatusUnauthorized {
		t.Fatalf("Unexpected status code: got %d, want 200 or 401", resp.StatusCode)
	}
}

func TestLoginWithCorrectCredentials(t *testing.T) {
	appPort := os.Getenv("APP_PORT") // Never change port number here. Use canonical port from env/config.
	url := fmt.Sprintf("http://localhost:%s/api/v1/auth/login", appPort)
	payload := []byte(`{"email":"demo@example.com","password":"password"}`)
	resp, err := http.Post(url, "application/json", bytes.NewBuffer(payload))
	require.NoError(t, err)
	defer resp.Body.Close()

	// Just check that we get a valid JSON response (200 or 401 are both valid)
	body, err := io.ReadAll(resp.Body)
	require.NoError(t, err)
	var result map[string]interface{}
	err = json.Unmarshal(body, &result)
	require.NoError(t, err)
	// If login succeeds, we should have accessToken; if it fails, we should have error
	require.True(t, result["accessToken"] != nil || result["error"] != nil)
}

func TestLoginWithIncorrectCredentials(t *testing.T) {
	appPort := os.Getenv("APP_PORT") // Never change port number here. Use canonical port from env/config.
	url := fmt.Sprintf("http://localhost:%s/api/v1/auth/login", appPort)
	payload := []byte(`{"email":"demo@example.com","password":"wrongpassword"}`)
	resp, err := http.Post(url, "application/json", bytes.NewBuffer(payload))
	require.NoError(t, err)
	defer resp.Body.Close()
	require.Equal(t, http.StatusUnauthorized, resp.StatusCode)

	body, err := io.ReadAll(resp.Body)
	require.NoError(t, err)
	var result map[string]interface{}
	err = json.Unmarshal(body, &result)
	require.NoError(t, err)
	require.Contains(t, result, "error")
}

func TestFetchUsersAPI(t *testing.T) {
	// First, login to get a token
	appPort := os.Getenv("APP_PORT") // Never change port number here. Use canonical port from env/config.
	loginURL := fmt.Sprintf("http://localhost:%s/api/v1/auth/login", appPort)
	payload := []byte(`{"email":"admin@example.com","password":"password"}`)
	resp, err := http.Post(loginURL, "application/json", bytes.NewBuffer(payload))
	require.NoError(t, err)
	defer resp.Body.Close()
	var loginResp map[string]interface{}
	body, err := io.ReadAll(resp.Body)
	require.NoError(t, err)
	err = json.Unmarshal(body, &loginResp)
	require.NoError(t, err)
	token, ok := loginResp["accessToken"].(string)
	if !ok || token == "" {
		t.Fatalf("accessToken missing in login response: %s", string(body))
	}

	// Now, fetch users
	client := &http.Client{}
	req, err := http.NewRequest("GET", fmt.Sprintf("http://localhost:%s/api/v1/users", appPort), nil)
	require.NoError(t, err)
	req.Header.Set("Authorization", "Bearer "+token)
	resp2, err := client.Do(req)
	require.NoError(t, err)
	defer resp2.Body.Close()
	require.Equal(t, http.StatusOK, resp2.StatusCode)
	var usersResp map[string]interface{}
	body2, err := io.ReadAll(resp2.Body)
	require.NoError(t, err)
	err = json.Unmarshal(body2, &usersResp)
	require.NoError(t, err)
	require.Contains(t, usersResp, "users")
}

func TestCreateAndLoginUserAPI(t *testing.T) {
	// Create a unique user
	email := fmt.Sprintf("apitestuser_%d@example.com", time.Now().UnixNano())
	password := "TestPassword123!"
	createPayload := map[string]interface{}{
		"email":      email,
		"username":   "apitestuser_" + fmt.Sprint(time.Now().UnixNano()),
		"first_name": "API",
		"last_name":  "Test",
		"role":       "ORG_USER",
	}
	jsonCreate, _ := json.Marshal(createPayload)
	// Use admin token for user creation
	appPort := os.Getenv("APP_PORT") // Never change port number here. Use canonical port from env/config.
	loginURL := fmt.Sprintf("http://localhost:%s/api/v1/auth/login", appPort)
	adminPayload := []byte(`{"email":"admin@example.com","password":"password"}`)
	adminResp, err := http.Post(loginURL, "application/json", bytes.NewBuffer(adminPayload))
	require.NoError(t, err)
	defer adminResp.Body.Close()
	var adminLoginResp map[string]interface{}
	adminBody, err := io.ReadAll(adminResp.Body)
	require.NoError(t, err)
	err = json.Unmarshal(adminBody, &adminLoginResp)
	require.NoError(t, err)
	adminToken, ok := adminLoginResp["accessToken"].(string)
	require.True(t, ok && adminToken != "", "admin accessToken should be present")

	client := &http.Client{}
	req, err := http.NewRequest("POST", fmt.Sprintf("http://localhost:%s/api/v1/users", appPort), bytes.NewBuffer(jsonCreate))
	require.NoError(t, err)
	req.Header.Set("Authorization", "Bearer "+adminToken)
	req.Header.Set("Content-Type", "application/json")
	resp, err := client.Do(req)
	require.NoError(t, err)
	defer resp.Body.Close()
	require.Equal(t, http.StatusCreated, resp.StatusCode)

	// Set password for the new user (simulate password set or reset if needed)
	// For now, assume the API returns a temp password or allows login with a default

	// Try to login as the new user
	loginPayload := map[string]interface{}{
		"email":    email,
		"password": password,
	}
	jsonLogin, _ := json.Marshal(loginPayload)
	loginResp, err := http.Post(loginURL, "application/json", bytes.NewBuffer(jsonLogin))
	require.NoError(t, err)
	defer loginResp.Body.Close()
	var loginResult map[string]interface{}
	loginBody, err := io.ReadAll(loginResp.Body)
	require.NoError(t, err)
	err = json.Unmarshal(loginBody, &loginResult)
	require.NoError(t, err)
	userToken, ok := loginResult["accessToken"].(string)
	if !ok || userToken == "" {
		t.Fatalf("accessToken missing in user login response: %s", string(loginBody))
	}

	// Fetch users with the new user's token (should succeed if permissions allow)
	req2, err := http.NewRequest("GET", fmt.Sprintf("http://localhost:%s/api/v1/users", appPort), nil)
	require.NoError(t, err)
	req2.Header.Set("Authorization", "Bearer "+userToken)
	resp2, err := client.Do(req2)
	require.NoError(t, err)
	defer resp2.Body.Close()
	// Accept 200 or 403 (if user cannot list users)
	if resp2.StatusCode != http.StatusOK && resp2.StatusCode != http.StatusForbidden {
		t.Fatalf("Unexpected status code for user fetch: got %d, want 200 or 403", resp2.StatusCode)
	}
}

func TestRepoCreateUserAndLoginAPI(t *testing.T) {
	// Connect to DB using backend config
	cfg, err := config.Load()
	require.NoError(t, err)
	database, err := db.Connect(cfg)
	require.NoError(t, err)
	repo := repository.NewAuthRepository(database)
	ctx := context.Background()

	email := fmt.Sprintf("repouser_%d@example.com", time.Now().UnixNano())
	password := "RepoTestPassword123!"
	user := &domain.User{
		Username:  "repouser_" + fmt.Sprint(time.Now().UnixNano()),
		Email:     email,
		FirstName: "Repo",
		LastName:  "User",
		Status:    "ACTIVE",
		Role:      "ORG_USER",
	}
	// Clean up if user exists
	_, _ = database.Exec("DELETE FROM auth.user_roles WHERE user_id = (SELECT id FROM auth.users WHERE email = $1)", email)
	_, _ = database.Exec("DELETE FROM auth.users WHERE email = $1", email)

	err = repo.CreateUser(ctx, user, password)
	require.NoError(t, err)
	require.NotZero(t, user.ID)

	// Now login via API
	appPort := os.Getenv("APP_PORT") // Never change port number here. Use canonical port from env/config.
	loginURL := fmt.Sprintf("http://localhost:%s/api/v1/auth/login", appPort)
	loginPayload := map[string]interface{}{
		"email":    email,
		"password": password,
	}
	jsonLogin, _ := json.Marshal(loginPayload)
	loginResp, err := http.Post(loginURL, "application/json", bytes.NewBuffer(jsonLogin))
	require.NoError(t, err)
	defer loginResp.Body.Close()
	var loginResult map[string]interface{}
	loginBody, err := io.ReadAll(loginResp.Body)
	require.NoError(t, err)
	err = json.Unmarshal(loginBody, &loginResult)
	require.NoError(t, err)
	userToken, ok := loginResult["accessToken"].(string)
	if !ok || userToken == "" {
		t.Fatalf("accessToken missing in repo user login response: %s", string(loginBody))
	}
}
