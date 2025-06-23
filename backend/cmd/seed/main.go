package main

import (
	"context"
	"database/sql"
	"flag"
	"fmt"
	"log"
	"math/rand"
	"os"
	"time"

	cryptorand "crypto/rand"
	"encoding/hex"

	"global-remit-backend/internal/cache"

	faker "github.com/go-faker/faker/v4"
	_ "github.com/lib/pq"
	"golang.org/x/crypto/bcrypt"
)

type TestUser struct {
	FirstName string
	LastName  string
	Email     string
	Password  string
	Role      string
	Status    string
}

func main() {
	numClients := flag.Int("clients", 100, "Number of clients to generate")
	dbPort := os.Getenv("DB_PORT") // Never change port number here. Use canonical port from env/config.
	dbURL := flag.String("db", fmt.Sprintf("postgres://postgres:yourpassword@localhost:%s/global_remit?sslmode=disable", dbPort), "Database connection string")
	flag.Parse()

	db, err := sql.Open("postgres", *dbURL)
	if err != nil {
		log.Fatalf("Failed to connect to database: %v", err)
	}
	defer db.Close()

	rand.Seed(time.Now().UnixNano())

	seedTestUsers(db)
	seedCurrencies(db)
	accountTypeIDs := seedAccountTypes(db)
	transactionTypeIDs := seedTransactionTypes(db)

	clientIDs := make([]string, 0, *numClients)
	accountIDs := make([]string, 0, *numClients*2)
	for i := 0; i < *numClients; i++ {
		clientID := insertFakeClient(db)
		clientIDs = append(clientIDs, clientID)
		// Each client gets 1-3 accounts
		numAccounts := rand.Intn(3) + 1
		for j := 0; j < numAccounts; j++ {
			accountID := insertFakeAccount(db, clientID, accountTypeIDs)
			accountIDs = append(accountIDs, accountID)
		}
	}

	// For each account, create 5-10 transactions
	for _, accountID := range accountIDs {
		numTx := rand.Intn(6) + 5
		for k := 0; k < numTx; k++ {
			// Pick random sender/receiver (other accounts)
			receiverID := accountIDs[rand.Intn(len(accountIDs))]
			for receiverID == accountID && len(accountIDs) > 1 {
				receiverID = accountIDs[rand.Intn(len(accountIDs))]
			}
			insertFakeTransaction(db, accountID, receiverID, transactionTypeIDs)
		}
	}

	fmt.Printf("Seeded %d clients, %d accounts, and ~%d transactions.\n", len(clientIDs), len(accountIDs), len(accountIDs)*7)
	fmt.Println("Testing Redis...")
	ctx := context.Background()
	err = cache.Set(ctx, "test:ping", "pong", 10*time.Second)
	if err != nil {
		fmt.Println("Redis SET error:", err)
	} else {
		val, err := cache.Get(ctx, "test:ping")
		if err != nil {
			fmt.Println("Redis GET error:", err)
		} else {
			fmt.Println("Redis GET test:ping =", val)
		}
	}
	_ = cache.Close()
}

func seedTestUsers(db *sql.DB) {
	testUsers := []TestUser{
		{
			FirstName: "Test",
			LastName:  "User",
			Email:     "testuser@example.com",
			Password:  "Password123",
			Role:      "ORG_ADMIN",
			Status:    "ACTIVE",
		},
		{
			FirstName: "Agent",
			LastName:  "Admin",
			Email:     "agentadmin@example.com",
			Password:  "Password123",
			Role:      "AGENT_ADMIN",
			Status:    "ACTIVE",
		},
		{
			FirstName: "Agent",
			LastName:  "User",
			Email:     "agentuser@example.com",
			Password:  "Password123",
			Role:      "AGENT_USER",
			Status:    "ACTIVE",
		},
		{
			FirstName: "Compliance",
			LastName:  "User",
			Email:     "complianceuser@example.com",
			Password:  "Password123",
			Role:      "COMPLIANCE_USER",
			Status:    "ACTIVE",
		},
		{
			FirstName: "Org",
			LastName:  "User",
			Email:     "orguser@example.com",
			Password:  "Password123",
			Role:      "ORG_USER",
			Status:    "ACTIVE",
		},
		{
			FirstName: "Demo",
			LastName:  "User",
			Email:     "demo@example.com",
			Password:  "demo",
			Role:      "ORG_USER",
			Status:    "ACTIVE",
		},
	}

	for _, u := range testUsers {
		// Ensure role exists in auth.roles
		var roleID string
		err := db.QueryRow("INSERT INTO auth.roles (name) VALUES ($1) ON CONFLICT (name) DO UPDATE SET name=EXCLUDED.name RETURNING id", u.Role).Scan(&roleID)
		if err != nil {
			log.Fatalf("failed to insert or get role %s: %v", u.Role, err)
		}

		passwordHash, err := bcrypt.GenerateFromPassword([]byte(u.Password), bcrypt.DefaultCost)
		if err != nil {
			log.Fatalf("failed to hash password for %s: %v", u.Email, err)
		}

		// Insert user
		var userID string
		err = db.QueryRow(`
			INSERT INTO auth.users (id, username, email, email_verified, password_hash, status, first_name, last_name, phone, phone_verified, created_at, updated_at, version) 
			VALUES (gen_random_uuid(), $1, $2, true, $3, $4, $5, $6, '', false, NOW(), NOW(), 1) 
			ON CONFLICT (email) DO UPDATE SET 
				password_hash = EXCLUDED.password_hash,
				status = EXCLUDED.status,
				first_name = EXCLUDED.first_name,
				last_name = EXCLUDED.last_name
			RETURNING id`,
			u.Email, u.Email, string(passwordHash), u.Status, u.FirstName, u.LastName).Scan(&userID)
		if err != nil {
			log.Fatalf("failed to insert user %s: %v", u.Email, err)
		}

		// Assign role to user
		_, err = db.Exec(`
			INSERT INTO auth.user_roles (user_id, role_id) VALUES ($1, $2)
			ON CONFLICT (user_id, role_id) DO NOTHING`, userID, roleID)
		if err != nil {
			log.Fatalf("failed to assign role %s to user %s: %v", u.Role, u.Email, err)
		}
		log.Printf("Seeded user: %s (%s)", u.Email, u.Role)
	}
}

