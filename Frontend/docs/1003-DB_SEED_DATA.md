# Database Seed Data Strategy

## 1. Overview

This document outlines the strategy for managing seed data in the Global Remit Teller application. Seed data is essential for development, testing, and providing initial data for new environments.

## 2. Seed Data Categories

### 2.1 Reference Data
- System roles and permissions
- Configuration settings
- Lookup tables
- Default templates

### 2.2 Test Data
- Test users and credentials
- Sample clients and accounts
- Test transactions
- Mock KYC data

### 2.3 Environment-Specific Data
- Development-specific configurations
- Staging environment data
- Demo data for presentations

## 3. Seed Data Management

### 3.1 Tools
- **Go-based seeders**: For complex data relationships
- **SQL files**: For simple static data
- **CSV imports**: For large datasets

### 3.2 Directory Structure
```
db/
├── seeds/
│   ├── common/
│   │   ├── 001_roles_permissions.sql
│   │   └── 002_system_settings.sql
│   ├── development/
│   │   ├── 001_test_users.sql
│   │   └── 002_sample_clients.sql
│   └── test/
│       └── 001_test_data.sql
└── README.md
```

## 4. Seed Data Examples

### 4.1 Roles and Permissions
```sql
-- seeds/common/001_roles_permissions.sql
INSERT INTO roles (name, description) VALUES 
('admin', 'Administrator with full system access'),
('teller', 'Teller with transaction capabilities'),
('manager', 'Branch manager with approval rights'),
('viewer', 'Read-only access')
ON CONFLICT (name) DO NOTHING;

-- Admin permissions
INSERT INTO permissions (name, description) VALUES 
('users:read', 'View users'),
('users:write', 'Create/update users'),
('transactions:process', 'Process transactions'),
('reports:view', 'View reports')
ON CONFLICT (name) DO NOTHING;

-- Assign permissions to roles
INSERT INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id 
FROM roles r
CROSS JOIN permissions p
WHERE r.name = 'admin'
ON CONFLICT DO NOTHING;
```

### 4.2 Test Users
```sql
-- seeds/development/001_test_users.sql
-- Admin user
INSERT INTO users (email, password_hash, first_name, last_name, status, role_id)
SELECT 
    'admin@example.com',
    -- bcrypt hash for 'admin123'
    '$2a$10$XFDq3wYyl/4XxX3XqXqXveXxXxXxXxXxXxXxXxXxXxXxXxXxXxXx',
    'Admin',
    'User',
    'active',
    (SELECT id FROM roles WHERE name = 'admin')
ON CONFLICT (email) DO NOTHING;

-- Teller user
INSERT INTO users (email, password_hash, first_name, last_name, status, role_id)
SELECT 
    'teller@example.com',
    -- bcrypt hash for 'teller123'
    '$2a$10$YFDq3wYyl/4XxX3XqXqXveXxXxXxXxXxXxXxXxXxXxXxXxXxXxXx',
    'John',
    'Doe',
    'active',
    (SELECT id FROM roles WHERE name = 'teller')
ON CONFLICT (email) DO NOTHING;
```

### 4.3 Sample Clients
```sql
-- seeds/development/002_sample_clients.sql
-- Sample client 1
WITH new_client AS (
    INSERT INTO clients (
        first_name, 
        last_name, 
        email, 
        phone, 
        date_of_birth, 
        kyc_status, 
        created_by
    ) VALUES (
        'Alice', 
        'Johnson', 
        'alice.johnson@example.com', 
        '+1234567890',
        '1985-05-15',
        'verified',
        (SELECT id FROM users WHERE email = 'admin@example.com')
    )
    RETURNING id
),
client_address AS (
    INSERT INTO addresses (
        client_id, 
        address_line1, 
        city, 
        state, 
        postal_code, 
        country,
        is_primary
    )
    SELECT 
        id, 
        '123 Main St', 
        'New York', 
        'NY', 
        '10001', 
        'USA',
        true
    FROM new_client
)
-- Create account for the client
INSERT INTO accounts (
    client_id,
    account_number,
    account_type,
    currency,
    balance,
    status,
    created_by
)
SELECT 
    id,
    'ACC' || LPAD(nextval('account_number_seq')::text, 8, '0'),
    'checking',
    'USD',
    10000.00,
    'active',
    (SELECT id FROM users WHERE email = 'admin@example.com')
FROM new_client;
```

## 5. Seed Data Management

