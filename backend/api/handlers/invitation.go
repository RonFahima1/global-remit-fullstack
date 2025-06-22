package handlers

import (
	"crypto/rand"
	"encoding/hex"
	"log"
	"net/http"
	"strings"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"

	"backend/internal/app"
	"backend/internal/domain"
)

type InvitationHandler struct {
	app *app.Application
}

func NewInvitationHandler(app *app.Application) *InvitationHandler {
	return &InvitationHandler{app: app}
}

// CreateInvitationRequest represents the request to create a new invitation
type CreateInvitationRequest struct {
	Email          string     `json:"email" binding:"required,email"`
	RoleID         int        `json:"role_id" binding:"required"`
	ExpiresInHours int        `json:"expires_in_hours"`
	OrganizationID *uuid.UUID `json:"organization_id,omitempty"`
	AgentID        *uuid.UUID `json:"agent_id,omitempty"`
	Message        string     `json:"message,omitempty"`
	Department     string     `json:"department,omitempty"`
	Position       string     `json:"position,omitempty"`
	ManagerID      *uuid.UUID `json:"manager_id,omitempty"`
}

// CreateInvitationResponse represents the response for creating an invitation
type CreateInvitationResponse struct {
	ID        uuid.UUID `json:"id"`
	Email     string    `json:"email"`
	Token     string    `json:"token"`
	ExpiresAt time.Time `json:"expires_at"`
	InviteURL string    `json:"invite_url"`
}

// CreateInvitation creates a new user invitation
func (h *InvitationHandler) CreateInvitation(c *gin.Context) {
	var req CreateInvitationRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid request", "details": err.Error()})
		return
	}

	// Get current user from context
	userIDStr, exists := c.Get("userID")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "unauthorized"})
		return
	}

	userID, err := uuid.Parse(userIDStr.(string))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid user ID"})
		return
	}

	// Check if user already exists
	existingUser, err := h.app.AuthRepo.GetUserByEmail(c.Request.Context(), req.Email)
	if err == nil && existingUser != nil {
		c.JSON(http.StatusConflict, gin.H{"error": "user already exists"})
		return
	}

	// Check if invitation already exists and is not expired
	existingInvitation, err := h.app.AuthRepo.GetInvitationByEmail(c.Request.Context(), req.Email)
	if err == nil && existingInvitation != nil && existingInvitation.ExpiresAt.After(time.Now()) {
		c.JSON(http.StatusConflict, gin.H{"error": "invitation already exists for this email"})
		return
	}

	// Set default expiration time if not provided
	if req.ExpiresInHours == 0 {
		req.ExpiresInHours = 72 // 3 days default
	}

	// Generate secure token
	token := generateSecureToken()

	// Create invitation
	invitation := &domain.UserInvitation{
		Email:     req.Email,
		Token:     token,
		RoleID:    req.RoleID,
		InvitedBy: userID,
		ExpiresAt: time.Now().Add(time.Duration(req.ExpiresInHours) * time.Hour),
		Status:    domain.InvitationStatusPending,
	}

	err = h.app.AuthRepo.CreateInvitation(c.Request.Context(), invitation)
	if err != nil {
		h.app.Logger.Error("Failed to create invitation", "email", req.Email, "error", err.Error())
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to create invitation"})
		return
	}

	// Log the invitation creation
	h.app.Logger.Info("Invitation created successfully",
		"email", req.Email,
		"invited_by", userID,
		"expires_at", invitation.ExpiresAt)

	// Generate invite URL
	baseURL := "http://localhost:3000" // TODO: Get from config
	inviteURL := baseURL + "/register?token=" + token

	response := CreateInvitationResponse{
		ID:        invitation.ID,
		Email:     invitation.Email,
		Token:     invitation.Token,
		ExpiresAt: invitation.ExpiresAt,
		InviteURL: inviteURL,
	}

	c.JSON(http.StatusCreated, response)
}

// ValidateInvitationRequest represents the request to validate an invitation
type ValidateInvitationRequest struct {
	Token string `json:"token" binding:"required"`
}

