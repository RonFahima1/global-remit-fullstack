CREATE SCHEMA IF NOT EXISTS compliance;

CREATE TABLE IF NOT EXISTS compliance.kyc_verifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    client_id UUID NOT NULL,
    verification_type VARCHAR(50) NOT NULL,
    verification_status VARCHAR(20) NOT NULL,
    verified_at TIMESTAMPTZ,
    verified_by UUID,
    expiration_date TIMESTAMPTZ,
    verification_data JSONB,
    rejection_reason TEXT,
    
    -- System Fields
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by UUID, -- NOT NULL,
    updated_by UUID,
    version INTEGER NOT NULL DEFAULT 1,
    
    -- Constraints
    CONSTRAINT fk_kyc_client FOREIGN KEY (client_id) 
        REFERENCES core.clients(id) ON DELETE CASCADE,
    CONSTRAINT chk_verification_status CHECK (
        verification_status IN ('pending', 'approved', 'rejected', 'expired')
    )
);

CREATE TABLE IF NOT EXISTS compliance.aml_checks (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    client_id UUID,
    transaction_id UUID,
    check_type VARCHAR(50) NOT NULL,
    check_status VARCHAR(20) NOT NULL,
    risk_score INTEGER,
    risk_level VARCHAR(20),
    check_data JSONB,
    notes TEXT,
    resolved_at TIMESTAMPTZ,
    resolved_by UUID,
    
    -- System Fields
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by UUID, -- NOT NULL,
    updated_by UUID,
    version INTEGER NOT NULL DEFAULT 1,
    
    -- Constraints
    CONSTRAINT fk_aml_client FOREIGN KEY (client_id) 
        REFERENCES core.clients(id) ON DELETE SET NULL,
    CONSTRAINT fk_aml_transaction FOREIGN KEY (transaction_id) 
        REFERENCES core.transactions(id) ON DELETE SET NULL,
    CONSTRAINT chk_aml_status CHECK (
        check_status IN ('pending', 'passed', 'failed', 'manual_review')
    ),
    CONSTRAINT chk_risk_level CHECK (
        risk_level IN ('low', 'medium', 'high', 'critical')
    )
);

CREATE TABLE IF NOT EXISTS compliance.sanctions_matches (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    client_id UUID,
    transaction_id UUID,
    list_name VARCHAR(100) NOT NULL,
    matched_name TEXT NOT NULL,
    match_score NUMERIC(5, 2) NOT NULL,
    match_data JSONB,
    status VARCHAR(20) NOT NULL DEFAULT 'pending',
    reviewed_at TIMESTAMPTZ,
    reviewed_by UUID,
    review_notes TEXT,
    
    -- System Fields
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by UUID, -- NOT NULL,
    updated_by UUID,
    version INTEGER NOT NULL DEFAULT 1,
    
    -- Constraints
    CONSTRAINT fk_sanctions_client FOREIGN KEY (client_id) 
        REFERENCES core.clients(id) ON DELETE SET NULL,
    CONSTRAINT fk_sanctions_transaction FOREIGN KEY (transaction_id) 
        REFERENCES core.transactions(id) ON DELETE SET NULL,
    CONSTRAINT chk_sanctions_status CHECK (
        status IN ('pending', 'false_positive', 'confirmed', 'resolved')
    )
);

CREATE TABLE IF NOT EXISTS compliance.audit_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    event_time TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    event_type VARCHAR(50) NOT NULL,
    table_name VARCHAR(100),
    record_id UUID,
    user_id UUID,
    user_ip INET,
    user_agent TEXT,
    action VARCHAR(20) NOT NULL,
    old_values JSONB,
    new_values JSONB,
    
    -- Constraints
    CONSTRAINT chk_audit_action CHECK (
        action IN ('INSERT', 'UPDATE', 'DELETE', 'LOGIN', 'LOGOUT', 'AUTH_FAILED')
    )
);
