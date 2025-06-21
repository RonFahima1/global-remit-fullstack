package domain

import (
	"encoding/json"
	"time"

	"github.com/google/uuid"
)

// Transaction represents a financial transaction in the system.
type Transaction struct {
	ID                   uuid.UUID       `json:"id" db:"id"`
	TransactionReference string          `json:"transaction_reference" db:"transaction_reference"`
	TransactionTypeID    uuid.UUID       `json:"transaction_type_id" db:"transaction_type_id"`
	Status               string          `json:"status" db:"status"`
	Amount               float64         `json:"amount" db:"amount"`
	CurrencyCode         string          `json:"currency_code" db:"currency_code"`
	ExchangeRate         float64         `json:"exchange_rate" db:"exchange_rate"`
	FeeAmount            float64         `json:"fee_amount" db:"fee_amount"`
	TaxAmount            float64         `json:"tax_amount" db:"tax_amount"`
	NetAmount            float64         `json:"net_amount" db:"net_amount"`
	TransactionDate      time.Time       `json:"transaction_date" db:"transaction_date"`
	ValueDate            *time.Time      `json:"value_date" db:"value_date"`
	ParentTransactionID  *uuid.UUID      `json:"parent_transaction_id" db:"parent_transaction_id"`
	RelatedTransactionID *uuid.UUID      `json:"related_transaction_id" db:"related_transaction_id"`
	BranchID             *uuid.UUID      `json:"branch_id" db:"branch_id"`
	TellerID             *uuid.UUID      `json:"teller_id" db:"teller_id"`
	Description          *string         `json:"description" db:"description"`
	Notes                *string         `json:"notes" db:"notes"`
	Metadata             json.RawMessage `json:"metadata" db:"metadata"`
	CreatedAt            time.Time       `json:"created_at" db:"created_at"`
	UpdatedAt            time.Time       `json:"updated_at" db:"updated_at"`
	CreatedBy            uuid.UUID       `json:"created_by" db:"created_by"`
	UpdatedBy            *uuid.UUID      `json:"updated_by" db:"updated_by"`
	Version              int             `json:"version" db:"version"`
}

type TransactionType struct {
	ID                uuid.UUID  `json:"id" db:"id"`
	Code              string     `json:"code" db:"code"`
	Name              string     `json:"name" db:"name"`
	Description       *string    `json:"description" db:"description"`
	Direction         string     `json:"direction" db:"direction"`
	AffectsBalance    bool       `json:"affects_balance" db:"affects_balance"`
	RequiresApproval  bool       `json:"requires_approval" db:"requires_approval"`
	ApprovalThreshold *float64   `json:"approval_threshold" db:"approval_threshold"`
	IsActive          bool       `json:"is_active" db:"is_active"`
	CreatedAt         time.Time  `json:"created_at" db:"created_at"`
	UpdatedAt         time.Time  `json:"updated_at" db:"updated_at"`
	CreatedBy         uuid.UUID  `json:"created_by" db:"created_by"`
	UpdatedBy         *uuid.UUID `json:"updated_by" db:"updated_by"`
	Version           int        `json:"version" db:"version"`
}