// ValidateInvitationResponse represents the response for validating an invitation
type ValidateInvitationResponse struct {
	Valid     bool      `json:"valid"`
	Email     string    `json:"email,omitempty"`
	RoleID    int       `json:"role_id,omitempty"`
	ExpiresAt time.Time `json:"expires_at,omitempty"`
	InvitedBy string    `json:"invited_by,omitempty"`
	Message   string    `json:"message,omitempty"`
}

// ValidateInvitation validates an invitation token
func (h *InvitationHandler) ValidateInvitation(c *gin.Context) {
	token := c.Query("token")
	if token == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "token is required"})
		return
	}

	invitation, err := h.app.AuthRepo.GetInvitationByToken(c.Request.Context(), token)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "invalid invitation token"})
		return
	}

	// Check if invitation is expired
	if invitation.ExpiresAt.Before(time.Now()) {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invitation has expired"})
		return
	}

	// Check if invitation is already accepted
	if invitation.Status == domain.InvitationStatusAccepted {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invitation has already been accepted"})
		return
	}

	// Get invited by user info
	invitedByUser, err := h.app.AuthRepo.GetUserByID(c.Request.Context(), invitation.InvitedBy.String())
	if err != nil {
		h.app.Logger.Error("Failed to get invited by user", "error", err.Error())
	}

	response := ValidateInvitationResponse{
		Valid:     true,
		Email:     invitation.Email,
		RoleID:    invitation.RoleID,
		ExpiresAt: invitation.ExpiresAt,
		InvitedBy: invitedByUser.Email,
	}

	c.JSON(http.StatusOK, response)
}

// AcceptInvitationRequest represents the request to accept an invitation
type AcceptInvitationRequest struct {
	Token      string `json:"token" binding:"required"`
	FirstName  string `json:"first_name" binding:"required"`
	LastName   string `json:"last_name" binding:"required"`
	Password   string `json:"password" binding:"required,min=8"`
	Phone      string `json:"phone,omitempty"`
	Department string `json:"department,omitempty"`
	Position   string `json:"position,omitempty"`
}

// AcceptInvitationResponse represents the response for accepting an invitation
type AcceptInvitationResponse struct {
	UserID uuid.UUID `json:"user_id"`
	Email  string    `json:"email"`
	Role   string    `json:"role"`
}

