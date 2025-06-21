# Database Migrations Guide

## Introduction
This document outlines the database migration strategy for the Global Remit application. Database migrations are version-controlled SQL scripts that manage incremental, reversible changes to the database schema and reference data.

## Table of Contents
- [Migration Tools](#migration-tools)
- [Migration File Naming](#migration-file-naming)
- [Migration Structure](#migration-structure)
- [Creating Migrations](#creating-migrations)
- [Running Migrations](#running-migrations)
- [Rolling Back Migrations](#rolling-back-migrations)
- [Environment-Specific Migrations](#environment-specific-migrations)
- [Data Migrations](#data-migrations)
- [Migration Best Practices](#migration-best-practices)
- [Troubleshooting](#troubleshooting)
- [Related Documents](#related-documents)
- [Version History](#version-history)

## Migration Tools

### Primary Tool: Flyway
We use [Flyway](https://flywaydb.org/) as our database migration tool due to its:
- Simple SQL-based migrations
- Version control integration
- Support for multiple databases
- Community and enterprise support
- Easy integration with CI/CD pipelines

### Alternative: Manual SQL Scripts
For complex migrations that can't be handled by Flyway, we maintain manual SQL scripts in the `database/manual_migrations` directory.

## Migration File Naming

### Versioned Migrations
```
backend/db/migrations/
  V{version}__{description}.sql
  V1.1__create_users_table.sql
  V1.2__add_email_to_users.sql
```

### Repeatable Migrations
```
backend/db/migrations/
  R__update_monthly_metrics_view.sql
  R__refresh_materialized_views.sql
```

### Undo Migrations
```
backend/db/migrations/undo/
  U1.1__drop_users_table.sql
```

## Migration Structure

### Project Structure
```
database/
├── migrations/               # Flyway SQL migrations
│   ├── V1__initial_schema.sql
│   └── V2__add_user_preferences.sql
├── manual_migrations/       # Complex migrations
│   └── 2025-06-20_data_migration/
│       ├── README.md
│       ├── pre_migration.sql
│       ├── migration.sh
│       └── verify.sql
└── seeds/                   # Reference data
    ├── reference_data.sql
    └── test_data.sql
```

### SQL File Structure
```sql
-- +migrate Up
-- SQL in this section is executed when the migration is applied
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email VARCHAR(255) NOT NULL UNIQUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- +migrate Down
-- SQL in this section is executed when the migration is rolled back
DROP TABLE IF EXISTS users;
```

## Creating Migrations

### 1. Generate a New Migration
```bash
# Install flyway CLI (if not already installed)
# Create a new migration file
touch database/migrations/V$(date +%Y%m%d%H%M%S)__your_migration_description.sql
```

### 2. Write the Migration
```sql
-- +migrate Up
CREATE TABLE transactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    account_id UUID NOT NULL REFERENCES accounts(id),
    amount DECIMAL(20, 4) NOT NULL,
    transaction_date TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    status VARCHAR(20) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_transactions_account_id ON transactions(account_id);
CREATE INDEX idx_transactions_date ON transactions(transaction_date);

-- +migrate Down
DROP TABLE IF EXISTS transactions;
```

### 3. Add DDL Statements
- Use `CREATE TABLE`, `ALTER TABLE`, etc.
- Include necessary constraints and indexes
- Add comments for complex operations

### 4. Add Data Migrations (if needed)
```sql
-- +migrate Up
-- Migrate existing data to the new schema
INSERT INTO new_table (col1, col2)
SELECT old_col1, old_col2 FROM old_table
WHERE condition;

-- +migrate Down
-- Reverse the data migration if needed
DELETE FROM new_table WHERE condition;
```

## Running Migrations

### Local Development
```bash
# Run all pending migrations
flyway migrate -configFiles=flyway.conf

# Validate migrations (without running them)
flyway validate -configFiles=flyway.conf

# Show migration status
flyway info -configFiles=flyway.conf
```

### Configuration File (`flyway.conf`)
```properties
flyway.url=jdbc:postgresql://localhost:5432/global_remit
flyway.user=db_user
flyway.password=db_password
flyway.locations=filesystem:database/migrations
flyway.baselineOnMigrate=true
flyway.baselineVersion=0
flyway.validateOnMigrate=true
```

### Production Deployment
In production, migrations should be run as part of the CI/CD pipeline:

```yaml
# .github/workflows/migrate-db.yml
name: Database Migrations

on:
  push:
    branches: [ main ]
    paths:
      - 'database/migrations/**'

jobs:
  migrate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      
      - name: Set up JDK
        uses: actions/setup-java@v2
        with:
          java-version: '11'
          
      - name: Set up Flyway
        run: |
          wget -qO- https://repo1.maven.org/maven2/org/flywaydb/flyway-commandline/8.5.10/flyway-commandline-8.5.10-linux-x64.tar.gz | tar xvz
          echo "$(pwd)/flyway-8.5.10" >> $GITHUB_PATH
          
      - name: Run migrations
        run: |
          cat > flyway.conf <<EOL
          flyway.url=${{ secrets.DB_URL }}
          flyway.user=${{ secrets.DB_USER }}
          flyway.password=${{ secrets.DB_PASSWORD }}
          flyway.locations=filesystem:database/migrations
          flyway.baselineOnMigrate=true
          flyway.validateOnMigrate=true
          EOL
          
          flyway -configFiles=flyway.conf migrate
```

## Rolling Back Migrations

### 1. Create a Down Migration
For each `V{version}__description.sql` file, include a corresponding `U{version}__description.sql` in the `undo` directory.

### 2. Manual Rollback
```bash
# Revert the last migration
flyway undo -configFiles=flyway.conf

# Revert to a specific version
flyway undo -target=1.1 -configFiles=flyway.conf
```

### 3. Emergency Rollback Procedure
1. Restore from backup
2. Replay migrations up to the desired version
3. Verify data consistency

## Environment-Specific Migrations

### Conditional SQL
```sql
-- +migrate Up
-- Only run in development
DO $$
BEGIN
    IF current_setting('app.env') = 'development' THEN
        -- Development-only operations
        CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_debug ON debug_table(debug_column);
    END IF;
END
$$;
```

### Environment Variables in Migrations
```sql
-- +migrate Up
-- Set admin email from environment variable
INSERT INTO users (email, role, created_at)
VALUES ('${ADMIN_EMAIL:-admin@example.com}', 'admin', NOW());
```

## Data Migrations

### Best Practices
1. **Idempotency**: Ensure migrations can be run multiple times without side effects
2. **Backup First**: Always backup before running data migrations
3. **Transaction Safety**: Use transactions where possible
4. **Batch Processing**: Process large datasets in batches

### Example: Migrate User Data
```sql
-- +migrate Up
-- Migrate user data in batches to avoid locks
DO $$
DECLARE
    batch_size INTEGER := 1000;
    offset_val INTEGER := 0;
    rows_affected INTEGER;
BEGIN
    LOOP
        BEGIN
            -- Use a transaction for each batch
            WITH updated AS (
                UPDATE users u
                SET 
                    email = LOWER(TRIM(u.email)),
                    updated_at = NOW()
                FROM (
                    SELECT id 
                    FROM users 
                    WHERE email ~* '[A-Z]' OR email ~ '\\s+'
                    ORDER BY id
                    LIMIT batch_size
                    OFFSET offset_val
                    FOR UPDATE SKIP LOCKED
                ) AS batch
                WHERE u.id = batch.id
                RETURNING 1
            )
            SELECT COUNT(*) INTO rows_affected FROM updated;
            
            -- Commit this batch
            COMMIT;
            
            -- Exit if no more rows to process
            EXIT WHEN rows_affected = 0;
            
            -- Process next batch
            offset_val := offset_val + batch_size;
            
            -- Add a small delay to reduce database load
            PERFORM pg_sleep(0.1);
            
        EXCEPTION WHEN OTHERS THEN
            -- Log error and continue with next batch
            RAISE WARNING 'Error processing batch %: %', offset_val, SQLERRM;
            ROLLBACK;
            offset_val := offset_val + batch_size;
        END;
    END LOOP;
END;
$$;
```

## Migration Best Practices

### 1. Keep Migrations Small and Focused
- Each migration should do one thing well
- Avoid mixing schema and data changes when possible
- Keep migrations short and focused

### 2. Make Migrations Idempotent
```sql
-- Good
CREATE TABLE IF NOT EXISTS users (...);

-- Better
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'users') THEN
        CREATE TABLE users (...);
    END IF;
END
$$;
```

### 3. Handle Dependencies
- Order migrations to respect foreign key constraints
- Use `CREATE SCHEMA IF NOT EXISTS` for schema creation
- Add `IF NOT EXISTS` to `CREATE` statements

### 4. Performance Considerations
- Avoid long-running transactions
- Use `CONCURRENTLY` for index creation on large tables
- Consider disabling triggers for bulk operations

### 5. Testing
- Test all migrations in a staging environment first
- Include rollback tests
- Test with production-like data volumes

## Troubleshooting

### Common Issues

#### 1. Migration Fails with Duplicate Key
**Symptom**: `ERROR: duplicate key value violates unique constraint`
**Solution**: Make the migration idempotent or fix the data before migration

#### 2. Long-Running Migration
**Symptom**: Migration takes too long and times out
**Solution**:
- Break into smaller migrations
- Run during maintenance window
- Use batch processing for large data changes

#### 3. Missing Migration Files
**Symptom**: `ERROR: Missing migration file`
**Solution**:
- Ensure all migration files are committed to version control
- Check file naming conventions
- Verify file permissions

### Recovery Procedures

#### 1. Failed Migration
1. Identify the failed migration
2. Fix the issue in the migration file
3. Run `flyway repair` to mark the migration as failed
4. Rerun the migration

#### 2. Corrupted Schema Version Table
```bash
# Check current schema version
psql -c "SELECT version, description, installed_on, success FROM flyway_schema_history ORDER BY installed_rank DESC LIMIT 5;"

# If needed, repair the schema version table
flyway repair -configFiles=flyway.conf
```

## Related Documents
- [Database Overview](./030-DATABASE-OVERVIEW.md)
- [Schema Design Overview](./031-SCHEMA-DESIGN-OVERVIEW.md)
- [Tables Reference](./032-TABLES-REFERENCE.md)
- [Indexing Strategy](./033-INDEXING-STRATEGY.md)
- [Query Patterns](./034-QUERY-PATTERNS.md)
- [Partitioning Strategy](./035-PARTITIONING-STRATEGY.md)
- [Backup and Recovery](./037-BACKUP-RECOVERY.md)

## Version History
| Date | Version | Description |
|------|---------|-------------|
| 2025-06-20 | 1.0 | Initial version |
