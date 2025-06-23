package handlers

import (
	"log"
	"net/http"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"

	"global-remit-backend/internal/app"
	"global-remit-backend/internal/domain"
	"global-remit-backend/internal/repository"
)

// AccountHandler handles HTTP requests for accounts.
type AccountHandler struct {
	repo repository.AccountRepository
}

// NewAccountHandler creates a new account handler.
func NewAccountHandler(app *app.Application) *AccountHandler {
	return &AccountHandler{repo: *app.AccountRepo}
}

type CreateAccountRequest struct {
	AccountName      string    `json:"account_name" binding:"required"`
	AccountTypeID    uuid.UUID `json:"account_type_id" binding:"required"`
	CurrencyID       uuid.UUID `json:"currency_id" binding:"required"`
	Status           string    `json:"status" binding:"required"`
	CurrentBalance   float64   `json:"current_balance"`
	AvailableBalance float64   `json:"available_balance"`
	HoldBalance      float64   `json:"hold_balance"`
	CreatedBy        uuid.UUID `json:"created_by" binding:"required"`
}

// CreateAccount handles the creation of a new account.
func (h *AccountHandler) CreateAccount(c *gin.Context) {
	var req CreateAccountRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	account := &domain.Account{
		AccountNumber:    "ACC-" + uuid.New().String()[:8], // Generate a temporary account number
		AccountName:      req.AccountName,
		AccountTypeID:    req.AccountTypeID,
		CurrencyID:       req.CurrencyID,
		Status:           req.Status,
		CurrentBalance:   req.CurrentBalance,
		AvailableBalance: req.AvailableBalance,
		HoldBalance:      req.HoldBalance,
		CreatedBy:        req.CreatedBy,
	}

	if err := h.repo.CreateAccount(c.Request.Context(), account); err != nil {
		log.Printf("Error creating account: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to create account"})
		return
	}

	c.JSON(http.StatusCreated, account)
}

func (h *AccountHandler) CreateAccountType(c *gin.Context) {
	var accountType domain.AccountType
	if err := c.ShouldBindJSON(&accountType); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	if accountType.Features == nil {
		accountType.Features = []byte("{}")
	}
	if accountType.Restrictions == nil {
		accountType.Restrictions = []byte("{}")
	}

	if err := h.repo.CreateAccountType(c.Request.Context(), &accountType); err != nil {
		log.Printf("Error creating account type: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to create account type"})
		return
	}

	c.JSON(http.StatusCreated, accountType)
}

func (h *AccountHandler) CreateTransactionType(c *gin.Context) {
	var transactionType domain.TransactionType
	if err := c.ShouldBindJSON(&transactionType); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	if err := h.repo.CreateTransactionType(c.Request.Context(), &transactionType); err != nil {
		log.Printf("Error creating transaction type: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to create transaction type"})
		return
	}

	c.JSON(http.StatusCreated, transactionType)
}

// CreateTransaction handles the creation of a new transaction.
func (h *AccountHandler) CreateTransaction(c *gin.Context) {
	var req domain.Transaction
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	if err := h.repo.CreateTransaction(c.Request.Context(), &req); err != nil {
		log.Printf("Error creating transaction: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to create transaction"})
		return
	}

	c.JSON(http.StatusCreated, req)
}

func (h *AccountHandler) GetAccounts(c *gin.Context) {
	accounts, err := h.repo.GetAccounts(c.Request.Context())
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to get accounts"})
		return
	}
	c.JSON(http.StatusOK, accounts)
}
