# Aspect 1: Core Database Schema Design - 5 Substeps

## Overview
Breaking down the massive database schema design into 5 focused, manageable substeps that build upon each other systematically.

## Substeps Breakdown

### **Substep 1.1: Core Client Schema Foundation**
**Focus**: Essential client data structure with basic business rules
**Duration**: 2-3 days
**Dependencies**: None (foundation)

#### What We'll Build:
```sql
-- Core client table with essential fields only
CREATE TABLE core.clients (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    client_number VARCHAR(20) UNIQUE NOT NULL,
    client_type VARCHAR(20) NOT NULL CHECK (client_type IN ('INDIVIDUAL', 'BUSINESS')),
    status VARCHAR(20) NOT NULL DEFAULT 'PENDING',
    
    -- Essential Personal Info
    first_name VARCHAR(100),
    last_name VARCHAR(100),
    date_of_birth DATE,
    phone VARCHAR(20) NOT NULL,
    email VARCHAR(255),
    
    -- Essential Business Info
    business_name VARCHAR(255),
    registration_number VARCHAR(50),
    
    -- Basic KYC
    kyc_status VARCHAR(20) NOT NULL DEFAULT 'NOT_VERIFIED',
    risk_level VARCHAR(20) NOT NULL DEFAULT 'LOW',
    
    -- System Fields
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by UUID NOT NULL,
    version INTEGER NOT NULL DEFAULT 1
);
```

#### Business Rules to Implement:
- Age verification (18+ for individuals)
- Required fields by client type
- Phone number format validation
- Basic KYC status progression

#### Success Criteria:
- [ ] Client table created with proper constraints
- [ ] Auto-generation of client numbers working
- [ ] Basic validation rules enforced
- [ ] Indexes for common queries created
- [ ] Unit tests passing

---

### **Substep 1.2: Account Management Schema**
**Focus**: Account structure and holder relationships
**Duration**: 2-3 days
**Dependencies**: Substep 1.1 (clients)

#### What We'll Build:
```sql
-- Account types
CREATE TABLE core.account_types (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    type_code VARCHAR(20) UNIQUE NOT NULL,
    name VARCHAR(100) NOT NULL,
    features JSONB DEFAULT '{}'::jsonb,
    is_active BOOLEAN NOT NULL DEFAULT true
);

-- Core accounts
CREATE TABLE core.accounts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    account_number VARCHAR(20) UNIQUE NOT NULL,
    account_name VARCHAR(255) NOT NULL,
    account_type_id UUID NOT NULL REFERENCES core.account_types(id),
    currency_code CHAR(3) NOT NULL,
    
    -- Balance fields
    current_balance DECIMAL(19, 4) NOT NULL DEFAULT 0,
    available_balance DECIMAL(19, 4) NOT NULL DEFAULT 0,
    hold_balance DECIMAL(19, 4) NOT NULL DEFAULT 0,
    
    -- Status
    status VARCHAR(20) NOT NULL DEFAULT 'ACTIVE',
    opened_date DATE NOT NULL DEFAULT CURRENT_DATE,
    
    -- System fields
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by UUID NOT NULL,
    version INTEGER NOT NULL DEFAULT 1
);

-- Account holders
CREATE TABLE core.account_holders (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    account_id UUID NOT NULL REFERENCES core.accounts(id),
    client_id UUID NOT NULL REFERENCES core.clients(id),
    holder_type VARCHAR(20) NOT NULL DEFAULT 'PRIMARY',
    permissions JSONB DEFAULT '{"view": true, "transact": true}'::jsonb
);
```

#### Business Rules to Implement:
- Balance constraints (non-negative, available ≤ current)
- Account number auto-generation
- Holder relationship validation
- Status progression rules

#### Success Criteria:
- [ ] Account tables created with proper relationships
- [ ] Balance constraints working correctly
- [ ] Account holder relationships functional
- [ ] Auto-generation of account numbers working
- [ ] Integration tests with clients passing

