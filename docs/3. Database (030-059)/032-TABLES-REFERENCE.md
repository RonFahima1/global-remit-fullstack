# Database Tables Reference

## Introduction
This document serves as a quick reference for all database tables across all schemas in the Global Remit application. For detailed schema information, please refer to the individual schema documentation files.

## Table of Contents
- [Auth Schema](#auth-schema)
- [Core Schema](#core-schema)
  - [Clients](#coreclients)
  - [Accounts](#coreaccounts)
  - [Transactions](#coretransactions)
- [Compliance Schema](#compliance-schema)
- [Config Schema](#config-schema)
- [Audit Schema](#audit-schema)

## Auth Schema

### users
Stores user authentication and profile information.
- **Primary Key**: `id` (UUID)
- **Key Columns**: `email`, `username`
- **Related Tables**: `auth.roles` (via `role_id`)
- **Documentation**: [Auth Schema](./031.1-AUTH-SCHEMA.md#users)

### roles
Defines user roles and their permissions.
- **Primary Key**: `id` (SERIAL)
- **Key Columns**: `name`
- **Related Tables**: `auth.role_permissions`, `auth.users`
- **Documentation**: [Auth Schema](./031.1-AUTH-SCHEMA.md#roles)

### permissions
Defines system permissions that can be assigned to roles.
- **Primary Key**: `id` (SERIAL)
- **Key Columns**: `code`, `name`
- **Related Tables**: `auth.role_permissions`
- **Documentation**: [Auth Schema](./031.1-AUTH-SCHEMA.md#permissions)

### role_permissions
Maps permissions to roles (many-to-many relationship).
- **Primary Key**: (`role_id`, `permission_id`)
- **Related Tables**: `auth.roles`, `auth.permissions`
- **Documentation**: [Auth Schema](./031.1-AUTH-SCHEMA.md#role_permissions)

### sessions
Tracks user sessions for authentication.
- **Primary Key**: `id` (UUID)
- **Key Columns**: `user_id`, `token_hash`
- **Related Tables**: `auth.users`
- **Documentation**: [Auth Schema](./031.1-AUTH-SCHEMA.md#sessions)

## Core Schema

### Core.Clients

#### clients
Stores client profile information.
- **Primary Key**: `id` (UUID)
- **Key Columns**: `client_number`, `email`, `phone`
- **Related Tables**: `core.addresses`, `core.identifications`
- **Documentation**: [Core Clients Schema](./031.2-CORE-CLIENTS-SCHEMA.md#clients)

#### addresses
Stores client addresses.
- **Primary Key**: `id` (UUID)
- **Key Columns**: `client_id`, `type`
- **Related Tables**: `core.clients`
- **Documentation**: [Core Clients Schema](./031.2-CORE-CLIENTS-SCHEMA.md#addresses)

### Core.Accounts

#### accounts
Manages client accounts.
- **Primary Key**: `id` (UUID)
- **Key Columns**: `account_number`, `client_id`
- **Related Tables**: `core.clients`, `core.transactions`
- **Documentation**: [Core Accounts Schema](./031.3-CORE-ACCOUNTS-SCHEMA.md#accounts)

#### account_types
Defines types of accounts.
- **Primary Key**: `id` (SERIAL)
- **Key Columns**: `code`, `name`
- **Documentation**: [Core Accounts Schema](./031.3-CORE-ACCOUNTS-SCHEMA.md#account_types)

### Core.Transactions

#### transactions
Records all financial transactions.
- **Primary Key**: `id` (UUID)
- **Key Columns**: `transaction_reference`, `account_id`, `transaction_date`
- **Related Tables**: `core.accounts`, `core.transaction_types`
- **Documentation**: [Core Transactions Schema](./031.4-CORE-TRANSACTIONS-SCHEMA.md#transactions)

#### transaction_types
Defines types of transactions.
- **Primary Key**: `id` (SERIAL)
- **Key Columns**: `code`, `name`
- **Related Tables**: `core.transactions`
- **Documentation**: [Core Transactions Schema](./031.4-CORE-TRANSACTIONS-SCHEMA.md#transaction_types)

## Compliance Schema

### kyc_verifications
Tracks KYC verification status for clients.
- **Primary Key**: `id` (UUID)
- **Key Columns**: `client_id`, `verification_status`
- **Related Tables**: `core.clients`
- **Documentation**: [Compliance Schema](./031.5-COMPLIANCE-SCHEMA.md#kyc_verifications)

### aml_checks
Stores Anti-Money Laundering (AML) check results.
- **Primary Key**: `id` (UUID)
- **Key Columns**: `client_id`, `transaction_id`, `check_status`
- **Related Tables**: `core.clients`, `core.transactions`
- **Documentation**: [Compliance Schema](./031.5-COMPLIANCE-SCHEMA.md#aml_checks)

### sanctions_matches
Records potential matches against sanctions lists.
- **Primary Key**: `id` (UUID)
- **Key Columns**: `client_id`, `transaction_id`, `status`
- **Related Tables**: `core.clients`, `core.transactions`
- **Documentation**: [Compliance Schema](./031.5-COMPLIANCE-SCHEMA.md#sanctions_matches)

### audit_logs
Comprehensive audit trail of all system activities.
- **Primary Key**: `id` (UUID)
- **Key Columns**: `event_time`, `event_type`, `user_id`
- **Partitioned**: Yes (by `event_time`)
- **Documentation**: [Compliance Schema](./031.5-COMPLIANCE-SCHEMA.md#audit_logs)

## Config Schema

### settings
Stores system-wide configuration parameters.
- **Primary Key**: `id` (UUID)
- **Key Columns**: `setting_key`
- **Documentation**: [Config Schema](./031.6-CONFIG-SCHEMA.md#settings)

### currencies
Defines supported currencies and their properties.
- **Primary Key**: `code` (CHAR(3))
- **Key Columns**: `is_active`, `is_base_currency`
- **Documentation**: [Config Schema](./031.6-CONFIG-SCHEMA.md#currencies)

### exchange_rates
Stores currency exchange rates.
- **Primary Key**: `id` (UUID)
- **Key Columns**: `from_currency`, `to_currency`, `effective_date`
- **Related Tables**: `config.currencies`
- **Documentation**: [Config Schema](./031.6-CONFIG-SCHEMA.md#exchange_rates)

### fee_structures
Defines fee structures for different transaction types.
- **Primary Key**: `id` (UUID)
- **Key Columns**: `name`, `fee_type`
- **Related Tables**: `config.currencies`
- **Documentation**: [Config Schema](./031.6-CONFIG-SCHEMA.md#fee_structures)

### fee_structure_rules
Defines rules for applying fee structures.
- **Primary Key**: `id` (UUID)
- **Key Columns**: `fee_structure_id`, `rule_type`
- **Related Tables**: `config.fee_structures`, `config.currencies`
- **Documentation**: [Config Schema](./031.6-CONFIG-SCHEMA.md#fee_structure_rules)

## Audit Schema

Note: Audit functionality is implemented through the `compliance.audit_logs` table in the Compliance schema. See [Compliance Schema](./031.5-COMPLIANCE-SCHEMA.md#audit_logs) for details.

## Table Relationships

### Key Relationships
1. **Users → Roles**
   - `auth.users.role_id` → `auth.roles.id`

2. **Clients → Addresses**
   - `core.addresses.client_id` → `core.clients.id`

3. **Clients → Accounts**
   - `core.accounts.client_id` → `core.clients.id`

4. **Accounts → Transactions**
   - `core.transactions.account_id` → `core.accounts.id`

5. **Transactions → Transaction Types**
   - `core.transactions.transaction_type_id` → `core.transaction_types.id`

6. **Clients → KYC Verifications**
   - `compliance.kyc_verifications.client_id` → `core.clients.id`

7. **Exchange Rates → Currencies**
   - `config.exchange_rates.from_currency` → `config.currencies.code`
   - `config.exchange_rates.to_currency` → `config.currencies.code`

## Index Reference

### Common Index Patterns
- All primary keys are automatically indexed
- Foreign key columns are indexed
- Frequently filtered columns are indexed
- Composite indexes for common query patterns

### Important Indexes
- `idx_users_email_lower` - Case-insensitive email lookup
- `idx_transactions_account_date` - Account transaction history
- `idx_audit_logs_event_time` - Time-based audit log queries
- `idx_exchange_rates_effective` - Exchange rate lookups by date

## Data Retention

| Table | Retention Period | Notes |
|-------|------------------|-------|
| `compliance.audit_logs` | 10 years | Monthly partitions, archived after 1 year |
| `core.transactions` | 7 years | Archived after 2 years |
| `auth.sessions` | 90 days | |
| `compliance.kyc_verifications` | 10 years after account closure | |

## Related Documents
- [Database Overview](./030-DATABASE-OVERVIEW.md)
- [Schema Design Overview](./031-SCHEMA-DESIGN-OVERVIEW.md)
- [Auth Schema](./031.1-AUTH-SCHEMA.md)
- [Core Clients Schema](./031.2-CORE-CLIENTS-SCHEMA.md)
- [Core Accounts Schema](./031.3-CORE-ACCOUNTS-SCHEMA.md)
- [Core Transactions Schema](./031.4-CORE-TRANSACTIONS-SCHEMA.md)
- [Compliance Schema](./031.5-COMPLIANCE-SCHEMA.md)
- [Config Schema](./031.6-CONFIG-SCHEMA.md)
- [Audit Schema](./031.7-AUDIT-SCHEMA.md)

## Version History
| Date | Version | Description |
|------|---------|-------------|
| 2025-06-20 | 1.0 | Initial version |
