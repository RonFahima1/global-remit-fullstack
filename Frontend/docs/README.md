# Global Remit Database Documentation

## Overview
This documentation covers the database design and architecture for the Global Remit application, a comprehensive banking solution for money transfer operations.

## Table of Contents
1. [Database Overview](#database-overview)
2. [Schema Organization](#schema-organization)
3. [Core Tables](#core-tables)
4. [Authentication & Authorization](#authentication--authorization)
5. [Client Management](#client-management)
6. [Account Management](#account-management)
7. [Transaction Management](#transaction-management)
8. [Compliance & Security](#compliance--security)
9. [System Configuration](#system-configuration)
10. [Data Access Patterns](#data-access-patterns)
11. [Performance Considerations](#performance-considerations)
12. [Migration Strategy](#migration-strategy)

## Database Overview

### Technology Stack
- **Primary Database**: PostgreSQL 14+
- **Caching**: Redis
- **ORM**: Prisma
- **Version Control**: Database migrations managed via Prisma Migrate

### Design Principles
- **Data Integrity**: Enforced through constraints, foreign keys, and proper data types
- **Security**: Row-level security, encryption, and access controls
- **Auditability**: Comprehensive change tracking and historical records
- **Performance**: Optimized indexing and partitioning strategies
- **Scalability**: Designed to handle growth in data volume and transaction throughput

## Schema Organization

The database is organized into logical schemas for better management and security:

### Core Schemas:

1. **`auth`**
   - Purpose: Authentication and authorization
   - Contains: Users, roles, permissions, sessions
   - Access: Restricted to authentication services

2. **`core`**
   - Purpose: Core business entities
   - Contains: Clients, accounts, transactions, branches
   - Access: Main application services

3. **`transactions`**
   - Purpose: Transaction processing
   - Contains: Transaction records, ledgers, remittance details
   - Access: Transaction processing services

4. **`compliance`**
   - Purpose: Regulatory compliance
   - Contains: KYC/AML checks, audit logs
   - Access: Compliance team and auditing services

5. **`config`**
   - Purpose: System configuration
   - Contains: Currencies, exchange rates, fee structures
   - Access: Configuration management services

6. **`audit`**
   - Purpose: Audit trails
   - Contains: Change logs, access logs
   - Access: Auditing services and compliance

## Naming Conventions

### Tables
- Use plural nouns (e.g., `users`, `transactions`)
- Use snake_case for table names
- Prefix with schema name in SQL queries (e.g., `auth.users`)

### Columns
- Use snake_case
- Use `_id` suffix for foreign keys
- Use `is_` prefix for boolean flags
- Use `_at` suffix for timestamps
- Use `_by` suffix for user references

### Constraints
- Primary Key: `pk_<table>_<columns>`
- Foreign Key: `fk_<table>_<referenced_table>_<column>`
- Unique: `uq_<table>_<columns>`
- Check: `ck_<table>_<constraint_name>`
- Index: `ix_<table>_<columns>`

## Documentation Structure

Detailed documentation for each schema and its components is organized in separate markdown files:

1. [Authentication & Authorization](auth/README.md)
2. [Client Management](client-management/README.md)
3. [Account Management](account-management/README.md)
4. [Transaction Management](transaction-management/README.md)
5. [Compliance & Security](compliance/README.md)
6. [System Configuration](config/README.md)

## Getting Started

### Prerequisites
- PostgreSQL 14+
- Redis (for caching)
- Node.js 16+

### Setup
1. Clone the repository
2. Install dependencies: `npm install`
3. Set up environment variables (copy .env.example to .env)
4. Run migrations: `npx prisma migrate deploy`
5. Start the application: `npm run dev`

## Contributing
Please read [CONTRIBUTING.md](../CONTRIBUTING.md) for details on our code of conduct and the process for submitting pull requests.

## License
This project is licensed under the MIT License - see the [LICENSE.md](../LICENSE.md) file for details.

## Documentation Team
- Database Architect: [Your Name]
- Last Updated: June 20, 2025