### 5.1 Environment-Specific Seeds
- **Development**: Full dataset with test users and sample data
- **Test**: Minimal dataset for automated testing
- **Staging**: Similar to production but with obfuscated data
- **Production**: Only essential reference data

### 5.2 Data Privacy
- Never include real user data
- Use realistic but fake data
- Obfuscate sensitive information
- Comply with data protection regulations

## 6. Running Seeders

### 6.1 Development Setup
```bash
# Run all seeders
go run cmd/seed/main.go --env=development

# Run specific seeder
go run cmd/seed/main.go --env=development --file=sample_clients
```

### 6.2 Test Environment
```bash
# Run test seeders
go test ./internal/seed -v
```

## 7. Seed Data Maintenance

### 7.1 Version Control
- Store seed scripts in version control
- Include documentation
- Review seed scripts in PRs

### 7.2 Updates
- Add new seed data as needed
- Update existing data through migrations
- Document changes

## 8. Testing Seed Data

### 8.1 Unit Tests
- Test data validity
- Verify relationships
- Check constraints

### 8.2 Integration Tests
- Test database constraints
- Verify data consistency
- Test rollback scenarios

## 9. Example: Complete Seeder

```go
// internal/seed/users.go
package seed

import (
	"database/sql"
	"fmt"
	"log"

	"github.com/your-org/global-remit/internal/models"
	"golang.org/x/crypto/bcrypt"
)

type UserSeeder struct {
	db *sql.DB
}

func NewUserSeeder(db *sql.DB) *UserSeeder {
	return &UserSeeder{db: db}
}

func (s *UserSeeder) Seed() error {
	users := []models.User{
		{
			Email:      "admin@example.com",
			FirstName:  "Admin",
			LastName:   "User",
			Status:     "active",
			Role:       "admin", 
			Password:   "admin123",
		},
		{
			Email:      "teller@example.com",
			FirstName:  "John",
			LastName:   "Doe",
			Status:     "active",
			Role:       "teller",
			Password:   "teller123",
		},
	}

	for _, user := range users {
		err := s.createUser(user)
		if err != nil {
			return fmt.Errorf("error seeding user %s: %w", user.Email, err)
		}
	}

	return nil
}

func (s *UserSeeder) createUser(u models.User) error {
	// Check if user already exists
	var count int
	err := s.db.QueryRow(
		"SELECT COUNT(*) FROM users WHERE email = $1", 
		u.Email,
	).Scan(&count)
	if err != nil {
		return fmt.Errorf("error checking for existing user: %w", err)
	}

	if count > 0 {
		log.Printf("User %s already exists, skipping", u.Email)
		return nil
	}

	// Hash password
	hashedPassword, err := bcrypt.GenerateFromPassword(
		[]byte(u.Password), 
		bcrypt.DefaultCost,
	)
	if err != nil {
		return fmt.Errorf("error hashing password: %w", err)
	}

	// Get role ID
	var roleID int
	err = s.db.QueryRow(
		"SELECT id FROM roles WHERE name = $1", 
		u.Role,
	).Scan(&roleID)
	if err != nil {
		return fmt.Errorf("error getting role ID: %w", err)
	}

	// Insert user
	_, err = s.db.Exec(
		`INSERT INTO users (
			email, first_name, last_name, status, role_id, password_hash
		) VALUES ($1, $2, $3, $4, $5, $6)`,
		u.Email,
		u.FirstName,
		u.LastName,
		u.Status,
		roleID,
		hashedPassword,
	)
	if err != nil {
		return fmt.Errorf("error creating user: %w", err)
	}

	log.Printf("Created user: %s", u.Email)
	return nil
}
```

## 10. Best Practices

### 10.1 Data Consistency
- Use transactions for related data
- Handle errors gracefully
- Validate data before insertion

### 10.2 Performance
- Use bulk inserts for large datasets
- Disable triggers and constraints when possible
- Re-enable constraints after seeding

### 10.3 Security
- Never commit sensitive data
- Use environment variables for secrets
- Hash all passwords

## 11. Common Tasks

### 11.1 Resetting the Database
```bash
# Drop and recreate database
dropdb global_remit && createdb global_remit

# Run migrations
go run cmd/migrate/main.go up

# Seed data
go run cmd/seed/main.go --env=development
```

### 11.2 Updating Seed Data
1. Update seed scripts
2. Test locally
3. Commit changes
4. Update documentation

## 12. Documentation
- Document all seed data
- Include usage instructions
- Document any dependencies
- Keep examples up to date
