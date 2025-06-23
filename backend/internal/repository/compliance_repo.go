package repository

import (
	"context"

	"github.com/jmoiron/sqlx"

	"global-remit-backend/internal/domain"
)

type ComplianceRepository struct {
	db *sqlx.DB
}

func NewComplianceRepository(db *sqlx.DB) *ComplianceRepository {
	return &ComplianceRepository{db: db}
}

func (r *ComplianceRepository) CreateKycVerification(ctx context.Context, kyc *domain.KycVerification) error {
	query := `
		INSERT INTO compliance.kyc_verifications (
			client_id, verification_type, verification_status, created_by
		) VALUES (
			:client_id, :verification_type, :verification_status, :created_by
		) RETURNING id, created_at, updated_at, version
	`
	rows, err := r.db.NamedQueryContext(ctx, query, kyc)
	if err != nil {
		return err
	}
	defer rows.Close()

	if rows.Next() {
		err = rows.StructScan(kyc)
		if err != nil {
			return err
		}
	}
	return nil
}

func (r *ComplianceRepository) GetKYCVerifications(ctx context.Context) ([]domain.KycVerification, error) {
	var kycs []domain.KycVerification
	err := r.db.SelectContext(ctx, &kycs, "SELECT * FROM compliance.kyc_verifications")
	return kycs, err
}

func (r *ComplianceRepository) ListCurrencies(ctx context.Context) ([]domain.Currency, error) {
	var currencies []domain.Currency
	err := r.db.SelectContext(ctx, &currencies, "SELECT * FROM currencies")
	return currencies, err
}

func (r *ComplianceRepository) CreateAuditLog(ctx context.Context, log *domain.AuditLog) error {
	query := `
		INSERT INTO audit_logs (event_type, table_name, record_id, user_id, user_ip, action, old_values, new_values)
		VALUES (:event_type, :table_name, :record_id, :user_id, :user_ip, :action, :old_values, :new_values)
	`
	_, err := r.db.NamedExecContext(ctx, query, log)
	return err
}
