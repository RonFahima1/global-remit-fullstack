package handlers

import (
	"math/rand"
	"net/http"
	"strconv"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"

	"backend/internal/app"
	"backend/internal/domain"
)

type UserManagementHandler struct {
	app *app.Application
}

func NewUserManagementHandler(app *app.Application) *UserManagementHandler {
	return &UserManagementHandler{app: app}
}

// GetUsers returns a list of all users with pagination
func (h *UserManagementHandler) GetUsers(c *gin.Context) {
	page, _ := strconv.Atoi(c.DefaultQuery("page", "1"))
	limit, _ := strconv.Atoi(c.DefaultQuery("limit", "50"))
	status := c.Query("status")
	role := c.Query("role")
	search := c.Query("search")

	users, total, err := h.app.AuthRepo.ListUsers(c.Request.Context(), page, limit, status, role, search)
	if err != nil {
		h.app.Logger.Error("Failed to fetch users", "error", err.Error())
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to fetch users"})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"users": users,
		"total": total,
		"page":  page,
		"limit": limit,
	})
}

// GetUser returns a single user by ID
func (h *UserManagementHandler) GetUser(c *gin.Context) {
	userID := c.Param("id")
	if userID == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "user ID is required"})
		return
	}

	user, err := h.app.AuthRepo.GetUserByID(c.Request.Context(), userID)
	if err != nil {
		h.app.Logger.Error("Failed to fetch user", "userID", userID, "error", err.Error())
		c.JSON(http.StatusNotFound, gin.H{"error": "user not found"})
		return
	}

	c.JSON(http.StatusOK, user)
}

// CreateUser creates a new user
func (h *UserManagementHandler) CreateUser(c *gin.Context) {
	var req struct {
		Email          string `json:"email" binding:"required,email"`
		Username       string `json:"username" binding:"required"`
		FirstName      string `json:"first_name" binding:"required"`
		LastName       string `json:"last_name" binding:"required"`
		Role           string `json:"role" binding:"required"`
		Department     string `json:"department"`
		Position       string `json:"position"`
		Phone          string `json:"phone"`
		EmployeeID     string `json:"employee_id"`
		HireDate       string `json:"hire_date"`
		SendInvitation bool   `json:"send_invitation"`
	}

	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid request", "details": err.Error()})
		return
	}

	// Get the current user (admin creating the user)
	adminID, exists := c.Get("userID")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "user not authenticated"})
		return
	}

	user := &domain.User{
		Username:  req.Username,
		Email:     req.Email,
		FirstName: req.FirstName,
		LastName:  req.LastName,
		Role:      req.Role,
		Status:    "PENDING_VERIFICATION",
	}

	// Generate a temporary password if not sending invitation
	var tempPassword string
	if !req.SendInvitation {
		tempPassword = generateTempPassword()
	}

	err := h.app.AuthRepo.CreateUser(c.Request.Context(), user, tempPassword)
	if err != nil {
		h.app.Logger.Error("Failed to create user", "email", req.Email, "error", err.Error())
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to create user"})
		return
	}

	// If sending invitation, create an invitation
	if req.SendInvitation {
		// Get role ID from role name
		role, err := h.app.AuthRepo.GetRoleByName(c.Request.Context(), req.Role)
		if err != nil {
			h.app.Logger.Error("Failed to get role for invitation", "role", req.Role, "error", err.Error())
			c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to get role"})
			return
		}

		// Generate invitation token
		token := uuid.New().String()

		// Set expiration time (7 days from now)
		expiresAt := time.Now().Add(7 * 24 * time.Hour)

		invitation := &domain.UserInvitation{
			Email:     req.Email,
			Token:     token,
			RoleID:    role.ID,
			InvitedBy: uuid.MustParse(adminID.(string)),
			ExpiresAt: expiresAt,
			Status:    domain.InvitationStatusPending,
		}
		err = h.app.AuthRepo.CreateInvitation(c.Request.Context(), invitation)
		if err != nil {
			h.app.Logger.Error("Failed to create invitation", "email", req.Email, "error", err.Error())
			// Don't fail the user creation, just log the error
		}
	}

	h.app.Logger.Info("User created successfully", "email", user.Email, "userID", user.ID)
	c.JSON(http.StatusCreated, gin.H{
		"user":         user,
		"tempPassword": tempPassword,
	})
}

