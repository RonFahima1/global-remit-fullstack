# Aspect 1: Core Database Schema Design - Complete Analysis

## Executive Summary

After thoroughly analyzing the existing codebase, business requirements, and current implementation, I've identified critical gaps and opportunities for optimization in the core database schema. This analysis provides a complete understanding before any implementation begins.

## Current State Analysis

### Existing Schema Strengths
1. **Proper Schema Separation**: `auth.*`, `core.*`, `compliance.*`, `config.*` schemas are well-organized
2. **UUID Primary Keys**: Consistent use of UUIDs for security and scalability
3. **Audit Trail**: Basic audit fields (created_at, updated_at, created_by, version)
4. **Foreign Key Relationships**: Proper referential integrity
5. **JSONB Support**: Flexible metadata storage

### Critical Issues Identified

#### 1. **Inconsistent Data Types & Constraints**
```sql
-- Current: Inconsistent currency handling
currency_code CHAR(3) -- In some tables
currency VARCHAR(10)   -- In others
currency_id UUID       -- In domain models

-- Current: Missing critical constraints
-- No CHECK constraints for business rules
-- No validation for phone formats
-- No age verification constraints
```

#### 2. **Missing Business Logic Enforcement**
```sql
-- Current: No database-level business rules
-- Should have: Client age verification
-- Should have: Transaction amount validation
-- Should have: Account balance constraints
-- Should have: KYC status progression rules
```

#### 3. **Incomplete Relationship Modeling**
```sql
-- Current: Missing account-holder relationships
-- Current: No transaction participant modeling
-- Current: Incomplete audit trail
-- Current: Missing compliance tracking
```

#### 4. **Performance Issues**
```sql
-- Current: Missing critical indexes
-- Current: No partitioning strategy
-- Current: Inefficient search patterns
-- Current: No caching considerations
```

## Business Requirements Deep Dive

### 1. **Client Management Requirements**

#### Core Client Data
```typescript
interface ClientRequirements {
  // Identity Management
  clientNumber: string;        // Auto-generated: CL + YYMM + 8-digit ID
  clientType: 'INDIVIDUAL' | 'BUSINESS' | 'ORGANIZATION';
  status: 'PENDING' | 'ACTIVE' | 'SUSPENDED' | 'CLOSED' | 'DECEASED';
  
  // Personal Information (Individual)
  firstName: string;           // Required for individuals
  lastName: string;            // Required for individuals
  middleName?: string;         // Optional
  dateOfBirth: Date;           // Required, must be 18+
  gender: 'MALE' | 'FEMALE' | 'OTHER' | 'UNSPECIFIED';
  maritalStatus?: string;
  
  // Business Information (Business)
  businessName?: string;       // Required for businesses
  registrationNumber?: string; // Required for businesses
  taxIdentificationNumber?: string;
  
  // Contact Information
  email?: string;              // Optional but validated if provided
  emailVerified: boolean;      // Default: false
  phone: string;               // Required, international format
  phoneVerified: boolean;      // Default: false
  
  // Address Information
  residentialAddress?: Address;
  mailingAddress?: Address;
  
  // Employment Information
  occupation?: string;
  employerName?: string;
  employmentStatus?: string;
  annualIncome?: number;       // For risk assessment
  
  // KYC & Compliance
  kycStatus: 'NOT_VERIFIED' | 'PENDING' | 'VERIFIED' | 'REJECTED' | 'EXPIRED';
  kycVerifiedAt?: Date;
  kycVerifiedBy?: string;     // User ID
  riskLevel: 'LOW' | 'MEDIUM' | 'HIGH' | 'CRITICAL';
  
  // Business Relationships
  branchId: string;            // Required
  relationshipManagerId?: string;
  referralSource?: string;
  
  // Audit & Compliance
  notes?: string;
  tags?: string[];
  metadata?: Record<string, any>;
}
```

