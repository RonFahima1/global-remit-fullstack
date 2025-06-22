-- +goose Up
CREATE TYPE transaction_status AS ENUM (
    'pending', 'completed', 'failed', 'cancelled', 'reversed', 'hold'
);

CREATE TYPE transaction_direction AS ENUM (
    'credit', 'debit'
);

CREATE TYPE participant_type AS ENUM (
    'sender', 'receiver', 'fee', 'tax', 'commission', 'adjustment', 'system'
);

CREATE TABLE IF NOT EXISTS core.transaction_types (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code VARCHAR(50) NOT NULL,
    name VARCHAR(100) NOT NULL,
    description TEXT,
    direction transaction_direction NOT NULL,
    affects_balance BOOLEAN NOT NULL DEFAULT true,
    requires_approval BOOLEAN NOT NULL DEFAULT false,
    approval_threshold DECIMAL(20, 4),
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by UUID,
    updated_by UUID,
    version INTEGER NOT NULL DEFAULT 1,
    
    CONSTRAINT uq_transaction_types_code UNIQUE (code)
);

CREATE TABLE IF NOT EXISTS core.transactions (
    -- Core Fields
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    transaction_reference VARCHAR(50) NOT NULL,
    transaction_type_id UUID NOT NULL,
    status transaction_status NOT NULL DEFAULT 'pending',
    
    -- Amount Information
    amount DECIMAL(20, 4) NOT NULL,
    currency_code CHAR(3) NOT NULL,
    exchange_rate NUMERIC(20, 10) DEFAULT 1,
    fee_amount DECIMAL(20, 4) DEFAULT 0,
    tax_amount DECIMAL(20, 4) DEFAULT 0,
    net_amount DECIMAL(20, 4) NOT NULL,
    
    -- Dates
    transaction_date TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    value_date DATE,
    
    -- References
    parent_transaction_id UUID,
    related_transaction_id UUID,
    branch_id UUID,
    teller_id UUID,
    
    -- Additional Information
    description TEXT,
    notes TEXT,
    metadata JSONB,
    
    -- System Fields
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by UUID,
    updated_by UUID,
    version INTEGER NOT NULL DEFAULT 1,
    
    -- Constraints
    CONSTRAINT uq_transactions_reference UNIQUE (transaction_reference),
    CONSTRAINT fk_transactions_type FOREIGN KEY (transaction_type_id) 
        REFERENCES core.transaction_types(id) ON DELETE RESTRICT,
    CONSTRAINT chk_transaction_amount CHECK (amount > 0),
    CONSTRAINT chk_net_amount CHECK (net_amount > 0)
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_transactions_reference ON core.transactions(transaction_reference);
CREATE INDEX IF NOT EXISTS idx_transactions_date ON core.transactions(transaction_date);
CREATE INDEX IF NOT EXISTS idx_transactions_type ON core.transactions(transaction_type_id);
CREATE INDEX IF NOT EXISTS idx_transactions_status ON core.transactions(status);
CREATE INDEX IF NOT EXISTS idx_transactions_created_by ON core.transactions(created_by);

-- +goose Down
DROP TABLE IF EXISTS core.transactions;
DROP TABLE IF EXISTS core.transaction_types;
DROP TYPE IF EXISTS participant_type;
DROP TYPE IF EXISTS transaction_direction;
DROP TYPE IF EXISTS transaction_status;
