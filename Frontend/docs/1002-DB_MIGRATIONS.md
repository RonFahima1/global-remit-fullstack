# Database Migrations Strategy

## 1. Overview

This document outlines the strategy for managing database schema changes in the Global Remit Teller application. We use a version-controlled migration approach to ensure consistent and reliable database schema updates across all environments.

## 2. Tools

### 2.1 Migration Tool
We use [golang-migrate](https://github.com/golang-migrate/migrate) for database migrations. It provides:
- Support for both SQL and Go-based migrations
- Transactional migrations
- Version control integration
- Support for multiple database backends (PostgreSQL)

### 2.2 Directory Structure
```
db/
├── migrations/
│   ├── 000001_initial_schema.up.sql
│   ├── 000001_initial_schema.down.sql
│   ├── 000002_add_user_roles.up.sql
│   └── 000002_add_user_roles.down.sql
└── README.md
```

## 3. Naming Conventions

### 3.1 File Naming
- Format: `{version}_{description}.{direction}.{extension}`
- Example: `000001_initial_schema.up.sql`

### 3.2 Versioning
- Use sequential numbers (000001, 000002, etc.)
- Each migration must have both `up` and `down` files
- Never modify a migration after it has been applied to any environment

## 4. Migration Types

### 4.1 SQL Migrations
- Used for most schema changes
- Stored in `.sql` files
- Supports PostgreSQL-specific syntax

### 4.2 Go Migrations
- For complex migrations requiring application logic
- Stored in `.go` files
- Must implement the `migrate.Migration` interface

## 5. Best Practices

### 5.1 Atomic Changes
- Each migration should make a single, atomic change
- Use transactions for multi-statement migrations
- Include error handling for data-dependent migrations

### 5.2 Idempotency
- All migrations must be idempotent
- Use `IF NOT EXISTS` for table/column creation
- Use `IF EXISTS` for drops

### 5.3 Backward Compatibility
- Maintain backward compatibility for at least one release
- Use feature flags for breaking changes
- Document deprecation timelines

## 6. Migration Process

### 6.1 Development Workflow
1. Create migration files
2. Test locally
3. Commit to feature branch
4. Open pull request
5. Code review
6. Merge to main

### 6.2 Deployment
1. Run migrations in CI/CD pipeline
2. Verify success before application deployment
3. Rollback on failure

## 7. Rollback Strategy

### 7.1 Automatic Rollback
- Failed migrations are automatically rolled back
- Use transactions for data safety
- Test rollbacks during development

### 7.2 Manual Rollback
1. Revert application code
2. Run `migrate down`
3. Verify database state

## 8. Example Migrations

### 8.1 Creating a Table
```sql
-- 000001_create_users.up.sql
CREATE TABLE IF NOT EXISTS users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email VARCHAR(255) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

-- Add indexes
CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);

-- 000001_create_users.down.sql
DROP TABLE IF EXISTS users CASCADE;
```

### 8.2 Adding a Column
```sql
-- 000002_add_phone_to_users.up.sql
ALTER TABLE users 
ADD COLUMN IF NOT EXISTS phone_number VARCHAR(20),
ADD COLUMN IF NOT EXISTS phone_verified BOOLEAN DEFAULT FALSE;

-- Create index
CREATE INDEX IF NOT EXISTS idx_users_phone ON users(phone_number) WHERE phone_number IS NOT NULL;

-- 000002_add_phone_to_users.down.sql
ALTER TABLE users 
DROP COLUMN IF EXISTS phone_number,
DROP COLUMN IF EXISTS phone_verified;
```

## 9. Data Migrations

### 9.1 When to Use
- Backfilling data
- Data transformations
- One-time data fixes

### 9.2 Example
```sql
-- 000003_backfill_user_roles.up.sql
-- Ensure the roles table exists
CREATE TABLE IF NOT EXISTS roles (
    id SERIAL PRIMARY KEY,
    name VARCHAR(50) NOT NULL UNIQUE,
    description TEXT
);

-- Insert default roles if they don't exist
INSERT INTO roles (name, description) 
VALUES 
    ('admin', 'Administrator with full access'),
    ('teller', 'Teller with limited access'),
    ('viewer', 'Read-only access')
ON CONFLICT (name) DO NOTHING;

-- Add role_id to users table if it doesn't exist
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                  WHERE table_name = 'users' AND column_name = 'role_id') THEN
        ALTER TABLE users ADD COLUMN role_id INTEGER REFERENCES roles(id);
    END IF;
END $$;

-- Set default role to 'teller' for existing users
UPDATE users SET role_id = (SELECT id FROM roles WHERE name = 'teller') 
WHERE role_id IS NULL;

-- 000003_backfill_user_roles.down.sql
-- No down migration as this is a data migration
-- We don't want to lose data on rollback
```

## 10. Testing Migrations

### 10.1 Local Testing
1. Create a test database
2. Run all migrations
3. Verify schema and data
4. Test rollback

### 10.2 Automated Testing
- Include migration tests in CI pipeline
- Test against multiple PostgreSQL versions
- Verify migration order and dependencies

## 11. Version Control

### 11.1 Branching Strategy
- Create a feature branch for migrations
- Include migration files in the same PR as related code changes
- Never modify committed migrations

### 11.2 Code Review
- Review SQL for performance implications
- Check for missing indexes
- Verify transaction boundaries
- Review rollback strategy

## 12. Deployment

### 12.1 Staging
1. Run migrations in staging first
2. Verify application functionality
3. Monitor performance

### 12.2 Production
1. Schedule during maintenance window
2. Take database backup
3. Run migrations
4. Verify application
5. Monitor for issues

## 13. Monitoring

### 13.1 Metrics
- Migration duration
- Success/failure rates
- Application performance after migration

### 13.2 Alerts
- Failed migrations
- Long-running migrations
- Performance degradation

## 14. Rollback Plan

### 14.1 Automated Rollback
- For failed deployments
- Reverts the last migration
- Restores from backup if needed

### 14.2 Manual Rollback
1. Identify the target version
2. Run `migrate down`
3. Verify database state
4. Rollback application if needed

## 15. Documentation

### 15.1 Migration Logs
- Record all migrations
- Include timestamps and users
- Track execution time

### 15.2 Runbooks
- Common migration scenarios
- Troubleshooting guide
- Emergency contacts