#### Business Rules for Clients
```sql
-- Age Verification (18+ required)
CONSTRAINT chk_client_age CHECK (
  client_type <> 'INDIVIDUAL' OR 
  (date_of_birth IS NOT NULL AND 
   date_of_birth <= CURRENT_DATE - INTERVAL '18 years')
);

-- Required Fields by Client Type
CONSTRAINT chk_individual_fields CHECK (
  client_type <> 'INDIVIDUAL' OR (
    first_name IS NOT NULL AND 
    last_name IS NOT NULL AND
    date_of_birth IS NOT NULL AND
    phone IS NOT NULL
  )
);

CONSTRAINT chk_business_fields CHECK (
  client_type <> 'BUSINESS' OR (
    business_name IS NOT NULL AND
    registration_number IS NOT NULL AND
    phone IS NOT NULL
  )
);

-- Phone Number Format Validation
CONSTRAINT chk_phone_format CHECK (
  phone ~* '^\+?[1-9]\d{1,14}$'
);

-- Email Format Validation (if provided)
CONSTRAINT chk_email_format CHECK (
  email IS NULL OR 
  email ~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$'
);

-- KYC Status Progression Rules
CONSTRAINT chk_kyc_status_progression CHECK (
  (kyc_status = 'NOT_VERIFIED' AND kyc_verified_at IS NULL) OR
  (kyc_status = 'PENDING' AND kyc_verified_at IS NULL) OR
  (kyc_status IN ('VERIFIED', 'REJECTED') AND kyc_verified_at IS NOT NULL AND kyc_verified_by IS NOT NULL) OR
  (kyc_status = 'EXPIRED' AND kyc_verified_at IS NOT NULL)
);
```

### 2. **Account Management Requirements**

#### Core Account Data
```typescript
interface AccountRequirements {
  // Account Identity
  accountNumber: string;       // Auto-generated: AC + YYMM + 10-digit ID
  accountName: string;         // Required
  accountTypeId: string;       // Reference to account_types
  currencyCode: string;        // ISO 4217 (USD, EUR, ILS, etc.)
  
  // Balance Management
  currentBalance: number;      // Total balance including holds
  availableBalance: number;    // Available for transactions
  holdBalance: number;         // Amount on hold
  unclearedBalance: number;    // Pending transactions
  
  // Account Status
  status: 'PENDING' | 'ACTIVE' | 'DORMANT' | 'RESTRICTED' | 'BLOCKED' | 'CLOSED';
  statusReason?: string;
  statusUpdatedAt?: Date;
  statusUpdatedBy?: string;
  
  // Dates
  openedDate: Date;            // Required
  lastActivityDate?: Date;
  closedDate?: Date;
  
  // Account Holders
  holders: AccountHolder[];    // Multiple holders possible
  
  // Features & Limits
  features: AccountFeatures;
  limits: AccountLimits;
  
  // Audit
  metadata?: Record<string, any>;
}
```

#### Business Rules for Accounts
```sql
-- Balance Constraints
CONSTRAINT chk_balance_non_negative CHECK (current_balance >= 0);
CONSTRAINT chk_available_balance CHECK (available_balance <= current_balance);
CONSTRAINT chk_hold_balance CHECK (hold_balance <= current_balance);
CONSTRAINT chk_uncleared_balance CHECK (uncleared_balance >= 0);

-- Date Constraints
CONSTRAINT chk_account_dates CHECK (
  (closed_date IS NULL) OR 
  (closed_date IS NOT NULL AND closed_date >= opened_date)
);

CONSTRAINT chk_last_activity CHECK (
  (last_activity_date IS NULL) OR 
  (last_activity_date >= opened_date)
);

-- Status Constraints
CONSTRAINT chk_account_status CHECK (
  status IN ('PENDING', 'ACTIVE', 'DORMANT', 'RESTRICTED', 'BLOCKED', 'CLOSED')
);

-- Currency Validation
CONSTRAINT chk_currency_code CHECK (
  currency_code ~* '^[A-Z]{3}$'
);
```

### 3. **Transaction Management Requirements**

#### Core Transaction Data
```typescript
interface TransactionRequirements {
  // Transaction Identity
  transactionReference: string; // Unique reference
  transactionTypeId: string;    // Reference to transaction_types
  status: 'PENDING' | 'COMPLETED' | 'FAILED' | 'CANCELLED' | 'REVERSED' | 'HOLD';
  
  // Amount Information
  amount: number;               // Transaction amount
  currencyCode: string;         // Transaction currency
  exchangeRate: number;         // Exchange rate if applicable
  feeAmount: number;            // Transaction fee
  taxAmount: number;            // Tax amount
  netAmount: number;            // Net amount after fees/taxes
  
  // Dates
  transactionDate: Date;        // When transaction occurred
  valueDate?: Date;             // Value date for settlement
  postedDate?: Date;            // When posted to accounts
  
  // Participants
  fromAccountId?: string;       // Source account
  toAccountId?: string;         // Destination account
  clientId?: string;            // Primary client
  branchId?: string;            // Branch where processed
  tellerId?: string;            // Teller who processed
  
  // Complex Transactions
  parentTransactionId?: string; // For multi-step transactions
  relatedTransactionId?: string; // For related transactions
  
  // Metadata
  description?: string;
  reference?: string;
  notes?: string;
  metadata?: Record<string, any>;
  
  // Compliance
  complianceChecks: ComplianceCheck[];
  riskScore?: number;
  riskLevel?: 'LOW' | 'MEDIUM' | 'HIGH' | 'CRITICAL';
}
```

