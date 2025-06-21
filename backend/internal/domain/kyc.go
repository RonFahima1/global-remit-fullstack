package domain

import (
	"time"

	"github.com/google/uuid"
)

// KycVerification represents a KYC verification record for a client.
type KycVerification struct {
	ID                 uuid.UUID  `json:"id" db:"id"`
	ClientID           uuid.UUID  `json:"client_id" db:"client_id"`
	VerificationType   string     `json:"verification_type" db:"verification_type"`
	VerificationStatus string     `json:"verification_status" db:"verification_status"`
	VerifiedAt         *time.Time `json:"verified_at,omitempty" db:"verified_at"`
	VerifiedBy         *uuid.UUID `json:"verified_by,omitempty" db:"verified_by"`
	ExpirationDate     *time.Time `json:"expiration_date,omitempty" db:"expiration_date"`
	VerificationData   *string    `json:"verification_data,omitempty" db:"verification_data"`
	RejectionReason    *string    `json:"rejection_reason,omitempty" db:"rejection_reason"`
	CreatedAt          time.Time  `json:"created_at" db:"created_at"`
	UpdatedAt          time.Time  `json:"updated_at" db:"updated_at"`
	CreatedBy          *uuid.UUID `json:"created_by,omitempty" db:"created_by"`
	UpdatedBy          *uuid.UUID `json:"updated_by,omitempty" db:"updated_by"`
	Version            int        `json:"version" db:"version"`
}
