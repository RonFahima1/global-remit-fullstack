# Global Remit: Database Schema Documentation

## Overview
This document serves as the comprehensive reference for the Global Remit database schema. It consolidates all database design decisions, table structures, relationships, and constraints from the various schema documents.

## Table of Contents
1. [Schema Organization](#schema-organization)
2. [Core Tables](#core-tables)
3. [Client Management](#client-management)
4. [Account Management](#account-management)
5. [Transaction Management](#transaction-management)
6. [Compliance & Security](#compliance--security)
7. [System Configuration](#system-configuration)
8. [Audit & Logging](#audit--logging)
9. [Enums](#enums)
10. [Indexes](#indexes)
11. [Views](#views)
12. [Functions](#functions)
13. [Triggers](#triggers)
14. [Partitioning Strategy](#partitioning-strategy)
15. [Security](#security)

## Schema Organization

The database is organized into logical schemas for better management and security:

| Schema | Purpose | Key Tables |
|--------|---------|------------|
| `core` | Core business entities | clients, accounts, transactions |
| `auth` | Authentication & authorization | users, roles, permissions |
| `compliance` | Compliance operations | kyc_verifications, aml_checks |
| `config` | System configuration | currencies, exchange_rates |
| `audit` | Audit trails | audit_logs |

## Core Tables

### users
Stores system users (Tellers, Admins).

```sql
CREATE TABLE auth.users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    username VARCHAR(50) NOT NULL UNIQUE,
    email VARCHAR(255) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    role VARCHAR(20) NOT NULL CHECK (role IN ('TELLER', 'SENIOR_TELLER', 'MANAGER', 'ADMIN')),
    branch_id UUID REFERENCES core.branches(id),
    is_active BOOLEAN NOT NULL DEFAULT true,
    last_login_at TIMESTAMPTZ,
    failed_login_attempts INTEGER NOT NULL DEFAULT 0,
    password_changed_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by UUID REFERENCES auth.users(id),
    updated_by UUID REFERENCES auth.users(id),
    version INTEGER NOT NULL DEFAULT 1
);
```

## Client Management

### clients
Core client information for individuals and businesses.

```sql
CREATE TABLE core.clients (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    client_type VARCHAR(20) NOT NULL CHECK (client_type IN ('INDIVIDUAL', 'BUSINESS')),
    client_number VARCHAR(20) GENERATED ALWAYS AS (
        'CL' || to_char(created_at, 'YYMM') || lpad(id::text, 8, '0')
    ) STORED,
    
    -- Individual fields
    first_name VARCHAR(100),
    middle_name VARCHAR(100),
    last_name VARCHAR(100),
    date_of_birth DATE,
    gender VARCHAR(10),
    
    -- Business fields
    business_name VARCHAR(255),
    registration_number VARCHAR(50),
    tax_identification_number VARCHAR(50),
    
    -- Common fields
    email VARCHAR(255),
    phone_number VARCHAR(20) NOT NULL,
    country_of_residence CHAR(2) REFERENCES config.countries(code),
    country_of_tax_residence CHAR(2) REFERENCES config.countries(code),
    tax_identification_number_country CHAR(2) REFERENCES config.countries(code),
    
    -- KYC/AML
    kyc_status VARCHAR(20) NOT NULL DEFAULT 'NOT_STARTED' 
        CHECK (kyc_status IN ('NOT_STARTED', 'IN_PROGRESS', 'PENDING_VERIFICATION', 'VERIFIED', 'REJECTED')),
    kyc_verified_at TIMESTAMPTZ,
    kyc_verified_by UUID REFERENCES auth.users(id),
    risk_level VARCHAR(10) NOT NULL DEFAULT 'MEDIUM' 
        CHECK (risk_level IN ('LOW', 'MEDIUM', 'HIGH')),
    
    -- Status
    status VARCHAR(20) NOT NULL DEFAULT 'ACTIVE' 
        CHECK (status IN ('ACTIVE', 'INACTIVE', 'SUSPENDED', 'CLOSED')),
    status_reason TEXT,
    
    -- Metadata
    branch_id UUID NOT NULL REFERENCES core.branches(id),
    relationship_manager_id UUID REFERENCES auth.users(id),
    referral_source VARCHAR(100),
    notes TEXT,
    
    -- Audit
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by UUID NOT NULL REFERENCES auth.users(id),
    updated_by UUID REFERENCES auth.users(id),
    version INTEGER NOT NULL DEFAULT 1,
    is_deleted BOOLEAN NOT NULL DEFAULT false,
    deleted_at TIMESTAMPTZ,
    deleted_by UUID REFERENCES auth.users(id),
    
    -- Constraints
    CONSTRAINT chk_individual_fields CHECK (
        client_type <> 'INDIVIDUAL' OR (
            first_name IS NOT NULL AND 
            last_name IS NOT NULL AND
            date_of_birth IS NOT NULL
        )
    ),
    CONSTRAINT chk_business_fields CHECK (
        client_type <> 'BUSINESS' OR (
            business_name IS NOT NULL AND
            registration_number IS NOT NULL
        )
    )
);
```

## Account Management

### accounts
Core account information.

```sql
CREATE TABLE core.accounts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    account_number VARCHAR(30) GENERATED ALWAYS AS (
        'AC' || to_char(created_at, 'YYMM') || lpad(id::text, 10, '0')
    ) STORED,
    client_id UUID NOT NULL REFERENCES core.clients(id) ON DELETE CASCADE,
    account_type_id UUID NOT NULL REFERENCES core.account_types(id),
    branch_id UUID NOT NULL REFERENCES core.branches(id),
    currency_code CHAR(3) NOT NULL REFERENCES config.currencies(code),
    account_name VARCHAR(255) NOT NULL,
    nickname VARCHAR(100),
    
    -- Balance information
    available_balance DECIMAL(20, 4) NOT NULL DEFAULT 0,
    current_balance DECIMAL(20, 4) NOT NULL DEFAULT 0,
    hold_balance DECIMAL(20, 4) NOT NULL DEFAULT 0,
    uncleared_balance DECIMAL(20, 4) NOT NULL DEFAULT 0,
    
    -- Status
    status VARCHAR(20) NOT NULL DEFAULT 'ACTIVE' 
        CHECK (status IN ('PENDING', 'ACTIVE', 'DORMANT', 'RESTRICTED', 'BLOCKED', 'CLOSED')),
    status_reason TEXT,
    status_updated_at TIMESTAMPTZ,
    status_updated_by UUID REFERENCES auth.users(id),
    
    -- Dates
    opened_date DATE NOT NULL DEFAULT CURRENT_DATE,
    last_activity_date DATE,
    closed_date DATE,
    
    -- Audit
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by UUID NOT NULL REFERENCES auth.users(id),
    updated_by UUID REFERENCES auth.users(id),
    version INTEGER NOT NULL DEFAULT 1,
    is_deleted BOOLEAN NOT NULL DEFAULT false,
    deleted_at TIMESTAMPTZ,
    deleted_by UUID REFERENCES auth.users(id)
);
```

## Transaction Management

### transactions
Core transaction information.

```sql
CREATE TYPE core.TRANSACTION_STATUS AS ENUM (
    'PENDING', 'COMPLETED', 'FAILED', 'CANCELLED', 'REVERSED', 'HOLD'
);

CREATE TYPE core.TRANSACTION_DIRECTION AS ENUM ('CREDIT', 'DEBIT');

CREATE TABLE core.transactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    transaction_reference VARCHAR(50) NOT NULL,
    transaction_type_id UUID NOT NULL REFERENCES core.transaction_types(id),
    status TRANSACTION_STATUS NOT NULL DEFAULT 'PENDING',
    
    -- Amount Information
    amount DECIMAL(20, 4) NOT NULL,
    currency_code CHAR(3) NOT NULL REFERENCES config.currencies(code),
    exchange_rate NUMERIC(20, 10) DEFAULT 1,
    fee_amount DECIMAL(20, 4) DEFAULT 0,
    tax_amount DECIMAL(20, 4) DEFAULT 0,
    net_amount DECIMAL(20, 4) NOT NULL,
    
    -- Dates
    transaction_date TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    value_date DATE,
    posted_date TIMESTAMPTZ,
    
    -- References
    from_account_id UUID REFERENCES core.accounts(id),
    to_account_id UUID REFERENCES core.accounts(id),
    client_id UUID REFERENCES core.clients(id),
    branch_id UUID REFERENCES core.branches(id),
    teller_id UUID REFERENCES auth.users(id),
    
    -- Metadata
    description TEXT,
    reference TEXT,
    notes TEXT,
    metadata JSONB,
    
    -- Audit
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by UUID NOT NULL REFERENCES auth.users(id),
    updated_by UUID REFERENCES auth.users(id),
    version INTEGER NOT NULL DEFAULT 1
) PARTITION BY RANGE (transaction_date);
```

## Compliance & Security

### kyc_verifications
Tracks KYC verification status for clients.

```sql
CREATE TABLE compliance.kyc_verifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    client_id UUID NOT NULL REFERENCES core.clients(id) ON DELETE CASCADE,
    verification_type VARCHAR(50) NOT NULL,
    verification_status VARCHAR(20) NOT NULL 
        CHECK (verification_status IN ('PENDING', 'APPROVED', 'REJECTED', 'EXPIRED')),
    verified_at TIMESTAMPTZ,
    verified_by UUID REFERENCES auth.users(id),
    expiration_date TIMESTAMPTZ,
    rejection_reason TEXT,
    document_references JSONB,
    
    -- Audit
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by UUID NOT NULL REFERENCES auth.users(id),
    updated_by UUID REFERENCES auth.users(id),
    version INTEGER NOT NULL DEFAULT 1
);
```

## System Configuration

### currencies
Defines supported currencies.

```sql
CREATE TABLE config.currencies (
    code CHAR(3) PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    symbol VARCHAR(10) NOT NULL,
    decimal_places INTEGER NOT NULL DEFAULT 2,
    is_active BOOLEAN NOT NULL DEFAULT true,
    is_base_currency BOOLEAN NOT NULL DEFAULT false,
    is_fiat BOOLEAN NOT NULL DEFAULT true,
    is_crypto BOOLEAN GENERATED ALWAYS AS (NOT is_fiat) STORED,
    format_pattern VARCHAR(50) NOT NULL DEFAULT '#,##0.00',
    
    -- Metadata
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by UUID NOT NULL REFERENCES auth.users(id),
    updated_by UUID REFERENCES auth.users(id),
    version INTEGER NOT NULL DEFAULT 1,
    
    -- Constraints
    CONSTRAINT chk_decimal_places CHECK (decimal_places BETWEEN 0 AND 8)
);
```

## Indexes

### Core Indexes
```sql
-- Clients
CREATE INDEX idx_clients_client_number ON core.clients(client_number);
CREATE INDEX idx_clients_phone_number ON core.clients(phone_number);
CREATE INDEX idx_clients_email ON core.clients(email) WHERE email IS NOT NULL;
CREATE INDEX idx_clients_kyc_status ON core.clients(kyc_status);

-- Accounts
CREATE INDEX idx_accounts_client_id ON core.accounts(client_id);
CREATE INDEX idx_accounts_status ON core.accounts(status);
CREATE INDEX idx_accounts_created_at ON core.accounts(created_at);

-- Transactions
CREATE INDEX idx_transactions_reference ON core.transactions(transaction_reference);
CREATE INDEX idx_transactions_date ON core.transactions(transaction_date);
CREATE INDEX idx_transactions_status ON core.transactions(status);
CREATE INDEX idx_transactions_client_id ON core.transactions(client_id);
CREATE INDEX idx_transactions_from_account_id ON core.transactions(from_account_id);
CREATE INDEX idx_transactions_to_account_id ON core.transactions(to_account_id);
```

## Partitioning Strategy

### Transaction Tables
Key transaction tables are partitioned by date for better performance and manageability:

```sql
-- Monthly partitioning for transactions
CREATE TABLE core.transactions_y2023m07 
    PARTITION OF core.transactions
    FOR VALUES FROM ('2023-07-01') TO ('2023-08-01');

-- Monthly partitioning for transaction_ledger
CREATE TABLE core.transaction_ledger_y2023m07 
    PARTITION OF core.transaction_ledger
    FOR VALUES FROM ('2023-07-01') TO ('2023-08-01');
```

## Security

### Row-Level Security (RLS)
Row-level security policies are implemented to ensure data isolation:

```sql
-- Enable RLS on sensitive tables
ALTER TABLE core.clients ENABLE ROW LEVEL SECURITY;
ALTER TABLE core.accounts ENABLE ROW LEVEL SECURITY;
ALTER TABLE core.transactions ENABLE ROW LEVEL SECURITY;

-- Example policy for branch isolation
CREATE POLICY branch_isolation_policy ON core.clients
    USING (branch_id = current_setting('app.current_branch_id')::UUID);
```

## Next Steps

1. Review and refine the schema based on specific business requirements
2. Implement database migrations
3. Set up initial data population
4. Configure backup and recovery procedures
5. Implement monitoring and alerting

## Document History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2025-06-20 | Cascade | Initial version |