#### Business Rules for Transactions
```sql
-- Amount Validation
CONSTRAINT chk_transaction_amount CHECK (amount > 0);
CONSTRAINT chk_net_amount CHECK (net_amount > 0);
CONSTRAINT chk_fee_amount CHECK (fee_amount >= 0);
CONSTRAINT chk_tax_amount CHECK (tax_amount >= 0);

-- Exchange Rate Validation
CONSTRAINT chk_exchange_rate CHECK (
  (exchange_rate IS NULL) OR 
  (exchange_rate > 0 AND exchange_rate <= 1000000)
);

-- Status Validation
CONSTRAINT chk_transaction_status CHECK (
  status IN ('PENDING', 'COMPLETED', 'FAILED', 'CANCELLED', 'REVERSED', 'HOLD')
);

-- Date Validation
CONSTRAINT chk_transaction_dates CHECK (
  transaction_date <= CURRENT_TIMESTAMP AND
  (value_date IS NULL OR value_date >= transaction_date::date) AND
  (posted_date IS NULL OR posted_date >= transaction_date)
);

-- Account Validation
CONSTRAINT chk_transaction_accounts CHECK (
  (from_account_id IS NOT NULL AND to_account_id IS NOT NULL AND from_account_id != to_account_id) OR
  (from_account_id IS NOT NULL AND to_account_id IS NULL) OR
  (from_account_id IS NULL AND to_account_id IS NOT NULL)
);
```

## Optimized Schema Design

### 1. **Enhanced Client Schema**

