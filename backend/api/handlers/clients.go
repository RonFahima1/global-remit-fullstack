package handlers

import (
	"encoding/json"
	"log"
	"net/http"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"

	"global-remit-backend/internal/app"
	"global-remit-backend/internal/domain"
	"global-remit-backend/internal/repository"
)

// ClientHandler handles HTTP requests for clients.
type ClientHandler struct {
	app  *app.Application
	repo repository.ClientRepository
}

// NewClientHandler creates a new client handler.
func NewClientHandler(app *app.Application) *ClientHandler {
	return &ClientHandler{
		app:  app,
		repo: *app.ClientRepo,
	}
}

type CreateClientRequest struct {
	ClientType       string     `json:"client_type" binding:"required"`
	Status           string     `json:"status" binding:"required"`
	Title            *string    `json:"title"`
	FirstName        string     `json:"first_name" binding:"required"`
	MiddleName       *string    `json:"middle_name"`
	LastName         string     `json:"last_name" binding:"required"`
	DateOfBirth      *time.Time `json:"date_of_birth"`
	Gender           *string    `json:"gender"`
	MaritalStatus    *string    `json:"marital_status"`
	Email            string     `json:"email"`
	Phone            *string    `json:"phone"`
	Occupation       *string    `json:"occupation"`
	EmployerName     *string    `json:"employer_name"`
	EmploymentStatus *string    `json:"employment_status"`
	AnnualIncome     *float64   `json:"annual_income"`
	KycStatus        string     `json:"kyc_status" binding:"required"`
}

// CreateClient godoc
// @Summary Create a new client
// @Description Create a new client with the input payload
// @Tags clients
// @Accept  json
// @Produce  json
// @Param client body domain.Client true "Client"
// @Success 201 {object} domain.Client
// @Router /clients [post]
func (h *ClientHandler) CreateClient(c *gin.Context) {
	var req CreateClientRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	var email *string
	if req.Email != "" {
		email = &req.Email
	}

	client := &domain.Client{
		ClientNumber:     "CLI-" + uuid.New().String()[:8], // Generate a shorter temporary client number
		ClientType:       req.ClientType,
		Status:           req.Status,
		Title:            req.Title,
		FirstName:        req.FirstName,
		MiddleName:       req.MiddleName,
		LastName:         req.LastName,
		DateOfBirth:      req.DateOfBirth,
		Gender:           req.Gender,
		MaritalStatus:    req.MaritalStatus,
		Email:            email,
		Phone:            req.Phone,
		Occupation:       req.Occupation,
		EmployerName:     req.EmployerName,
		EmploymentStatus: req.EmploymentStatus,
		AnnualIncome:     req.AnnualIncome,
		KycStatus:        req.KycStatus,
	}

	if err := h.repo.CreateClient(c.Request.Context(), client); err != nil {
		log.Printf("Error creating client: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to create client"})
		return
	}

	// Audit the creation of a new client
	newValues, _ := json.Marshal(client)
	idStr := client.ID.String()
	auditLog := &domain.AuditLog{
		EventType: "client_created",
		TableName: strToPtr("clients"),
		RecordID:  &idStr,
		Action:    "INSERT",
		NewValues: newValues,
		UserIP:    strToPtr(c.ClientIP()),
	}
	h.app.AuditService.Log(c.Request.Context(), auditLog)

	c.JSON(http.StatusCreated, client)
}

func (h *ClientHandler) GetClients(c *gin.Context) {
	clients, err := h.repo.GetClients(c.Request.Context())
	if err != nil {
		log.Printf("GetClients error: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to get clients", "detail": err.Error()})
		return
	}
	c.JSON(http.StatusOK, clients)
}

func strToPtr(s string) *string {
	return &s
}
