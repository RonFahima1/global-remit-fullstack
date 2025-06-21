package app

import (
	"log/slog"

	"github.com/jmoiron/sqlx"

	"backend/internal/repository"
)

// Application holds all the application's services.
type Application struct {
	DB             *sqlx.DB
	Logger         *slog.Logger
	AuditService   *AuditService
	ClientRepo     *repository.ClientRepository
	AccountRepo    *repository.AccountRepository
	ComplianceRepo *repository.ComplianceRepository
	AuthRepo       *repository.AuthRepository
}

// NewApplication creates a new Application.
func New(
	db *sqlx.DB,
	logger *slog.Logger,
) *Application {
	clientRepo := repository.NewClientRepository(db)
	accountRepo := repository.NewAccountRepository(db)
	complianceRepo := repository.NewComplianceRepository(db)
	authRepo := repository.NewAuthRepository(db)

	auditService := NewAuditService(complianceRepo)

	return &Application{
		DB:             db,
		Logger:         logger,
		AuditService:   auditService,
		ClientRepo:     clientRepo,
		AccountRepo:    accountRepo,
		ComplianceRepo: complianceRepo,
		AuthRepo:       authRepo,
	}
}