```sql
-- Core client table with comprehensive business rules
CREATE TABLE core.clients (
    -- Core Identity
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    client_number VARCHAR(20) UNIQUE NOT NULL,
    client_type VARCHAR(20) NOT NULL CHECK (client_type IN ('INDIVIDUAL', 'BUSINESS', 'ORGANIZATION')),
    status VARCHAR(20) NOT NULL DEFAULT 'PENDING' 
        CHECK (status IN ('PENDING', 'ACTIVE', 'SUSPENDED', 'CLOSED', 'DECEASED')),
    
    -- Personal Information (Individual)
    title VARCHAR(10),
    first_name VARCHAR(100),
    middle_name VARCHAR(100),
    last_name VARCHAR(100),
    date_of_birth DATE,
    gender VARCHAR(10) CHECK (gender IN ('MALE', 'FEMALE', 'OTHER', 'UNSPECIFIED')),
    marital_status VARCHAR(20),
    
    -- Business Information (Business)
    business_name VARCHAR(255),
    registration_number VARCHAR(50),
    tax_identification_number VARCHAR(50),
    
    -- Contact Information
    email VARCHAR(255),
    email_verified BOOLEAN NOT NULL DEFAULT false,
    phone VARCHAR(20) NOT NULL,
    phone_verified BOOLEAN NOT NULL DEFAULT false,
    
    -- Address Information (JSONB for flexibility)
    addresses JSONB DEFAULT '[]'::jsonb,
    
    -- Employment Information
    occupation VARCHAR(100),
    employer_name VARCHAR(200),
    employment_status VARCHAR(50),
    annual_income DECIMAL(15, 2),
    
    -- KYC & Compliance
    kyc_status VARCHAR(20) NOT NULL DEFAULT 'NOT_VERIFIED'
        CHECK (kyc_status IN ('NOT_VERIFIED', 'PENDING', 'VERIFIED', 'REJECTED', 'EXPIRED')),
    kyc_verified_at TIMESTAMPTZ,
    kyc_verified_by UUID REFERENCES auth.users(id),
    risk_level VARCHAR(20) NOT NULL DEFAULT 'LOW'
        CHECK (risk_level IN ('LOW', 'MEDIUM', 'HIGH', 'CRITICAL')),
    
    -- Business Relationships
    branch_id UUID NOT NULL REFERENCES core.branches(id),
    relationship_manager_id UUID REFERENCES auth.users(id),
    referral_source VARCHAR(100),
    
    -- Additional Information
    notes TEXT,
    tags TEXT[],
    metadata JSONB DEFAULT '{}'::jsonb,
    
    -- System Fields
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at TIMESTAMPTZ,
    created_by UUID NOT NULL REFERENCES auth.users(id),
    updated_by UUID REFERENCES auth.users(id),
    version INTEGER NOT NULL DEFAULT 1,
    
    -- Business Rule Constraints
    CONSTRAINT chk_client_age CHECK (
        client_type <> 'INDIVIDUAL' OR 
        (date_of_birth IS NOT NULL AND 
         date_of_birth <= CURRENT_DATE - INTERVAL '18 years')
    ),
    CONSTRAINT chk_individual_fields CHECK (
        client_type <> 'INDIVIDUAL' OR (
            first_name IS NOT NULL AND 
            last_name IS NOT NULL AND
            date_of_birth IS NOT NULL AND
            phone IS NOT NULL
        )
    ),
    CONSTRAINT chk_business_fields CHECK (
        client_type <> 'BUSINESS' OR (
            business_name IS NOT NULL AND
            registration_number IS NOT NULL AND
            phone IS NOT NULL
        )
    ),
    CONSTRAINT chk_phone_format CHECK (
        phone ~* '^\+?[1-9]\d{1,14}$'
    ),
    CONSTRAINT chk_email_format CHECK (
        email IS NULL OR 
        email ~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$'
    ),
    CONSTRAINT chk_kyc_status_progression CHECK (
        (kyc_status = 'NOT_VERIFIED' AND kyc_verified_at IS NULL) OR
        (kyc_status = 'PENDING' AND kyc_verified_at IS NULL) OR
        (kyc_status IN ('VERIFIED', 'REJECTED') AND kyc_verified_at IS NOT NULL AND kyc_verified_by IS NOT NULL) OR
        (kyc_status = 'EXPIRED' AND kyc_verified_at IS NOT NULL)
    ),
    CONSTRAINT chk_annual_income CHECK (
        annual_income IS NULL OR annual_income >= 0
    )
);

-- Indexes for Performance
CREATE INDEX idx_clients_client_number ON core.clients(client_number);
CREATE INDEX idx_clients_phone ON core.clients(phone) WHERE phone IS NOT NULL;
CREATE INDEX idx_clients_email ON core.clients(email) WHERE email IS NOT NULL;
CREATE INDEX idx_clients_status ON core.clients(status);
CREATE INDEX idx_clients_kyc_status ON core.clients(kyc_status);
CREATE INDEX idx_clients_risk_level ON core.clients(risk_level);
CREATE INDEX idx_clients_branch ON core.clients(branch_id);
CREATE INDEX idx_clients_created_at ON core.clients(created_at);
CREATE INDEX idx_clients_type_status ON core.clients(client_type, status);
CREATE INDEX idx_clients_phone_lower ON core.clients(LOWER(phone));
CREATE INDEX idx_clients_email_lower ON core.clients(LOWER(email)) WHERE email IS NOT NULL;

-- Full-text search index
CREATE INDEX idx_clients_search ON core.clients 
    USING gin(to_tsvector('english', 
        COALESCE(first_name, '') || ' ' || 
        COALESCE(last_name, '') || ' ' || 
        COALESCE(business_name, '') || ' ' || 
        COALESCE(phone, '')
    ));
```

### 2. **Enhanced Account Schema**