---

### **Substep 1.3: Transaction Schema Foundation**
**Focus**: Basic transaction structure and types
**Duration**: 2-3 days
**Dependencies**: Substep 1.2 (accounts)

#### What We'll Build:
```sql
-- Transaction types
CREATE TABLE core.transaction_types (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code VARCHAR(50) UNIQUE NOT NULL,
    name VARCHAR(100) NOT NULL,
    direction VARCHAR(10) NOT NULL CHECK (direction IN ('CREDIT', 'DEBIT', 'BOTH')),
    affects_balance BOOLEAN NOT NULL DEFAULT true,
    is_active BOOLEAN NOT NULL DEFAULT true
);

-- Core transactions
CREATE TABLE core.transactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    transaction_reference VARCHAR(50) UNIQUE NOT NULL,
    transaction_type_id UUID NOT NULL REFERENCES core.transaction_types(id),
    status VARCHAR(20) NOT NULL DEFAULT 'PENDING',
    
    -- Amount information
    amount DECIMAL(20, 4) NOT NULL,
    currency_code CHAR(3) NOT NULL,
    fee_amount DECIMAL(20, 4) DEFAULT 0,
    net_amount DECIMAL(20, 4) NOT NULL,
    
    -- Participants
    from_account_id UUID REFERENCES core.accounts(id),
    to_account_id UUID REFERENCES core.accounts(id),
    client_id UUID REFERENCES core.clients(id),
    teller_id UUID REFERENCES auth.users(id),
    
    -- Dates
    transaction_date TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    -- System fields
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by UUID NOT NULL,
    version INTEGER NOT NULL DEFAULT 1
);
```

#### Business Rules to Implement:
- Transaction amount validation (positive amounts)
- Account participant validation
- Transaction reference auto-generation
- Basic status progression

#### Success Criteria:
- [ ] Transaction tables created with proper relationships
- [ ] Amount validation working correctly
- [ ] Transaction references auto-generated
- [ ] Integration with accounts and clients working
- [ ] Basic transaction flow tests passing

---

### **Substep 1.4: Enhanced Business Rules & Constraints**
**Focus**: Advanced validation and business logic enforcement
**Duration**: 2-3 days
**Dependencies**: Substeps 1.1, 1.2, 1.3 (all core tables)

#### What We'll Add:
```sql
-- Enhanced client constraints
ALTER TABLE core.clients ADD CONSTRAINT chk_client_age 
    CHECK (client_type <> 'INDIVIDUAL' OR 
           (date_of_birth IS NOT NULL AND 
            date_of_birth <= CURRENT_DATE - INTERVAL '18 years'));

ALTER TABLE core.clients ADD CONSTRAINT chk_phone_format 
    CHECK (phone ~* '^\+?[1-9]\d{1,14}$');

-- Enhanced account constraints
ALTER TABLE core.accounts ADD CONSTRAINT chk_balance_relationships 
    CHECK (available_balance <= current_balance AND 
           hold_balance <= current_balance AND 
           current_balance >= 0);

-- Enhanced transaction constraints
ALTER TABLE core.transactions ADD CONSTRAINT chk_transaction_accounts 
    CHECK ((from_account_id IS NOT NULL AND to_account_id IS NOT NULL AND 
            from_account_id != to_account_id) OR
           (from_account_id IS NOT NULL AND to_account_id IS NULL) OR
           (from_account_id IS NULL AND to_account_id IS NOT NULL));

-- Triggers for business logic
CREATE OR REPLACE FUNCTION core.validate_transaction_balance()
RETURNS TRIGGER AS $$
BEGIN
    -- Check available balance for debits
    IF NEW.from_account_id IS NOT NULL THEN
        IF (SELECT available_balance FROM core.accounts WHERE id = NEW.from_account_id) < NEW.amount THEN
            RAISE EXCEPTION 'Insufficient available balance';
        END IF;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;
```

