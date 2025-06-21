# Database Seed Data Guide

## Introduction
This document outlines the strategy for managing seed data in the Global Remit application. Seed data includes reference data, lookup tables, initial configuration, test data, and any other data required for the application to function properly.

## Table of Contents
- [Seed Data Types](#seed-data-types)
- [Seed Data Management](#seed-data-management)
- [Environment-Specific Data](#environment-specific-data)
- [Seed Data Format](#seed-data-format)
- [Loading Seed Data](#loading-seed-data)
- [Version Control](#version-control)
- [Best Practices](#best-practices)
- [Related Documents](#related-documents)
- [Version History](#version-history)

## Seed Data Types

### 1. Reference Data
- Static data that rarely changes
- Examples: Countries, currencies, transaction types, account types

### 2. Configuration Data
- System configuration values
- Examples: Application settings, feature flags, business rules

### 3. Test Data
- Data used for development and testing
- Examples: Test users, sample transactions, mock clients

### 4. Initial Setup Data
- Data required for initial application setup
- Examples: Default admin user, initial roles and permissions

## Seed Data Management

### File Organization
```
database/
├── seeds/
│   ├── reference/               # Reference data
│   │   ├── countries.sql
│   │   ├── currencies.sql
│   │   └── transaction_types.sql
│   │
│   ├── backend/config/                  # Configuration data
│   │   ├── system_settings.sql
│   │   └── fee_structures.sql
│   │
│   ├── test/                    # Test data
│   │   ├── test_users.sql
│   │   └── sample_transactions.sql
│   │
│   └── initial/                 # Initial setup data
│       ├── admin_user.sql
│       └── roles_permissions.sql
│
└── migrations/                 # Database migrations
    └── ...
```

### Naming Conventions
- Use snake_case for all file names
- Prefix with load_ for loader scripts (e.g., `load_reference_data.sql`)
- Group related data in the same directory
- Use descriptive names that indicate the content

## Environment-Specific Data

### Development
- Contains sample data for local development
- May include test accounts with known credentials
- Should represent a realistic but not production dataset

### Staging
- Similar to production but with obfuscated or synthetic data
- Used for testing and validation
- Should match production schema and constraints

### Production
- Minimal initial data only
- No test or sample data
- Typically loaded during initial deployment

## Seed Data Format

### SQL Format
```sql
-- Reference data example: Countries
INSERT INTO core.countries (code, name, is_active, created_at, updated_at)
VALUES 
    ('US', 'United States', true, NOW(), NOW()),
    ('GB', 'United Kingdom', true, NOW(), NOW()),
    ('CA', 'Canada', true, NOW(), NOW())
ON CONFLICT (code) 
DO UPDATE SET 
    name = EXCLUDED.name,
    is_active = EXCLUDED.is_active,
    updated_at = NOW();

-- Configuration data example: System Settings
INSERT INTO config.settings (key, value, description, is_public, created_at, updated_at)
VALUES 
    ('app.name', 'Global Remit', 'Application name', true, NOW(), NOW()),
    ('app.timezone', 'UTC', 'Default timezone', true, NOW(), NOW()),
    ('security.password.min_length', '8', 'Minimum password length', false, NOW(), NOW())
ON CONFLICT (key) 
DO UPDATE SET 
    value = EXCLUDED.value,
    description = EXCLUDED.description,
    is_public = EXCLUDED.is_public,
    updated_at = NOW();
```

### CSV Format
For large datasets, use CSV files with `\copy` commands:

```sql
-- Load countries from CSV
\copy core.countries (code, name, is_active) FROM 'seeds/reference/countries.csv' WITH (FORMAT csv, HEADER true);

-- Load exchange rates from CSV
\copy config.exchange_rates (from_currency, to_currency, rate, effective_date) 
FROM 'seeds/reference/exchange_rates.csv' 
WITH (FORMAT csv, HEADER true);
```

## Loading Seed Data

### 1. Initial Database Setup
```bash
# Load all seed data
psql -U $DB_USER -d $DB_NAME -f database/seeds/load_all.sql

# Load specific seed data
psql -U $DB_USER -d $DB_NAME -f database/seeds/reference/countries.sql
```

### 2. Using Docker
```bash
# Load seed data in a container
docker-compose exec -T db psql -U $POSTGRES_USER -d $POSTGRES_DB < database/seeds/load_all.sql
```

### 3. Programmatic Loading
Create a Go script to load seed data with proper error handling and logging:

```go
// cmd/seed/main.go
package main

import (
	"database/sql"
	"fmt"
	"io/ioutil"
	"log"
	"os"
	"path/filepath"

	_ "github.com/lib/pq"
)

func main() {
	// Database connection
	db, err := sql.Open("postgres", os.Getenv("DATABASE_URL"))
	if err != nil {
		log.Fatalf("Failed to connect to database: %v", err)
	}
	defer db.Close()

	// Load and execute seed files
	seedDir := "database/seeds/reference"
	files, err := ioutil.ReadDir(seedDir)
	if err != nil {
		log.Fatalf("Failed to read seed directory: %v", err)
	}

	for _, file := range files {
		if filepath.Ext(file.Name()) == ".sql" {
			path := filepath.Join(seedDir, file.Name())
			sql, err := ioutil.ReadFile(path)
			if err != nil {
				log.Printf("Error reading %s: %v", path, err)
				continue
			}

			_, err = db.Exec(string(sql))
			if err != nil {
				log.Printf("Error executing %s: %v", path, err)
				continue
			}

			fmt.Printf("Loaded seed data: %s\n", file.Name())
		}
	}
}
```

## Version Control

### 1. Seed Data Changes
- Treat seed data changes like code changes
- Include in version control
- Document changes in pull requests

### 2. Data Migration
For changes to existing seed data:

```sql
-- Example: Update existing seed data
UPDATE config.settings 
SET value = '12', 
    updated_at = NOW()
WHERE key = 'security.password.min_length';

-- Example: Add new countries
INSERT INTO core.countries (code, name, is_active, created_at, updated_at)
VALUES 
    ('FR', 'France', true, NOW(), NOW()),
    ('DE', 'Germany', true, NOW(), NOW())
ON CONFLICT (code) 
DO UPDATE SET 
    name = EXCLUDED.name,
    is_active = EXCLUDED.is_active,
    updated_at = NOW();
```

## Best Practices

### 1. Idempotency
- Ensure seed scripts can be run multiple times without side effects
- Use `INSERT ... ON CONFLICT` for upserts
- Include `created_at` and `updated_at` timestamps

### 2. Performance
- Use transactions for data integrity
- Load data in batches for large datasets
- Disable triggers and indexes during bulk loads when possible

### 3. Security
- Never include sensitive data in seed files
- Use environment variables for secrets
- Validate all input data

### 4. Maintenance
- Keep seed data up to date with schema changes
- Document all seed data
- Include data validation scripts

## Related Documents
- [Database Overview](./030-DATABASE-OVERVIEW.md)
- [Schema Design Overview](./031-SCHEMA-DESIGN-OVERVIEW.md)
- [Migrations Guide](./036-MIGRATIONS-GUIDE.md)
- [Backup and Recovery](./037-BACKUP-RECOVERY.md)

## Version History
| Date | Version | Description |
|------|---------|-------------|
| 2025-06-20 | 1.0 | Initial version |