```sql
-- Account types with features and restrictions
CREATE TABLE core.account_types (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    type_code VARCHAR(20) UNIQUE NOT NULL,
    name VARCHAR(100) NOT NULL,
    description TEXT,
    
    -- Account Features
    features JSONB NOT NULL DEFAULT '{}'::jsonb,
    restrictions JSONB NOT NULL DEFAULT '{}'::jsonb,
    
    -- Status
    is_active BOOLEAN NOT NULL DEFAULT true,
    
    -- System
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by UUID NOT NULL REFERENCES auth.users(id),
    updated_by UUID REFERENCES auth.users(id),
    version INTEGER NOT NULL DEFAULT 1
);

-- Core accounts table
CREATE TABLE core.accounts (
    -- Core Identity
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    account_number VARCHAR(20) UNIQUE NOT NULL,
    account_name VARCHAR(255) NOT NULL,
    
    -- Account Type
    account_type_id UUID NOT NULL REFERENCES core.account_types(id),
    
    -- Currency
    currency_code CHAR(3) NOT NULL REFERENCES config.currencies(code),
    
    -- Balances
    current_balance DECIMAL(19, 4) NOT NULL DEFAULT 0,
    available_balance DECIMAL(19, 4) NOT NULL DEFAULT 0,
    hold_balance DECIMAL(19, 4) NOT NULL DEFAULT 0,
    uncleared_balance DECIMAL(19, 4) NOT NULL DEFAULT 0,
    
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
    
    -- Features & Limits
    features JSONB DEFAULT '{}'::jsonb,
    limits JSONB DEFAULT '{}'::jsonb,
    
    -- Metadata
    metadata JSONB DEFAULT '{}'::jsonb,
    
    -- System
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by UUID NOT NULL REFERENCES auth.users(id),
    updated_by UUID REFERENCES auth.users(id),
    version INTEGER NOT NULL DEFAULT 1,
    
    -- Business Rule Constraints
    CONSTRAINT chk_balance_non_negative CHECK (current_balance >= 0),
    CONSTRAINT chk_available_balance CHECK (available_balance <= current_balance),
    CONSTRAINT chk_hold_balance CHECK (hold_balance <= current_balance),
    CONSTRAINT chk_uncleared_balance CHECK (uncleared_balance >= 0),
    CONSTRAINT chk_account_dates CHECK (
        (closed_date IS NULL) OR 
        (closed_date IS NOT NULL AND closed_date >= opened_date)
    ),
    CONSTRAINT chk_last_activity CHECK (
        (last_activity_date IS NULL) OR 
        (last_activity_date >= opened_date)
    )
);

-- Account holders (many-to-many relationship)
CREATE TABLE core.account_holders (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    account_id UUID NOT NULL REFERENCES core.accounts(id) ON DELETE CASCADE,
    client_id UUID NOT NULL REFERENCES core.clients(id) ON DELETE CASCADE,
    
    -- Holder Information
    holder_type VARCHAR(20) NOT NULL DEFAULT 'PRIMARY' 
        CHECK (holder_type IN ('PRIMARY', 'JOINT', 'AUTHORIZED', 'BENEFICIARY', 'POWER_OF_ATTORNEY')),
    
    -- Dates
    added_date DATE NOT NULL DEFAULT CURRENT_DATE,
    removed_date DATE,
    
    -- Permissions
    permissions JSONB NOT NULL DEFAULT '{"view": true, "transact": true, "manage": false}'::jsonb,
    
    -- System
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by UUID NOT NULL REFERENCES auth.users(id),
    updated_by UUID REFERENCES auth.users(id),
    version INTEGER NOT NULL DEFAULT 1,
    
    -- Constraints
    CONSTRAINT chk_removal_date CHECK (
        (removed_date IS NULL) OR 
        (removed_date IS NOT NULL AND removed_date >= added_date)
    ),
    CONSTRAINT uq_account_holder UNIQUE (account_id, client_id, holder_type)
);

-- Indexes
CREATE INDEX idx_accounts_number ON core.accounts(account_number);
CREATE INDEX idx_accounts_type ON core.accounts(account_type_id);
CREATE INDEX idx_accounts_currency ON core.accounts(currency_code);
CREATE INDEX idx_accounts_status ON core.accounts(status);
CREATE INDEX idx_accounts_balance ON core.accounts(current_balance);
CREATE INDEX idx_accounts_opened_date ON core.accounts(opened_date);
CREATE INDEX idx_accounts_activity ON core.accounts(last_activity_date) WHERE last_activity_date IS NOT NULL;

CREATE INDEX idx_account_holders_account ON core.account_holders(account_id);
CREATE INDEX idx_account_holders_client ON core.account_holders(client_id);
CREATE INDEX idx_account_holders_type ON core.account_holders(holder_type);
CREATE INDEX idx_account_holders_active ON core.account_holders(account_id, client_id) 
    WHERE removed_date IS NULL;
```

### 3. **Enhanced Transaction Schema**