// UpdateUser updates an existing user
func (h *UserManagementHandler) UpdateUser(c *gin.Context) {
	userID := c.Param("id")
	if userID == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "user ID is required"})
		return
	}

	var req struct {
		FirstName       string `json:"first_name"`
		LastName        string `json:"last_name"`
		Status          string `json:"status"`
		Role            string `json:"role"`
		Department      string `json:"department"`
		Position        string `json:"position"`
		Phone           string `json:"phone"`
		EmployeeID      string `json:"employee_id"`
		HireDate        string `json:"hire_date"`
		TerminationDate string `json:"termination_date"`
	}

	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid request", "details": err.Error()})
		return
	}

	// Get the current user (admin updating the user)
	adminID, exists := c.Get("userID")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "user not authenticated"})
		return
	}

	// Convert struct to map for dynamic updates
	updates := make(map[string]interface{})
	if req.FirstName != "" {
		updates["first_name"] = req.FirstName
	}
	if req.LastName != "" {
		updates["last_name"] = req.LastName
	}
	if req.Status != "" {
		updates["status"] = req.Status
	}
	if req.Role != "" {
		updates["role"] = req.Role
	}
	if req.Department != "" {
		updates["department"] = req.Department
	}
	if req.Position != "" {
		updates["position"] = req.Position
	}
	if req.Phone != "" {
		updates["phone"] = req.Phone
	}
	if req.EmployeeID != "" {
		updates["employee_id"] = req.EmployeeID
	}
	if req.HireDate != "" {
		updates["hire_date"] = req.HireDate
	}
	if req.TerminationDate != "" {
		updates["termination_date"] = req.TerminationDate
	}

	err := h.app.AuthRepo.UpdateUser(c.Request.Context(), userID, updates, adminID.(string))
	if err != nil {
		h.app.Logger.Error("Failed to update user", "userID", userID, "error", err.Error())
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to update user"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "user updated successfully"})
}

// UpdateUserStatus updates a user's status
func (h *UserManagementHandler) UpdateUserStatus(c *gin.Context) {
	userID := c.Param("id")
	if userID == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "user ID is required"})
		return
	}

	var req struct {
		Status string `json:"status" binding:"required"`
		Reason string `json:"reason"`
	}

	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid request", "details": err.Error()})
		return
	}

	// Get the current user (admin updating the status)
	adminID, exists := c.Get("userID")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "user not authenticated"})
		return
	}

	err := h.app.AuthRepo.UpdateUserStatus(c.Request.Context(), userID, req.Status, req.Reason, adminID.(string))
	if err != nil {
		h.app.Logger.Error("Failed to update user status", "userID", userID, "error", err.Error())
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to update user status"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "user status updated successfully"})
}

// ResetUserPassword resets a user's password (admin function)
func (h *UserManagementHandler) ResetUserPassword(c *gin.Context) {
	userID := c.Param("id")
	if userID == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "user ID is required"})
		return
	}

	var req struct {
		NewPassword string `json:"newPassword" binding:"required,min=8"`
	}

	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid request", "details": err.Error()})
		return
	}

	err := h.app.AuthRepo.ChangePassword(c.Request.Context(), userID, req.NewPassword)
	if err != nil {
		h.app.Logger.Error("Failed to reset user password", "userID", userID, "error", err.Error())
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to reset password"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "password reset successfully"})
}

// DeleteUser soft deletes a user
func (h *UserManagementHandler) DeleteUser(c *gin.Context) {
	userID := c.Param("id")
	if userID == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "user ID is required"})
		return
	}

	// Get the current user (admin deleting the user)
	adminID, exists := c.Get("userID")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "user not authenticated"})
		return
	}

	err := h.app.AuthRepo.DeleteUser(c.Request.Context(), userID, adminID.(string))
	if err != nil {
		h.app.Logger.Error("Failed to delete user", "userID", userID, "error", err.Error())
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to delete user"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "user deleted successfully"})
}

// GetRoles returns all available roles
func (h *UserManagementHandler) GetRoles(c *gin.Context) {
	roles, err := h.app.AuthRepo.GetRoles(c.Request.Context())
	if err != nil {
		h.app.Logger.Error("Failed to fetch roles", "error", err.Error())
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to fetch roles"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"roles": roles})
}

// GetUserPermissions returns permissions for a specific user
func (h *UserManagementHandler) GetUserPermissions(c *gin.Context) {
	userID := c.Param("id")
	if userID == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "user ID is required"})
		return
	}

	permissions, err := h.app.AuthRepo.GetUserPermissions(c.Request.Context(), userID)
	if err != nil {
		h.app.Logger.Error("Failed to fetch user permissions", "userID", userID, "error", err.Error())
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to fetch user permissions"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"permissions": permissions})
}

// SearchUsers searches for users by various criteria
func (h *UserManagementHandler) SearchUsers(c *gin.Context) {
	query := c.Query("q")
	if query == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "search query is required"})
		return
	}

	users, err := h.app.AuthRepo.SearchUsers(c.Request.Context(), query)
	if err != nil {
		h.app.Logger.Error("Failed to search users", "query", query, "error", err.Error())
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to search users"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"users": users})
}

// Helper function to generate temporary password
func generateTempPassword() string {
	const charset = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#$%^&*"
	password := make([]byte, 12)
	for i := range password {
		password[i] = charset[rand.Intn(len(charset))]
	}
	return string(password)
}

// Test endpoint to verify route registration
func (h *UserManagementHandler) Test(c *gin.Context) {
	c.JSON(http.StatusOK, gin.H{"message": "User management handler is working"})
}
