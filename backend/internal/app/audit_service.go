package app

import (
	"context"

	"backend/internal/domain"
	"backend/internal/repository"
)

// AuditService provides a simple interface for creating audit log entries.
type AuditService struct {
	repo repository.ComplianceRepository
}

// NewAuditService creates a new audit service.
func NewAuditService(repo *repository.ComplianceRepository) *AuditService {
	return &AuditService{repo: *repo}
}

// Log logs an audit event.
func (s *AuditService) Log(ctx context.Context, log *domain.AuditLog) error {
	return s.repo.CreateAuditLog(ctx, log)
}