```sql
-- Transaction types with business rules
CREATE TABLE core.transaction_types (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code VARCHAR(50) UNIQUE NOT NULL,
    name VARCHAR(100) NOT NULL,
    description TEXT,
    
    -- Transaction Properties
    direction VARCHAR(10) NOT NULL CHECK (direction IN ('CREDIT', 'DEBIT', 'BOTH')),
    affects_balance BOOLEAN NOT NULL DEFAULT true,
    requires_approval BOOLEAN NOT NULL DEFAULT false,
    approval_threshold DECIMAL(20, 4),
    
    -- Business Rules
    business_rules JSONB DEFAULT '{}'::jsonb,
    
    -- Status
    is_active BOOLEAN NOT NULL DEFAULT true,
    
    -- System
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by UUID NOT NULL REFERENCES auth.users(id),
    updated_by UUID REFERENCES auth.users(id),
    version INTEGER NOT NULL DEFAULT 1
);

-- Core transactions table
CREATE TABLE core.transactions (
    -- Core Identity
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    transaction_reference VARCHAR(50) UNIQUE NOT NULL,
    transaction_type_id UUID NOT NULL REFERENCES core.transaction_types(id),
    status VARCHAR(20) NOT NULL DEFAULT 'PENDING'
        CHECK (status IN ('PENDING', 'COMPLETED', 'FAILED', 'CANCELLED', 'REVERSED', 'HOLD')),
    
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
    
    -- Participants
    from_account_id UUID REFERENCES core.accounts(id),
    to_account_id UUID REFERENCES core.accounts(id),
    client_id UUID REFERENCES core.clients(id),
    branch_id UUID REFERENCES core.branches(id),
    teller_id UUID REFERENCES auth.users(id),
    
    -- Complex Transactions
    parent_transaction_id UUID REFERENCES core.transactions(id),
    related_transaction_id UUID REFERENCES core.transactions(id),
    
    -- Compliance
    risk_score INTEGER,
    risk_level VARCHAR(20) CHECK (risk_level IN ('LOW', 'MEDIUM', 'HIGH', 'CRITICAL')),
    compliance_status VARCHAR(20) DEFAULT 'PENDING'
        CHECK (compliance_status IN ('PENDING', 'APPROVED', 'REJECTED', 'MANUAL_REVIEW')),
    
    -- Metadata
    description TEXT,
    reference TEXT,
    notes TEXT,
    metadata JSONB DEFAULT '{}'::jsonb,
    
    -- System
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by UUID NOT NULL REFERENCES auth.users(id),
    updated_by UUID REFERENCES auth.users(id),
    version INTEGER NOT NULL DEFAULT 1,
    
    -- Business Rule Constraints
    CONSTRAINT chk_transaction_amount CHECK (amount > 0),
    CONSTRAINT chk_net_amount CHECK (net_amount > 0),
    CONSTRAINT chk_fee_amount CHECK (fee_amount >= 0),
    CONSTRAINT chk_tax_amount CHECK (tax_amount >= 0),
    CONSTRAINT chk_exchange_rate CHECK (
        (exchange_rate IS NULL) OR 
        (exchange_rate > 0 AND exchange_rate <= 1000000)
    ),
    CONSTRAINT chk_transaction_dates CHECK (
        transaction_date <= CURRENT_TIMESTAMP AND
        (value_date IS NULL OR value_date >= transaction_date::date) AND
        (posted_date IS NULL OR posted_date >= transaction_date)
    ),
    CONSTRAINT chk_transaction_accounts CHECK (
        (from_account_id IS NOT NULL AND to_account_id IS NOT NULL AND from_account_id != to_account_id) OR
        (from_account_id IS NOT NULL AND to_account_id IS NULL) OR
        (from_account_id IS NULL AND to_account_id IS NOT NULL)
    ),
    CONSTRAINT chk_risk_score CHECK (
        risk_score IS NULL OR (risk_score >= 0 AND risk_score <= 100)
    )
);

-- Transaction participants (for complex transactions)
CREATE TABLE core.transaction_participants (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    transaction_id UUID NOT NULL REFERENCES core.transactions(id) ON DELETE CASCADE,
    account_id UUID REFERENCES core.accounts(id),
    participant_type VARCHAR(20) NOT NULL
        CHECK (participant_type IN ('SENDER', 'RECEIVER', 'BENEFICIARY', 'INTERMEDIARY')),
    
    -- Amount Information
    amount DECIMAL(20, 4) NOT NULL,
    currency_code CHAR(3) NOT NULL REFERENCES config.currencies(code),
    exchange_rate NUMERIC(20, 10) DEFAULT 1,
    
    -- References
    client_id UUID REFERENCES core.clients(id),
    receiver_id UUID REFERENCES core.receivers(id),
    
    -- Additional Information
    description TEXT,
    metadata JSONB DEFAULT '{}'::jsonb,
    
    -- System
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by UUID NOT NULL REFERENCES auth.users(id),
    updated_by UUID REFERENCES auth.users(id),
    version INTEGER NOT NULL DEFAULT 1,
    
    -- Constraints
    CONSTRAINT chk_participant_amount CHECK (amount != 0)
);

-- Indexes
CREATE INDEX idx_transactions_reference ON core.transactions(transaction_reference);
CREATE INDEX idx_transactions_date ON core.transactions(transaction_date);
CREATE INDEX idx_transactions_type ON core.transactions(transaction_type_id);
CREATE INDEX idx_transactions_status ON core.transactions(status);
CREATE INDEX idx_transactions_compliance ON core.transactions(compliance_status);
CREATE INDEX idx_transactions_risk ON core.transactions(risk_level) WHERE risk_level IS NOT NULL;
CREATE INDEX idx_transactions_from_account ON core.transactions(from_account_id) WHERE from_account_id IS NOT NULL;
CREATE INDEX idx_transactions_to_account ON core.transactions(to_account_id) WHERE to_account_id IS NOT NULL;
CREATE INDEX idx_transactions_client ON core.transactions(client_id) WHERE client_id IS NOT NULL;
CREATE INDEX idx_transactions_teller ON core.transactions(teller_id) WHERE teller_id IS NOT NULL;
CREATE INDEX idx_transactions_branch ON core.transactions(branch_id) WHERE branch_id IS NOT NULL;
CREATE INDEX idx_transactions_parent ON core.transactions(parent_transaction_id) WHERE parent_transaction_id IS NOT NULL;
CREATE INDEX idx_transactions_related ON core.transactions(related_transaction_id) WHERE related_transaction_id IS NOT NULL;
CREATE INDEX idx_transactions_created_by ON core.transactions(created_by);
CREATE INDEX idx_transactions_amount ON core.transactions(amount);
CREATE INDEX idx_transactions_currency ON core.transactions(currency_code);

-- Composite indexes for common queries
CREATE INDEX idx_transactions_account_status ON core.transactions(from_account_id, status) WHERE from_account_id IS NOT NULL;
CREATE INDEX idx_transactions_client_date ON core.transactions(client_id, transaction_date) WHERE client_id IS NOT NULL;
CREATE INDEX idx_transactions_branch_date ON core.transactions(branch_id, transaction_date) WHERE branch_id IS NOT NULL;
CREATE INDEX idx_transactions_type_status ON core.transactions(transaction_type_id, status);

CREATE INDEX idx_participants_transaction ON core.transaction_participants(transaction_id);
CREATE INDEX idx_participants_account ON core.transaction_participants(account_id) WHERE account_id IS NOT NULL;
CREATE INDEX idx_participants_client ON core.transaction_participants(client_id) WHERE client_id IS NOT NULL;
CREATE INDEX idx_participants_type ON core.transaction_participants(participant_type);
```

