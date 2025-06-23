package handlers

import (
	"log"
	"net/http"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"

	"global-remit-backend/internal/app"
	"global-remit-backend/internal/domain"
	"global-remit-backend/internal/repository"
)

// ComplianceHandler handles HTTP requests for compliance-related operations.
type ComplianceHandler struct {
	repo repository.ComplianceRepository
}

// NewComplianceHandler creates a new compliance handler.
func NewComplianceHandler(app *app.Application) *ComplianceHandler {
	return &ComplianceHandler{repo: *app.ComplianceRepo}
}

type CreateKycVerificationRequest struct {
	ClientID       uuid.UUID  `json:"client_id" binding:"required"`
	DocumentType   string     `json:"document_type" binding:"required"`
	DocumentNumber string     `json:"document_number" binding:"required"`
	IssueDate      time.Time  `json:"issue_date" binding:"required"`
	ExpiryDate     *time.Time `json:"expiry_date"`
}

// CreateKycVerification handles the creation of a new KYC verification record.
func (h *ComplianceHandler) CreateKycVerification(c *gin.Context) {
	var req CreateKycVerificationRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	kyc := &domain.KycVerification{
		ClientID:           req.ClientID,
		VerificationType:   req.DocumentType,
		VerificationStatus: "pending", // Default status
		ExpirationDate:     req.ExpiryDate,
		Version:            1, // Default version
	}

	if err := h.repo.CreateKycVerification(c.Request.Context(), kyc); err != nil {
		log.Printf("Error creating KYC verification: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to create KYC verification"})
		return
	}

	c.JSON(http.StatusCreated, kyc)
}

// ListCurrencies handles listing all currencies.
func (h *ComplianceHandler) ListCurrencies(c *gin.Context) {
	// In a real app, this would fetch from the repository
	currencies := []domain.Currency{
		{Code: "USD", Name: "United States Dollar"},
		{Code: "EUR", Name: "Euro"},
	}
	c.JSON(http.StatusOK, currencies)
}

func (h *ComplianceHandler) GetKYCVerifications(c *gin.Context) {
	verifications, err := h.repo.GetKYCVerifications(c.Request.Context())
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to get kyc verifications"})
		return
	}
	c.JSON(http.StatusOK, verifications)
}
