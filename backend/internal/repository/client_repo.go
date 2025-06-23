package repository

import (
	"context"

	"github.com/jmoiron/sqlx"

	"global-remit-backend/internal/domain"
)

// ClientRepository defines the interface for client data operations.
type ClientRepository struct {
	db *sqlx.DB
}

// NewClientRepository creates a new client repository.
func NewClientRepository(db *sqlx.DB) *ClientRepository {
	return &ClientRepository{db: db}
}

// CreateClient inserts a new client into the database.
func (r *ClientRepository) CreateClient(ctx context.Context, client *domain.Client) error {
	query := `
		INSERT INTO core.clients (
			client_number, client_type, status, title, first_name, middle_name, last_name, 
			date_of_birth, gender, marital_status, email, phone, occupation, employer_name, 
			employment_status, annual_income, kyc_status
		) VALUES (
			:client_number, :client_type, :status, :title, :first_name, :middle_name, :last_name,
			:date_of_birth, :gender, :marital_status, :email, :phone, :occupation, :employer_name,
			:employment_status, :annual_income, :kyc_status
		) RETURNING id, created_at, updated_at, version
	`
	rows, err := r.db.NamedQueryContext(ctx, query, client)
	if err != nil {
		return err
	}
	defer rows.Close()

	if rows.Next() {
		err = rows.StructScan(client)
		if err != nil {
			return err
		}
	}
	return nil
}

func (r *ClientRepository) GetClients(ctx context.Context) ([]domain.Client, error) {
	var clients []domain.Client
	err := r.db.SelectContext(ctx, &clients, "SELECT * FROM core.clients")
	return clients, err
}