## Performance Optimization Strategy

### 1. **Partitioning Strategy**
```sql
-- Partition transactions by date for better performance
CREATE TABLE core.transactions_2024 PARTITION OF core.transactions
FOR VALUES FROM ('2024-01-01') TO ('2025-01-01');

CREATE TABLE core.transactions_2025 PARTITION OF core.transactions
FOR VALUES FROM ('2025-01-01') TO ('2026-01-01');

-- Partition audit logs by date
CREATE TABLE compliance.audit_logs_2024 PARTITION OF compliance.audit_logs
FOR VALUES FROM ('2024-01-01') TO ('2025-01-01');
```

### 2. **Materialized Views for Analytics**
```sql
-- Daily transaction summary
CREATE MATERIALIZED VIEW core.daily_transaction_summary AS
SELECT 
    DATE(transaction_date) as date,
    transaction_type_id,
    currency_code,
    COUNT(*) as transaction_count,
    SUM(amount) as total_amount,
    SUM(fee_amount) as total_fees,
    AVG(amount) as avg_amount
FROM core.transactions
WHERE status = 'COMPLETED'
GROUP BY DATE(transaction_date), transaction_type_id, currency_code;

-- Client activity summary
CREATE MATERIALIZED VIEW core.client_activity_summary AS
SELECT 
    client_id,
    COUNT(*) as total_transactions,
    SUM(CASE WHEN status = 'COMPLETED' THEN 1 ELSE 0 END) as completed_transactions,
    SUM(CASE WHEN status = 'COMPLETED' THEN amount ELSE 0 END) as total_volume,
    MAX(transaction_date) as last_activity
FROM core.transactions
GROUP BY client_id;
```

### 3. **Function-Based Indexes**
```sql
-- Case-insensitive search indexes
CREATE INDEX idx_clients_name_lower ON core.clients(LOWER(first_name || ' ' || last_name));
CREATE INDEX idx_clients_business_name_lower ON core.clients(LOWER(business_name)) WHERE business_name IS NOT NULL;

-- Partial indexes for active records
CREATE INDEX idx_clients_active ON core.clients(id, client_number, phone) WHERE status = 'ACTIVE';
CREATE INDEX idx_accounts_active ON core.accounts(id, account_number, current_balance) WHERE status = 'ACTIVE';
```

