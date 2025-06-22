package handlers

import (
	"net/http"

	"github.com/gin-gonic/gin"

	"backend/internal/app"
	"backend/internal/domain"
	"backend/internal/session"
	"backend/internal/utils/token"
	"database/sql"
	"time"
)

type AuthHandler struct {
	app *app.Application
}

func NewAuthHandler(app *app.Application) *AuthHandler {
	return &AuthHandler{app: app}
}

type RegisterUserRequest struct {
	Username  string `json:"username" binding:"required"`
	Email     string `json:"email" binding:"required,email"`
	Password  string `json:"password" binding:"required,min=8"`
	FirstName string `json:"first_name" binding:"required"`
	LastName  string `json:"last_name" binding:"required"`
}

func (h *AuthHandler) RegisterUser(c *gin.Context) {
	var req RegisterUserRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid request", "details": err.Error()})
		return
	}

	user := &domain.User{
		Username:  req.Username,
		Email:     req.Email,
		FirstName: req.FirstName,
		LastName:  req.LastName,
		Status:    "PENDING_VERIFICATION",
	}

	err := h.app.AuthRepo.CreateUser(c.Request.Context(), user, req.Password)
	if err != nil {
		h.app.Logger.Error("Failed to create user", "email", req.Email, "error", err.Error())
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to create user"})
		return
	}

	h.app.Logger.Info("User registration successful", "email", user.Email, "userID", user.ID)
	c.JSON(http.StatusCreated, user)
}

// LoginRequest and LoginResponse for login endpoint
type LoginRequest struct {
	Email    string `json:"email" binding:"required,email"`
	Password string `json:"password" binding:"required"`
}

type LoginResponse struct {
	AccessToken  string      `json:"accessToken"`
	RefreshToken string      `json:"refreshToken"`
	User         interface{} `json:"user"`
}

func (h *AuthHandler) Login(c *gin.Context) {
	var req LoginRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid request", "details": err.Error()})
		return
	}
	user, err := h.app.AuthRepo.AuthenticateUser(c.Request.Context(), req.Email, req.Password)
	if err != nil {
		h.app.Logger.Warn("Failed login attempt", "email", req.Email, "error", err.Error())
		if err.Error() == "password does not match" {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "invalid credentials", "detail": "password mismatch"})
		} else if err.Error() == "account is temporarily locked due to multiple failed login attempts" {
			c.JSON(http.StatusForbidden, gin.H{"error": "account locked", "detail": "account is temporarily locked due to multiple failed login attempts"})
		} else if err.Error() == "user is not active" {
			c.JSON(http.StatusForbidden, gin.H{"error": "account disabled", "detail": "user account is not active"})
		} else {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "invalid credentials"})
		}
		return
	}
	// Check if user account is locked
	if user.Status == "LOCKED" {
		h.app.Logger.Warn("Attempt to log in with locked account", "email", req.Email, "userID", user.ID)
		c.JSON(http.StatusForbidden, gin.H{"error": "Account is locked"})
		return
	}
	// Fetch permissions for user
	permissions, err := h.app.AuthRepo.GetUserPermissions(c.Request.Context(), user.ID.String())
	if err != nil {
		h.app.Logger.Error("Failed to fetch user permissions", "userID", user.ID, "error", err.Error())
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to fetch user permissions"})
		return
	}
	h.app.Logger.Info("User login successful", "email", user.Email, "userID", user.ID)
	// Create session
	sessMgr := session.NewRedisSessionManager()
	sess, err := sessMgr.Create(c.Request.Context(), &session.Session{
		UserID: user.ID.String(),
		Email:  user.Email,
		Role:   user.Role, // Use real role
		// Add more fields as needed
	}, c.ClientIP(), c.Request.UserAgent(), 30*time.Minute)
	if err != nil {
		h.app.Logger.Error("Failed to create session", "userID", user.ID, "error", err.Error())
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to create session", "details": err.Error()})
		return
	}
	// Issue JWTs with permissions
	accessToken, err := token.GenerateAccessToken(user, sess.ID, permissions)
	if err != nil {
		h.app.Logger.Error("Failed to issue access token", "userID", user.ID, "error", err.Error())
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to issue token", "details": err.Error()})
		return
	}
	refreshToken, err := token.GenerateRefreshToken(user, sess.ID, permissions)
	if err != nil {
		h.app.Logger.Error("Failed to issue refresh token", "userID", user.ID, "error", err.Error())
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to issue refresh token", "details": err.Error()})
		return
	}
	// Set cookies (optional, for Next.js)
	c.SetCookie("accessToken", accessToken, 1800, "/", "", true, true)
	c.SetCookie("refreshToken", refreshToken, 604800, "/", "", true, true)
	// Return tokens and user info
	c.JSON(http.StatusOK, LoginResponse{
		AccessToken:  accessToken,
		RefreshToken: refreshToken,
		User: gin.H{
			"id":          user.ID,
			"email":       user.Email,
			"name":        user.FirstName + " " + user.LastName,
			"role":        user.Role, // Use real role
			"status":      user.Status,
			"permissions": permissions,
			// Add more fields as needed
		},
	})
}

