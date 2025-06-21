package domain

import (
	"time"
)

// Currency represents a currency in the system.
type Currency struct {
	Code           string    `json:"code"`
	Name           string    `json:"name"`
	Symbol         string    `json:"symbol"`
	DecimalPlaces  int       `json:"decimal_places"`
	IsActive       bool      `json:"is_active"`
	IsBaseCurrency bool      `json:"is_base_currency"`
	CreatedAt      time.Time `json:"created_at"`
	UpdatedAt      time.Time `json:"updated_at"`
}