// AcceptInvitation accepts an invitation and creates a new user
func (h *InvitationHandler) AcceptInvitation(c *gin.Context) {
	log.Println("[AcceptInvitation] Handler start")
	var req AcceptInvitationRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid request", "details": err.Error()})
		return
	}

	// Validate invitation
	invitation, err := h.app.AuthRepo.GetInvitationByToken(c.Request.Context(), req.Token)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "invalid invitation token"})
		return
	}

	// Check if invitation is expired
	if invitation.ExpiresAt.Before(time.Now()) {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invitation has expired"})
		return
	}

	// Check if invitation is already accepted
	if invitation.Status == domain.InvitationStatusAccepted {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invitation has already been accepted"})
		return
	}

	// Check if user already exists
	existingUser, err := h.app.AuthRepo.GetUserByEmail(c.Request.Context(), invitation.Email)
	if err == nil && existingUser != nil {
		// If user exists but is in PENDING_VERIFICATION status, we can update them
		if existingUser.Status == domain.UserStatusPendingVerification {
			// Update the existing user with the provided information
			updates := map[string]interface{}{
				"first_name": req.FirstName,
				"last_name":  req.LastName,
				"status":     domain.UserStatusActive,
				"phone":      req.Phone,
				"department": req.Department,
				"position":   req.Position,
			}

			err = h.app.AuthRepo.UpdateUser(c.Request.Context(), existingUser.ID.String(), updates, existingUser.ID.String())
			if err != nil {
				h.app.Logger.Error("Failed to update existing user from invitation", "email", invitation.Email, "error", err.Error())
				c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to update user", "details": err.Error()})
				return
			}

			// Update the user's password
			err = h.app.AuthRepo.ChangePassword(c.Request.Context(), existingUser.ID.String(), req.Password)
			if err != nil {
				h.app.Logger.Error("Failed to update user password", "email", invitation.Email, "error", err.Error())
				c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to update password", "details": err.Error()})
				return
			}

			// Mark invitation as accepted
			invitation.Status = domain.InvitationStatusAccepted
			now := time.Now()
			invitation.AcceptedAt = &now
			invitation.AcceptedBy = &existingUser.ID

			err = h.app.AuthRepo.UpdateInvitation(c.Request.Context(), invitation)
			if err != nil {
				h.app.Logger.Error("Failed to update invitation status", "error", err.Error())
				// Don't fail the request, just log the error
			}

			// Log the invitation acceptance
			h.app.Logger.Info("Invitation accepted successfully for existing user",
				"email", invitation.Email,
				"user_id", existingUser.ID,
				"role", existingUser.Role)

			response := AcceptInvitationResponse{
				UserID: existingUser.ID,
				Email:  existingUser.Email,
				Role:   existingUser.Role,
			}

			c.JSON(http.StatusOK, response)
			return
		} else {
			// User exists but is not in PENDING_VERIFICATION status
			c.JSON(http.StatusConflict, gin.H{"error": "user already exists and is not pending verification"})
			return
		}
	}

	// Get role information
	role, err := h.app.AuthRepo.GetRoleByID(c.Request.Context(), invitation.RoleID)
	if err != nil {
		h.app.Logger.Error("Failed to get role", "role_id", invitation.RoleID, "error", err.Error())
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to get role information"})
		return
	}

	// Create new user
	username := ""
	if at := strings.Index(invitation.Email, "@"); at > 0 {
		username = invitation.Email[:at]
	} else {
		username = invitation.Email
	}
	user := &domain.User{
		Username:   username,
		Email:      invitation.Email,
		FirstName:  req.FirstName,
		LastName:   req.LastName,
		Status:     domain.UserStatusActive,
		Role:       role.Name,
		Phone:      &req.Phone,
		Department: &req.Department,
		Position:   &req.Position,
		InvitedBy:  &invitation.InvitedBy,
	}

	log.Println("[AcceptInvitation] Calling CreateUser")
	err = h.app.AuthRepo.CreateUser(c.Request.Context(), user, req.Password)
	if err != nil {
		log.Println("[AcceptInvitation] CreateUser failed:", err)
		h.app.Logger.Error("Failed to create user from invitation", "email", invitation.Email, "error", err.Error())
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to create user", "details": err.Error()})
		return
	}
	log.Println("[AcceptInvitation] CreateUser succeeded")

	// Mark invitation as accepted
	invitation.Status = domain.InvitationStatusAccepted
	invitation.AcceptedAt = &time.Time{}
	invitation.AcceptedBy = &user.ID

	err = h.app.AuthRepo.UpdateInvitation(c.Request.Context(), invitation)
	if err != nil {
		h.app.Logger.Error("Failed to update invitation status", "error", err.Error())
		// Don't fail the request, just log the error
	}

	// Log the invitation acceptance
	h.app.Logger.Info("Invitation accepted successfully",
		"email", invitation.Email,
		"user_id", user.ID,
		"role", role.Name)

	response := AcceptInvitationResponse{
		UserID: user.ID,
		Email:  user.Email,
		Role:   role.Name,
	}

	c.JSON(http.StatusCreated, response)
}

// ListInvitationsResponse represents the response for listing invitations
type ListInvitationsResponse struct {
	Invitations []InvitationInfo `json:"invitations"`
	Total       int              `json:"total"`
}

// InvitationInfo represents invitation information for listing
type InvitationInfo struct {
	ID         uuid.UUID  `json:"id"`
	Email      string     `json:"email"`
	RoleName   string     `json:"role_name"`
	Status     string     `json:"status"`
	Token      string     `json:"token"`
	ExpiresAt  time.Time  `json:"expires_at"`
	AcceptedAt *time.Time `json:"accepted_at,omitempty"`
	InvitedBy  string     `json:"invited_by"`
	CreatedAt  time.Time  `json:"created_at"`
}