type RefreshRequest struct {
	RefreshToken string `json:"refreshToken" binding:"required"`
}

type RefreshResponse struct {
	AccessToken  string `json:"accessToken"`
	RefreshToken string `json:"refreshToken"`
}

func (h *AuthHandler) Refresh(c *gin.Context) {
	var req RefreshRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid request", "details": err.Error()})
		return
	}
	claims, err := token.ValidateRefreshToken(req.RefreshToken)
	if err != nil {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "invalid refresh token"})
		return
	}
	user, err := h.app.AuthRepo.GetUserByID(c.Request.Context(), claims.UserID)
	if err != nil {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "user not found"})
		return
	}
	// Fetch permissions for user
	permissions, err := h.app.AuthRepo.GetUserPermissions(c.Request.Context(), user.ID.String())
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to fetch user permissions"})
		return
	}
	// Optionally check session validity in Redis
	accessToken, err := token.GenerateAccessToken(user, claims.ID, permissions)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to issue token"})
		return
	}
	refreshToken, err := token.GenerateRefreshToken(user, claims.ID, permissions)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to issue refresh token"})
		return
	}
	c.SetCookie("accessToken", accessToken, 1800, "/", "", true, true)
	c.SetCookie("refreshToken", refreshToken, 604800, "/", "", true, true)
	c.JSON(http.StatusOK, RefreshResponse{
		AccessToken:  accessToken,
		RefreshToken: refreshToken,
	})
}

type LogoutRequest struct {
	RefreshToken string `json:"refreshToken"`
}

func (h *AuthHandler) Logout(c *gin.Context) {
	var req LogoutRequest
	_ = c.ShouldBindJSON(&req) // optional
	// Get session ID from token/cookie
	accessToken, err := c.Cookie("accessToken")
	if err != nil {
		accessToken = c.GetHeader("Authorization")
		if len(accessToken) > 7 && accessToken[:7] == "Bearer " {
			accessToken = accessToken[7:]
		}
	}
	claims, err := token.ValidateAccessToken(accessToken)
	if err != nil {
		h.app.Logger.Warn("Logout with invalid token", "error", err.Error())
		c.JSON(http.StatusUnauthorized, gin.H{"error": "invalid token"})
		return
	}
	sessMgr := session.NewRedisSessionManager()
	_ = sessMgr.Delete(c.Request.Context(), claims.ID)
	h.app.Logger.Info("User logout successful", "userID", claims.UserID, "sessionID", claims.ID)
	// Optionally blacklist JWT in Redis
	c.SetCookie("accessToken", "", -1, "/", "", true, true)
	c.SetCookie("refreshToken", "", -1, "/", "", true, true)
	c.JSON(http.StatusOK, gin.H{"message": "logged out"})
}