func seedCurrencies(db *sql.DB) {
	// Minimal set for demo; extend as needed
	currencies := []struct {
		Code, Name, Symbol string
	}{
		{"USD", "US Dollar", "$"},
		{"EUR", "Euro", "€"},
		{"GBP", "Pound Sterling", "£"},
		{"JPY", "Yen", "¥"},
		{"CAD", "Canadian Dollar", "$"},
	}
	for _, c := range currencies {
		_, _ = db.Exec(`INSERT INTO config.currencies (code, name, symbol) VALUES ($1, $2, $3) ON CONFLICT (code) DO NOTHING`, c.Code, c.Name, c.Symbol)
	}
}

func seedAccountTypes(db *sql.DB) []string {
	types := []struct {
		Code, Name, Desc string
	}{
		{"CHECKING", "Checking Account", "Standard checking account"},
		{"SAVINGS", "Savings Account", "Standard savings account"},
		{"BUSINESS", "Business Account", "Business checking account"},
		{"JOINT", "Joint Account", "Jointly held account"},
	}
	ids := make([]string, 0, len(types))
	for _, t := range types {
		var id string
		err := db.QueryRow(`
			INSERT INTO core.account_types (id, type_code, name, description, created_at, updated_at, version)
			VALUES (gen_random_uuid(), $1, $2, $3, NOW(), NOW(), 1)
			ON CONFLICT (type_code) DO UPDATE SET name=EXCLUDED.name RETURNING id
		`, t.Code, t.Name, t.Desc).Scan(&id)
		if err != nil || id == "" {
			db.QueryRow(`SELECT id FROM core.account_types WHERE type_code=$1`, t.Code).Scan(&id)
		}
		ids = append(ids, id)
	}
	return ids
}

func seedTransactionTypes(db *sql.DB) []string {
	types := []struct {
		Code, Name, Desc, Direction string
	}{
		{"TRANSFER", "Transfer", "Account transfer", "debit"},
		{"PAYMENT", "Payment", "Bill payment", "debit"},
		{"DEPOSIT", "Deposit", "Deposit to account", "credit"},
		{"WITHDRAWAL", "Withdrawal", "Withdraw from account", "debit"},
	}
	ids := make([]string, 0, len(types))
	for _, t := range types {
		var id string
		err := db.QueryRow(`
			INSERT INTO core.transaction_types (id, code, name, description, direction, created_at, updated_at, version)
			VALUES (gen_random_uuid(), $1, $2, $3, $4, NOW(), NOW(), 1)
			ON CONFLICT (code) DO UPDATE SET name=EXCLUDED.name RETURNING id
		`, t.Code, t.Name, t.Desc, t.Direction).Scan(&id)
		if err != nil || id == "" {
			db.QueryRow(`SELECT id FROM core.transaction_types WHERE code=$1`, t.Code).Scan(&id)
		}
		ids = append(ids, id)
	}
	return ids
}

