# Database Schema Design Overview

## Introduction
This document provides a high-level overview of the database schema design for the Global Remit application. The database is organized into logical schemas for better management, security, and maintainability.

## Schema Organization

The database is divided into the following logical schemas:

| Schema | Purpose | Key Tables | Documentation |
|--------|---------|------------|---------------|
| `auth` | Authentication & Authorization | users, roles, permissions | [Auth Schema](./031.1-AUTH-SCHEMA.md) |
| `core` | Core Business Entities | clients, accounts, transactions | [Core Clients](./031.2-CORE-CLIENTS-SCHEMA.md), [Core Accounts](./031.3-CORE-ACCOUNTS-SCHEMA.md), [Core Transactions](./031.4-CORE-TRANSACTIONS-SCHEMA.md) |
| `compliance` | Compliance Operations | kyc_verifications, aml_checks, sanctions_matches, audit_logs | [Compliance Schema](./031.5-COMPLIANCE-SCHEMA.md) |
| `config` | System Configuration | settings, currencies, exchange_rates, fee_structures | [Config Schema](./031.6-CONFIG-SCHEMA.md) |
| *Audit* | Audit Trails | *(see compliance.audit_logs)* | [Audit Schema](./031.7-AUDIT-SCHEMA.md) |

## Design Principles

1. **Modularity**
   - Related tables are grouped into logical schemas
   - Clear separation of concerns between different functional areas
   - Minimized cross-schema dependencies

2. **Data Integrity**
   - Primary and foreign key constraints
   - Check constraints for data validation
   - Appropriate data types and nullability

3. **Performance**
   - Strategic indexing
   - Partitioning for large tables
   - Proper data types to minimize storage

4. **Security**
   - Row-level security (RLS) where appropriate
   - Sensitive data encryption
   - Principle of least privilege for database users

5. **Auditability**
   - Comprehensive audit logging
   - Versioning for critical tables
   - Created/updated timestamps and user tracking

## Schema Details

### 1. Auth Schema
Handles authentication, authorization, and user management.
- User authentication and session management
- Role-based access control (RBAC)
- Permission management

### 2. Core Schemas
#### 2.1 Core Clients
- Client profiles and demographics
- Contact information
- KYC and identification data

#### 2.2 Core Accounts
- Account management
- Balance tracking
- Account types and statuses

#### 2.3 Core Transactions
- Transaction processing
- Transaction types and statuses
- Ledger entries

### 3. Compliance Schema
- KYC verification tracking
- AML screening and monitoring
- Sanctions checking
- Audit logging

### 4. Config Schema
- System settings and parameters
- Currency and exchange rate management
- Fee structures and rules

## Naming Conventions

### Tables
- Use plural nouns (e.g., `users`, `transactions`)
- Use snake_case
- Be descriptive but concise

### Columns
- Use singular form (e.g., `first_name`, `created_at`)
- Use snake_case
- Use consistent naming across tables for similar concepts

### Constraints
- Primary keys: `pk_<table>_<columns>`
- Foreign keys: `fk_<table>_<referenced_table>_<columns>`
- Unique constraints: `uq_<table>_<columns>`
- Check constraints: `chk_<table>_<description>`

## Data Types

| Purpose | Data Type | Example |
|---------|-----------|---------|
| Unique identifier | UUID | `id UUID PRIMARY KEY DEFAULT gen_random_uuid()` |
| Short text | VARCHAR(n) | `first_name VARCHAR(100)` |
| Long text | TEXT | `description TEXT` |
| Integer | INTEGER | `attempts INTEGER` |
| Decimal | NUMERIC(p,s) | `amount NUMERIC(20, 4)` |
| Boolean | BOOLEAN | `is_active BOOLEAN` |
| Date/Time | TIMESTAMPTZ | `created_at TIMESTAMPTZ` |
| JSON Data | JSONB | `metadata JSONB` |

## Indexing Strategy

### Primary Indexes
- All tables have a primary key
- UUID primary keys for distributed systems compatibility

### Secondary Indexes
- Foreign key columns
- Frequently filtered or sorted columns
- Columns used in JOIN operations

### Partial Indexes
- For queries that filter on a specific value
- Example: `WHERE status = 'active'`

## Partitioning

### Partitioned Tables
1. `compliance.audit_logs`
   - Partitioned by date range
   - Monthly partitions
   - Old partitions moved to cold storage

## Security

### Row-Level Security (RLS)
- Enabled on all tables with sensitive data
- Policies define access at the row level
- Based on user roles and permissions

### Encryption
- Data at rest: TDE (Transparent Data Encryption)
- Data in transit: TLS 1.3
- Sensitive fields: Application-level encryption

## Maintenance

### Vacuum and Analyze
- Auto-vacuum with aggressive settings
- Auto-analyze for query planner statistics

### Reindexing
- Regular reindexing of frequently updated tables
- CONCURRENTLY to avoid locks

## Related Documents
- [Database Overview](../030-DATABASE-OVERVIEW.md)
- [Database Security](../039-DATABASE-SECURITY.md)
- [Performance Tuning](../038-PERFORMANCE-TUNING.md)
- [Migrations Guide](../035-MIGRATIONS-GUIDE.md)

## Version History
| Date | Version | Description |
|------|---------|-------------|
| 2025-06-20 | 1.0 | Initial version |