func (h *AuthHandler) Me(c *gin.Context) {
	accessToken, err := c.Cookie("accessToken")
	if err != nil {
		accessToken = c.GetHeader("Authorization")
		if len(accessToken) > 7 && accessToken[:7] == "Bearer " {
			accessToken = accessToken[7:]
		}
	}
	claims, err := token.ValidateAccessToken(accessToken)
	if err != nil {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "invalid token"})
		return
	}
	user, err := h.app.AuthRepo.GetUserByID(c.Request.Context(), claims.UserID)
	if err != nil {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "user not found"})
		return
	}
	c.JSON(http.StatusOK, gin.H{
		"id":    user.ID,
		"email": user.Email,
		"role":  user.Role, // Use real role
		// Add more fields as needed
	})
}

// TestSeedUser is a test-only endpoint to seed a user.
func (h *AuthHandler) TestSeedUser(c *gin.Context) {
	type SeedUserRequest struct {
		Email    string `json:"email" binding:"required,email"`
		Password string `json:"password" binding:"required"`
		Status   string `json:"status"` // e.g., ACTIVE, LOCKED
	}
	var req SeedUserRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid request", "details": err.Error()})
		return
	}

	status := "ACTIVE"
	if req.Status != "" {
		status = req.Status
	}

	existing, err := h.app.AuthRepo.GetUserByEmail(c.Request.Context(), req.Email)
	if err == nil && existing != nil {
		// User exists: update password and status
		err = h.app.AuthRepo.UpdateUserPasswordAndStatus(c.Request.Context(), existing.ID.String(), req.Password, status)
		if err != nil {
			h.app.Logger.Error("Failed to update test user", "email", req.Email, "error", err.Error())
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to update user"})
			return
		}
		h.app.Logger.Info("Test user updated successfully", "email", req.Email, "status", status)
		c.JSON(http.StatusOK, gin.H{"message": "user updated"})
		return
	} else if err != nil {
		if err != sql.ErrNoRows {
			h.app.Logger.Error("Failed to check for test user", "email", req.Email, "error", err)
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to check user", "details": err.Error()})
			return
		}
	}

	// User does not exist: create
	user := &domain.User{
		Username:  req.Email,
		Email:     req.Email,
		FirstName: "Seeded",
		LastName:  "User",
		Status:    status,
	}
	err = h.app.AuthRepo.CreateUser(c.Request.Context(), user, req.Password)
	if err != nil {
		h.app.Logger.Error("Failed to seed user", "email", req.Email, "error", err.Error())
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to seed user"})
		return
	}

	h.app.Logger.Info("Test user seeded successfully", "email", user.Email, "status", user.Status)
	c.JSON(http.StatusCreated, user)
}

// ChangePasswordRequest for password change endpoint
type ChangePasswordRequest struct {
	CurrentPassword string `json:"currentPassword" binding:"required"`
	NewPassword     string `json:"newPassword" binding:"required,min=8"`
}

func (h *AuthHandler) ChangePassword(c *gin.Context) {
	var req ChangePasswordRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid request", "details": err.Error()})
		return
	}

	// Get user from context (set by auth middleware)
	userID, exists := c.Get("userID")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "user not authenticated"})
		return
	}

	// Get user from database
	user, err := h.app.AuthRepo.GetUserByID(c.Request.Context(), userID.(string))
	if err != nil {
		h.app.Logger.Error("Failed to get user for password change", "userID", userID, "error", err.Error())
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to get user"})
		return
	}

	// Verify current password
	err = h.app.AuthRepo.VerifyPassword(c.Request.Context(), user.Email, req.CurrentPassword)
	if err != nil {
		h.app.Logger.Warn("Password change failed - incorrect current password", "userID", user.ID, "email", user.Email)
		c.JSON(http.StatusBadRequest, gin.H{"error": "current password is incorrect"})
		return
	}

	// Change password
	err = h.app.AuthRepo.ChangePassword(c.Request.Context(), user.ID.String(), req.NewPassword)
	if err != nil {
		h.app.Logger.Error("Failed to change password", "userID", user.ID, "error", err.Error())
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to change password"})
		return
	}

	h.app.Logger.Info("Password changed successfully", "userID", user.ID, "email", user.Email)
	c.JSON(http.StatusOK, gin.H{"message": "password changed successfully"})
}