## Data Integrity & Constraints

### 1. **Triggers for Business Logic**
```sql
-- Auto-generate client numbers
CREATE OR REPLACE FUNCTION core.generate_client_number()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.client_number IS NULL THEN
        NEW.client_number := 'CL' || 
                            TO_CHAR(CURRENT_DATE, 'YYMM') || 
                            LPAD(NEW.id::text, 8, '0');
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_generate_client_number
    BEFORE INSERT ON core.clients
    FOR EACH ROW
    EXECUTE FUNCTION core.generate_client_number();

-- Auto-generate account numbers
CREATE OR REPLACE FUNCTION core.generate_account_number()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.account_number IS NULL THEN
        NEW.account_number := 'AC' || 
                             TO_CHAR(CURRENT_DATE, 'YYMM') || 
                             LPAD(NEW.id::text, 10, '0');
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_generate_account_number
    BEFORE INSERT ON core.accounts
    FOR EACH ROW
    EXECUTE FUNCTION core.generate_account_number();

-- Auto-generate transaction references
CREATE OR REPLACE FUNCTION core.generate_transaction_reference()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.transaction_reference IS NULL THEN
        NEW.transaction_reference := 'TX' || 
                                    TO_CHAR(CURRENT_TIMESTAMP, 'YYYYMMDDHH24MISS') || 
                                    LPAD(NEW.id::text, 8, '0');
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_generate_transaction_reference
    BEFORE INSERT ON core.transactions
    FOR EACH ROW
    EXECUTE FUNCTION core.generate_transaction_reference();
```

### 2. **Audit Trail Triggers**
```sql
-- Comprehensive audit logging
CREATE OR REPLACE FUNCTION compliance.audit_changes()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        INSERT INTO compliance.audit_logs (
            event_type, table_name, record_id, user_id, action, new_values
        ) VALUES (
            'DATA_CHANGE', TG_TABLE_NAME, NEW.id, NEW.created_by, 'INSERT', to_jsonb(NEW)
        );
        RETURN NEW;
    ELSIF TG_OP = 'UPDATE' THEN
        INSERT INTO compliance.audit_logs (
            event_type, table_name, record_id, user_id, action, old_values, new_values
        ) VALUES (
            'DATA_CHANGE', TG_TABLE_NAME, NEW.id, NEW.updated_by, 'UPDATE', to_jsonb(OLD), to_jsonb(NEW)
        );
        RETURN NEW;
    ELSIF TG_OP = 'DELETE' THEN
        INSERT INTO compliance.audit_logs (
            event_type, table_name, record_id, user_id, action, old_values
        ) VALUES (
            'DATA_CHANGE', TG_TABLE_NAME, OLD.id, OLD.updated_by, 'DELETE', to_jsonb(OLD)
        );
        RETURN OLD;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- Apply audit triggers to all core tables
CREATE TRIGGER audit_clients_changes
    AFTER INSERT OR UPDATE OR DELETE ON core.clients
    FOR EACH ROW EXECUTE FUNCTION compliance.audit_changes();

CREATE TRIGGER audit_accounts_changes
    AFTER INSERT OR UPDATE OR DELETE ON core.accounts
    FOR EACH ROW EXECUTE FUNCTION compliance.audit_changes();

CREATE TRIGGER audit_transactions_changes
    AFTER INSERT OR UPDATE OR DELETE ON core.transactions
    FOR EACH ROW EXECUTE FUNCTION compliance.audit_changes();
```

## Migration Strategy

### Phase 1: Schema Creation
1. Create new optimized schemas
2. Implement all constraints and indexes
3. Create triggers and functions
4. Set up partitioning

### Phase 2: Data Migration
1. Migrate existing data to new schema
2. Validate data integrity
3. Update application code
4. Test thoroughly

### Phase 3: Performance Tuning
1. Monitor query performance
2. Optimize indexes based on usage
3. Implement caching strategies
4. Fine-tune configuration

## Success Criteria

1. **Performance**: All queries execute in < 100ms
2. **Data Integrity**: 100% constraint compliance
3. **Scalability**: Support 1M+ clients, 10M+ transactions
4. **Compliance**: Full audit trail and business rule enforcement
5. **Maintainability**: Clear documentation and standardized patterns

This comprehensive schema design provides a solid foundation for all other aspects of the client management system while ensuring performance, security, and compliance requirements are met. 