func insertFakeClient(db *sql.DB) string {
	clientTypes := []string{"INDIVIDUAL", "BUSINESS", "ORGANIZATION"}
	statuses := []string{"PENDING", "ACTIVE", "SUSPENDED", "CLOSED"}
	kycStatuses := []string{"NOT_VERIFIED", "PENDING", "VERIFIED", "REJECTED", "EXPIRED"}
	riskLevels := []string{"LOW", "MEDIUM", "HIGH"}
	var id string
	clientNumber := randomString(12) // max 20 chars
	phone := generatePhoneNumber()
	firstName := truncate(faker.FirstName(), 100)
	lastName := truncate(faker.LastName(), 100)
	email := truncate(faker.Email(), 255)
	emailVerified := rand.Intn(2) == 1
	phoneVerified := rand.Intn(2) == 1
	kycStatus := kycStatuses[rand.Intn(len(kycStatuses))]
	riskLevel := riskLevels[rand.Intn(len(riskLevels))]
	clientType := clientTypes[rand.Intn(len(clientTypes))]
	status := statuses[rand.Intn(len(statuses))]
	log.Println("Inserting client:", clientNumber, clientType, status, firstName, lastName, email, emailVerified, phone, phoneVerified, kycStatus, riskLevel)
	// Try with phone as NULL
	var phonePtr *string = nil // always NULL for now
	err := db.QueryRow(`
		INSERT INTO core.clients (
			id, client_number, client_type, status, first_name, last_name, email, email_verified, phone, phone_verified, kyc_status, risk_level, created_at, updated_at, version
		) VALUES (
			gen_random_uuid(), $1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, NOW(), NOW(), 1
		) RETURNING id
	`,
		clientNumber,
		clientType,
		status,
		firstName,
		lastName,
		email,
		emailVerified,
		phonePtr, // always NULL
		phoneVerified,
		kycStatus,
		riskLevel,
	).Scan(&id)
	if err != nil {
		log.Fatalf("Failed to insert client: %v", err)
	}
	return id
}

func generatePhoneNumber() string {
	return "+1234567890"
}

func randomString(n int) string {
	b := make([]byte, n)
	_, err := cryptorand.Read(b)
	if err != nil {
		return fmt.Sprintf("%d", time.Now().UnixNano())[:n]
	}
	return hex.EncodeToString(b)[:n]
}

func truncate(s string, max int) string {
	if len(s) > max {
		return s[:max]
	}
	return s
}

func insertFakeAccount(db *sql.DB, clientID string, accountTypeIDs []string) string {
	currencyCodes := []string{"USD", "EUR", "GBP", "JPY", "CAD"}
	accountTypeID := accountTypeIDs[rand.Intn(len(accountTypeIDs))]
	currencyCode := currencyCodes[rand.Intn(len(currencyCodes))]
	accountNumber := faker.UUIDHyphenated()[:20]
	accountName := faker.Word() + " Account"
	currentBalance := float64(rand.Intn(10000)) + rand.Float64()
	availableBalance := currentBalance * rand.Float64() // always <= currentBalance
	holdBalance := float64(rand.Intn(1000))
	if holdBalance > currentBalance {
		holdBalance = currentBalance * rand.Float64()
	}
	status := "ACTIVE"
	openDate := time.Now().AddDate(0, 0, -rand.Intn(365))
	log.Println("Inserting account:", accountNumber, accountName, accountTypeID, currencyCode, currentBalance, availableBalance, holdBalance, status, openDate)
	var id string
	err := db.QueryRow(`
		INSERT INTO core.accounts (
			id, account_number, account_name, account_type_id, currency_code, current_balance, available_balance, hold_balance, status, open_date, created_at, updated_at, version
		) VALUES (
			gen_random_uuid(), $1, $2, $3, $4, $5, $6, $7, $8, $9, NOW(), NOW(), 1
		) RETURNING id
	`,
		accountNumber,
		accountName,
		accountTypeID,
		currencyCode,
		currentBalance,
		availableBalance,
		holdBalance,
		status,
		openDate,
	).Scan(&id)
	if err != nil {
		log.Fatalf("Failed to insert account: %v", err)
	}
	// Link to client in account_holders
	_, _ = db.Exec(`INSERT INTO core.account_holders (id, account_id, client_id, holder_type, created_at, updated_at, version) VALUES (gen_random_uuid(), $1, $2, 'PRIMARY', NOW(), NOW(), 1) ON CONFLICT DO NOTHING`, id, clientID)
	return id
}

func insertFakeTransaction(db *sql.DB, senderAccountID, receiverAccountID string, transactionTypeIDs []string) {
	statuses := []string{"pending", "completed", "failed", "reversed"}
	amount := float64(rand.Intn(1000)) + rand.Float64()*100
	transactionTypeID := transactionTypeIDs[rand.Intn(len(transactionTypeIDs))]
	_, err := db.Exec(`
		INSERT INTO core.transactions (
			id, transaction_reference, transaction_type_id, status, amount, currency_code, net_amount, transaction_date, created_at, updated_at, version
		) VALUES (
			gen_random_uuid(), $1, $2, $3, $4, $5, $6, $7, NOW(), NOW(), 1
		)
	`,
		faker.UUIDHyphenated()[:20],
		transactionTypeID,
		statuses[rand.Intn(len(statuses))],
		amount,
		"USD",
		amount-float64(rand.Intn(10)),
		time.Now().Add(-time.Duration(rand.Intn(1000))*time.Hour),
	)
	if err != nil {
		log.Printf("Failed to insert transaction: %v", err)
	}
}
