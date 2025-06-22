-- +goose Up
-- +goose StatementBegin
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
        phone ~* '^\\+?[1-9]\\d{1,14}$'
    )
);

CREATE INDEX idx_clients_client_number ON core.clients(client_number);
CREATE INDEX idx_clients_phone ON core.clients(phone);
CREATE INDEX idx_clients_status ON core.clients(status);
CREATE INDEX idx_clients_kyc_status ON core.clients(kyc_status);
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP TABLE IF EXISTS core.clients;
-- +goose StatementEnd
