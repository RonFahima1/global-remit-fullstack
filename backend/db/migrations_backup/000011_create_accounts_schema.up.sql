-- +goose Up
CREATE TABLE IF NOT EXISTS core.account_types (
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
    created_by UUID, -- NOT NULL REFERENCES auth.users(id),
    updated_by UUID, -- REFERENCES auth.users(id),
    version INTEGER NOT NULL DEFAULT 1
);

CREATE TABLE IF NOT EXISTS core.accounts (
    -- Core Identity
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    account_number VARCHAR(20) UNIQUE NOT NULL,
    account_name VARCHAR(255) NOT NULL,
    
    -- Account Type
    account_type_id UUID NOT NULL, -- No FK to avoid migration order issues, add later
    
    -- Currency
    currency_code CHAR(3) NOT NULL, -- No FK to avoid migration order issues, add later
    
    -- Balances
    current_balance DECIMAL(19, 4) NOT NULL DEFAULT 0,
    available_balance DECIMAL(19, 4) NOT NULL DEFAULT 0,
    hold_balance DECIMAL(19, 4) NOT NULL DEFAULT 0,
    
    -- Status
    status VARCHAR(20) NOT NULL DEFAULT 'ACTIVE'
        CHECK (status IN ('PENDING', 'ACTIVE', 'DORMANT', 'RESTRICTED', 'CLOSED')),
    
    -- Dates
    open_date DATE NOT NULL DEFAULT CURRENT_DATE,
    last_activity_date DATE,
    close_date DATE,
    
    -- Metadata
    metadata JSONB,
    
    -- System
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by UUID, -- NOT NULL REFERENCES auth.users(id),
    updated_by UUID, -- REFERENCES auth.users(id),
    version INTEGER NOT NULL DEFAULT 1,
    
    -- Constraints
    CONSTRAINT chk_balance_non_negative CHECK (current_balance >= 0),
    CONSTRAINT chk_available_balance CHECK (available_balance <= current_balance),
    CONSTRAINT chk_hold_balance CHECK (hold_balance <= current_balance),
    CONSTRAINT chk_dates CHECK (
        (close_date IS NULL) OR 
        (close_date IS NOT NULL AND close_date >= open_date)
    )
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_accounts_number ON core.accounts(account_number);
CREATE INDEX IF NOT EXISTS idx_accounts_type ON core.accounts(account_type_id);
CREATE INDEX IF NOT EXISTS idx_accounts_currency ON core.accounts(currency_code);
CREATE INDEX IF NOT EXISTS idx_accounts_status ON core.accounts(status);
CREATE INDEX IF NOT EXISTS idx_accounts_balance ON core.accounts(current_balance);
CREATE INDEX IF NOT EXISTS idx_accounts_open_date ON core.accounts(open_date);

CREATE TABLE IF NOT EXISTS core.account_holders (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    account_id UUID NOT NULL, -- No FK to avoid migration order issues, add later
    client_id UUID NOT NULL, -- No FK to avoid migration order issues, add later
    
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
    created_by UUID, -- NOT NULL REFERENCES auth.users(id),
    updated_by UUID, -- REFERENCES auth.users(id),
    version INTEGER NOT NULL DEFAULT 1,
    
    -- Constraints
    CONSTRAINT chk_removal_date CHECK (
        (removed_date IS NULL) OR 
        (removed_date IS NOT NULL AND removed_date >= added_date)
    ),
    CONSTRAINT uq_account_holder UNIQUE (account_id, client_id, holder_type)
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_account_holders_account ON core.account_holders(account_id);
CREATE INDEX IF NOT EXISTS idx_account_holders_client ON core.account_holders(client_id);
CREATE INDEX IF NOT EXISTS idx_account_holders_type ON core.account_holders(holder_type);

CREATE TABLE IF NOT EXISTS core.account_balances (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    account_id UUID NOT NULL, -- No FK to avoid migration order issues, add later
    
    -- Balance Information
    balance_date DATE NOT NULL,
    opening_balance DECIMAL(19, 4) NOT NULL,
    closing_balance DECIMAL(19, 4) NOT NULL,
    total_credits DECIMAL(19, 4) NOT NULL DEFAULT 0,
    total_debits DECIMAL(19, 4) NOT NULL DEFAULT 0,
    transaction_count INTEGER NOT NULL DEFAULT 0,
    
    -- System
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by UUID, -- NOT NULL REFERENCES auth.users(id),
    updated_by UUID, -- REFERENCES auth.users(id),
    version INTEGER NOT NULL DEFAULT 1,
    
    -- Constraints
    CONSTRAINT chk_positive_balances CHECK (
        opening_balance >= 0 AND 
        closing_balance >= 0 AND
        total_credits >= 0 AND
        total_debits >= 0
    ),
    CONSTRAINT uq_daily_balance UNIQUE (account_id, balance_date)
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_account_balances_account ON core.account_balances(account_id);
CREATE INDEX IF NOT EXISTS idx_account_balances_date ON core.account_balances(balance_date);

-- +goose Down
DROP TABLE IF EXISTS core.account_balances;
DROP TABLE IF EXISTS core.account_holders;
DROP TABLE IF EXISTS core.accounts;
DROP TABLE IF EXISTS core.account_types;
