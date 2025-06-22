package domain

import (
	"time"

	"github.com/google/uuid"
)

// Client represents a client in the system.
type Client struct {
	ID                    uuid.UUID  `json:"id" db:"id"`
	ClientNumber          string     `json:"client_number" db:"client_number"`
	ClientType            string     `json:"client_type" db:"client_type"`
	Status                string     `json:"status" db:"status"`
	Title                 *string    `json:"title" db:"title"`
	FirstName             string     `json:"first_name" db:"first_name"`
	MiddleName            *string    `json:"middle_name" db:"middle_name"`
	LastName              string     `json:"last_name" db:"last_name"`
	DateOfBirth           *time.Time `json:"date_of_birth" db:"date_of_birth"`
	Gender                *string    `json:"gender" db:"gender"`
	MaritalStatus         *string    `json:"marital_status" db:"marital_status"`
	Email                 *string    `json:"email" db:"email"`
	EmailVerified         bool       `json:"email_verified" db:"email_verified"`
	Phone                 *string    `json:"phone" db:"phone"`
	PhoneVerified         bool       `json:"phone_verified" db:"phone_verified"`
	Occupation            *string    `json:"occupation" db:"occupation"`
	EmployerName          *string    `json:"employer_name" db:"employer_name"`
	EmploymentStatus      *string    `json:"employment_status" db:"employment_status"`
	AnnualIncome          *float64   `json:"annual_income" db:"annual_income"`
	KycStatus             string     `json:"kyc_status" db:"kyc_status"`
	KycVerifiedAt         *time.Time `json:"kyc_verified_at" db:"kyc_verified_at"`
	KycVerifiedBy         *uuid.UUID `json:"kyc_verified_by" db:"kyc_verified_by"`
	RiskLevel             string     `json:"risk_level" db:"risk_level"`
	RelationshipManagerID *uuid.UUID `json:"relationship_manager_id" db:"relationship_manager_id"`
	ReferralSource        *string    `json:"referral_source" db:"referral_source"`
	CreatedAt             time.Time  `json:"created_at" db:"created_at"`
	UpdatedAt             time.Time  `json:"updated_at" db:"updated_at"`
	DeletedAt             *time.Time `json:"deleted_at" db:"deleted_at"`
	CreatedBy             *uuid.UUID `json:"created_by" db:"created_by"`
	UpdatedBy             *uuid.UUID `json:"updated_by" db:"updated_by"`
	Version               int        `json:"version" db:"version"`
	BranchID              *uuid.UUID `json:"branch_id" db:"branch_id"`
}