// ListInvitations lists all invitations with optional filtering
func (h *InvitationHandler) ListInvitations(c *gin.Context) {
	status := c.Query("status")
	email := c.Query("email")

	invitations, err := h.app.AuthRepo.ListInvitations(c.Request.Context(), status, email)
	if err != nil {
		h.app.Logger.Error("Failed to list invitations", "error", err.Error())
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to list invitations"})
		return
	}

	// Convert to response format
	invitationInfos := make([]InvitationInfo, len(invitations))
	for i, invitation := range invitations {
		// Get role name
		role, err := h.app.AuthRepo.GetRoleByID(c.Request.Context(), invitation.RoleID)
		roleName := "Unknown"
		if err == nil && role != nil {
			roleName = role.Name
		}

		// Get invited by user info
		invitedByUser, err := h.app.AuthRepo.GetUserByID(c.Request.Context(), invitation.InvitedBy.String())
		invitedBy := "Unknown"
		if err == nil && invitedByUser != nil {
			invitedBy = invitedByUser.Email
		}

		invitationInfos[i] = InvitationInfo{
			ID:         invitation.ID,
			Email:      invitation.Email,
			RoleName:   roleName,
			Status:     invitation.Status,
			Token:      invitation.Token,
			ExpiresAt:  invitation.ExpiresAt,
			AcceptedAt: invitation.AcceptedAt,
			InvitedBy:  invitedBy,
			CreatedAt:  invitation.CreatedAt,
		}
	}

	response := ListInvitationsResponse{
		Invitations: invitationInfos,
		Total:       len(invitationInfos),
	}

	c.JSON(http.StatusOK, response)
}

// CancelInvitation cancels an invitation
func (h *InvitationHandler) CancelInvitation(c *gin.Context) {
	invitationID := c.Param("id")
	if invitationID == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invitation ID is required"})
		return
	}

	id, err := uuid.Parse(invitationID)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid invitation ID"})
		return
	}

	invitation, err := h.app.AuthRepo.GetInvitationByID(c.Request.Context(), id)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "invitation not found"})
		return
	}

	// Check if invitation is already accepted
	if invitation.Status == domain.InvitationStatusAccepted {
		c.JSON(http.StatusBadRequest, gin.H{"error": "cannot cancel accepted invitation"})
		return
	}

	// Cancel invitation
	invitation.Status = domain.InvitationStatusCancelled
	err = h.app.AuthRepo.UpdateInvitation(c.Request.Context(), invitation)
	if err != nil {
		h.app.Logger.Error("Failed to cancel invitation", "error", err.Error())
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to cancel invitation"})
		return
	}

	h.app.Logger.Info("Invitation cancelled successfully", "invitation_id", invitation.ID)

	c.JSON(http.StatusOK, gin.H{"message": "invitation cancelled successfully"})
}

// ResendInvitation resends an invitation with a new token
func (h *InvitationHandler) ResendInvitation(c *gin.Context) {
	invitationID := c.Param("id")
	if invitationID == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invitation ID is required"})
		return
	}

	id, err := uuid.Parse(invitationID)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid invitation ID"})
		return
	}

	invitation, err := h.app.AuthRepo.GetInvitationByID(c.Request.Context(), id)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "invitation not found"})
		return
	}

	// Check if invitation is already accepted
	if invitation.Status == domain.InvitationStatusAccepted {
		c.JSON(http.StatusBadRequest, gin.H{"error": "cannot resend accepted invitation"})
		return
	}

	// Generate new token and extend expiration
	newToken := generateSecureToken()
	invitation.Token = newToken
	invitation.ExpiresAt = time.Now().Add(72 * time.Hour) // 3 days
	invitation.Status = domain.InvitationStatusPending

	err = h.app.AuthRepo.UpdateInvitation(c.Request.Context(), invitation)
	if err != nil {
		h.app.Logger.Error("Failed to resend invitation", "error", err.Error())
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to resend invitation"})
		return
	}

	// Generate new invite URL
	baseURL := "http://localhost:3000" // TODO: Get from config
	inviteURL := baseURL + "/register?token=" + newToken

	response := CreateInvitationResponse{
		ID:        invitation.ID,
		Email:     invitation.Email,
		Token:     invitation.Token,
		ExpiresAt: invitation.ExpiresAt,
		InviteURL: inviteURL,
	}

	h.app.Logger.Info("Invitation resent successfully", "invitation_id", invitation.ID)

	c.JSON(http.StatusOK, response)
}

// generateSecureToken generates a secure random token
func generateSecureToken() string {
	bytes := make([]byte, 32)
	rand.Read(bytes)
	return hex.EncodeToString(bytes)
}