#### Business Rules to Implement:
- Advanced client validation (age, phone, email)
- Account balance integrity checks
- Transaction balance validation
- KYC status progression rules
- Risk level assessment logic

#### Success Criteria:
- [ ] All enhanced constraints working correctly
- [ ] Business logic triggers functional
- [ ] Data integrity maintained under all scenarios
- [ ] Performance impact acceptable
- [ ] Comprehensive validation tests passing

---

### **Substep 1.5: Performance Optimization & Indexing**
**Focus**: Query performance and scalability
**Duration**: 2-3 days
**Dependencies**: Substeps 1.1-1.4 (complete schema)

#### What We'll Implement:
```sql
-- Critical performance indexes
CREATE INDEX idx_clients_phone ON core.clients(phone);
CREATE INDEX idx_clients_status ON core.clients(status);
CREATE INDEX idx_clients_kyc_status ON core.clients(kyc_status);
CREATE INDEX idx_clients_search ON core.clients 
    USING gin(to_tsvector('english', first_name || ' ' || last_name || ' ' || phone));

CREATE INDEX idx_accounts_number ON core.accounts(account_number);
CREATE INDEX idx_accounts_status ON core.accounts(status);
CREATE INDEX idx_accounts_balance ON core.accounts(current_balance);

CREATE INDEX idx_transactions_reference ON core.transactions(transaction_reference);
CREATE INDEX idx_transactions_date ON core.transactions(transaction_date);
CREATE INDEX idx_transactions_status ON core.transactions(status);
CREATE INDEX idx_transactions_accounts ON core.transactions(from_account_id, to_account_id);

-- Composite indexes for common queries
CREATE INDEX idx_transactions_client_date ON core.transactions(client_id, transaction_date);
CREATE INDEX idx_accounts_holder_active ON core.account_holders(account_id, client_id) 
    WHERE holder_type = 'PRIMARY';

-- Materialized views for analytics
CREATE MATERIALIZED VIEW core.client_summary AS
SELECT 
    c.id,
    c.client_number,
    c.first_name,
    c.last_name,
    c.kyc_status,
    c.risk_level,
    COUNT(a.id) as account_count,
    SUM(a.current_balance) as total_balance
FROM core.clients c
LEFT JOIN core.account_holders ah ON c.id = ah.client_id
LEFT JOIN core.accounts a ON ah.account_id = a.id
GROUP BY c.id, c.client_number, c.first_name, c.last_name, c.kyc_status, c.risk_level;
```

#### Performance Optimizations:
- Strategic indexing for common queries
- Full-text search capabilities
- Materialized views for analytics
- Query optimization
- Partitioning strategy planning

#### Success Criteria:
- [ ] All critical queries execute in < 100ms
- [ ] Search functionality working efficiently
- [ ] Analytics queries performant
- [ ] Index maintenance strategy defined
- [ ] Performance benchmarks established

---

## Implementation Strategy

### **Sequential Approach**
1. **Start with Substep 1.1**: Build the foundation
2. **Move to Substep 1.2**: Add account management
3. **Continue to Substep 1.3**: Add transaction capabilities
4. **Enhance with Substep 1.4**: Add business rules
5. **Optimize with Substep 1.5**: Performance tuning

### **Testing Strategy**
- **Unit Tests**: Each substep has its own test suite
- **Integration Tests**: Verify relationships between substeps
- **Performance Tests**: Validate query performance
- **Business Logic Tests**: Ensure rules are enforced

### **Rollback Strategy**
- Each substep is reversible
- Data migration scripts for each step
- Backup points after each substep
- Feature flags for gradual rollout

### **Success Metrics**
- **Functionality**: All business rules working
- **Performance**: Queries under 100ms
- **Data Integrity**: 100% constraint compliance
- **Scalability**: Support for 100K+ clients
- **Maintainability**: Clear documentation and tests

This breakdown makes the database schema design manageable and allows us to build incrementally while ensuring each piece is solid before moving to the next. 