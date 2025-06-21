package domain

import (
	"encoding/json"
	"time"

	"github.com/google/uuid"
)

// Account represents a financial account in the system.
type Account struct {
	ID               uuid.UUID       `json:"id" db:"id"`
	AccountNumber    string          `json:"account_number" db:"account_number"`
	AccountName      string          `json:"account_name" db:"account_name"`
	AccountTypeID    uuid.UUID       `json:"account_type_id" db:"account_type_id"`
	CurrencyID       uuid.UUID       `json:"currency_id" db:"currency_id"`
	CurrentBalance   float64         `json:"current_balance" db:"current_balance"`
	AvailableBalance float64         `json:"available_balance" db:"available_balance"`
	HoldBalance      float64         `json:"hold_balance" db:"hold_balance"`
	Status           string          `json:"status" db:"status"`
	OpenDate         time.Time       `json:"open_date" db:"open_date"`
	LastActivityDate *time.Time      `json:"last_activity_date" db:"last_activity_date"`
	CloseDate        *time.Time      `json:"close_date" db:"close_date"`
	Metadata         json.RawMessage `json:"metadata" db:"metadata"`
	CreatedAt        time.Time       `json:"created_at" db:"created_at"`
	UpdatedAt        time.Time       `json:"updated_at" db:"updated_at"`
	CreatedBy        uuid.UUID       `json:"created_by" db:"created_by"`
	UpdatedBy        *uuid.UUID      `json:"updated_by" db:"updated_by"`
	Version          int             `json:"version" db:"version"`
}

type AccountType struct {
	ID           uuid.UUID       `json:"id" db:"id"`
	TypeCode     string          `json:"type_code" db:"type_code"`
	Name         string          `json:"name" db:"name"`
	Description  *string         `json:"description" db:"description"`
	Features     json.RawMessage `json:"features" db:"features"`
	Restrictions json.RawMessage `json:"restrictions" db:"restrictions"`
	IsActive     bool            `json:"is_active" db:"is_active"`
	CreatedAt    time.Time       `json:"created_at" db:"created_at"`
	UpdatedAt    time.Time       `json:"updated_at" db:"updated_at"`
	CreatedBy    uuid.UUID       `json:"created_by" db:"created_by"`
	UpdatedBy    *uuid.UUID      `json:"updated_by" db:"updated_by"`
	Version      int             `json:"version" db:"version"`
}

type AccountHolder struct {
	ID          uuid.UUID       `json:"id" db:"id"`
	AccountID   uuid.UUID       `json:"account_id" db:"account_id"`
	ClientID    uuid.UUID       `json:"client_id" db:"client_id"`
	HolderType  string          `json:"holder_type" db:"holder_type"`
	AddedDate   time.Time       `json:"added_date" db:"added_date"`
	RemovedDate *time.Time      `json:"removed_date" db:"removed_date"`
	Permissions json.RawMessage `json:"permissions" db:"permissions"`
	CreatedAt   time.Time       `json:"created_at" db:"created_at"`
	UpdatedAt   time.Time       `json:"updated_at" db:"updated_at"`
	CreatedBy   uuid.UUID       `json:"created_by" db:"created_by"`
	UpdatedBy   *uuid.UUID      `json:"updated_by" db:"updated_by"`
	Version     int             `json:"version" db:"version"`
}

type AccountBalance struct {
	ID               uuid.UUID  `json:"id" db:"id"`
	AccountID        uuid.UUID  `json:"account_id" db:"account_id"`
	BalanceDate      time.Time  `json:"balance_date" db:"balance_date"`
	OpeningBalance   float64    `json:"opening_balance" db:"opening_balance"`
	ClosingBalance   float64    `json:"closing_balance" db:"closing_balance"`
	TotalCredits     float64    `json:"total_credits" db:"total_credits"`
	TotalDebits      float64    `json:"total_debits" db:"total_debits"`
	TransactionCount int        `json:"transaction_count" db:"transaction_count"`
	CreatedAt        time.Time  `json:"created_at" db:"created_at"`
	UpdatedAt        time.Time  `json:"updated_at" db:"updated_at"`
	CreatedBy        uuid.UUID  `json:"created_by" db:"created_by"`
	UpdatedBy        *uuid.UUID `json:"updated_by" db:"updated_by"`
	Version          int        `json:"version" db:"version"`
}
