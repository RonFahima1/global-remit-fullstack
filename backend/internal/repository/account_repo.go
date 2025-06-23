package repository

import (
	"context"

	"github.com/jmoiron/sqlx"

	"global-remit-backend/internal/domain"
)

type AccountRepository struct {
	db *sqlx.DB
}

func NewAccountRepository(db *sqlx.DB) *AccountRepository {
	return &AccountRepository{db: db}
}

func (r *AccountRepository) CreateAccount(ctx context.Context, account *domain.Account) error {
	query := `
		INSERT INTO core.accounts (
			account_number, account_name, account_type_id, currency_id, status, 
			current_balance, available_balance, hold_balance, created_by
		) VALUES (
			:account_number, :account_name, :account_type_id, :currency_id, :status,
			:current_balance, :available_balance, :hold_balance, :created_by
		) RETURNING id, open_date, created_at, updated_at, version
	`
	rows, err := r.db.NamedQueryContext(ctx, query, account)
	if err != nil {
		return err
	}
	defer rows.Close()

	if rows.Next() {
		err = rows.StructScan(account)
		if err != nil {
			return err
		}
	}
	return nil
}

func (r *AccountRepository) GetAccounts(ctx context.Context) ([]domain.Account, error) {
	var accounts []domain.Account
	err := r.db.SelectContext(ctx, &accounts, "SELECT * FROM core.accounts")
	return accounts, err
}

func (r *AccountRepository) CreateAccountType(ctx context.Context, accountType *domain.AccountType) error {
	query := `
		INSERT INTO core.account_types (
			type_code, name, description, features, restrictions, is_active, created_by
		) VALUES (
			:type_code, :name, :description, :features, :restrictions, :is_active, :created_by
		) RETURNING id, created_at, updated_at, version
	`
	rows, err := r.db.NamedQueryContext(ctx, query, accountType)
	if err != nil {
		return err
	}
	defer rows.Close()

	if rows.Next() {
		err = rows.StructScan(accountType)
		if err != nil {
			return err
		}
	}
	return nil
}

func (r *AccountRepository) CreateTransaction(ctx context.Context, transaction *domain.Transaction) error {
	query := `
		INSERT INTO core.transactions (
			transaction_reference, transaction_type_id, status, amount, currency_code, 
			net_amount, created_by
		) VALUES (
			:transaction_reference, :transaction_type_id, :status, :amount, :currency_code,
			:net_amount, :created_by
		) RETURNING id, transaction_date, created_at, updated_at, version
	`
	rows, err := r.db.NamedQueryContext(ctx, query, transaction)
	if err != nil {
		return err
	}
	defer rows.Close()

	if rows.Next() {
		err = rows.StructScan(transaction)
		if err != nil {
			return err
		}
	}
	return nil
}

func (r *AccountRepository) CreateTransactionType(ctx context.Context, transactionType *domain.TransactionType) error {
	query := `
		INSERT INTO core.transaction_types (
			code, name, description, direction, affects_balance, requires_approval, 
			approval_threshold, is_active, created_by
		) VALUES (
			:code, :name, :description, :direction, :affects_balance, :requires_approval,
			:approval_threshold, :is_active, :created_by
		) RETURNING id, created_at, updated_at, version
	`
	rows, err := r.db.NamedQueryContext(ctx, query, transactionType)
	if err != nil {
		return err
	}
	defer rows.Close()

	if rows.Next() {
		err = rows.StructScan(transactionType)
		if err != nil {
			return err
		}
	}
	return nil
}
