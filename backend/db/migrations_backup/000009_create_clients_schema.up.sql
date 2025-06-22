-- +goose Up
CREATE SCHEMA IF NOT EXISTS core;

CREATE TABLE IF NOT EXISTS core.clients (
    -- Core Identity
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    client_number VARCHAR(20) UNIQUE NOT NULL,
    client_type VARCHAR(20) NOT NULL CHECK (client_type IN ('INDIVIDUAL', 'BUSINESS', 'ORGANIZATION')),
    status VARCHAR(20) NOT NULL DEFAULT 'PENDING' 
        CHECK (status IN ('PENDING', 'ACTIVE', 'SUSPENDED', 'CLOSED', 'DECEASED')),
    
    -- Personal Information
    title VARCHAR(10),
    first_name VARCHAR(100) NOT NULL,
    middle_name VARCHAR(100),
    last_name VARCHAR(100) NOT NULL,
    -- full_name VARCHAR(301) GENERATED ALWAYS AS (
    --     TRIM(CONCAT_WS(' ', title, first_name, middle_name, last_name))
    -- ) STORED,
    date_of_birth DATE,
    gender VARCHAR(10) CHECK (gender IN ('MALE', 'FEMALE', 'OTHER', 'UNSPECIFIED')),
    marital_status VARCHAR(20),
    
    -- Contact Information
    email VARCHAR(255),
    email_verified BOOLEAN NOT NULL DEFAULT false,
    phone VARCHAR(20),
    phone_verified BOOLEAN NOT NULL DEFAULT false,
    
    -- Address Information
    -- residential_address_id UUID REFERENCES core.addresses(id),
    -- mailing_address_id UUID REFERENCES core.addresses(id),
    
    -- Employment Information
    occupation VARCHAR(100),
    employer_name VARCHAR(200),
    employment_status VARCHAR(50),
    annual_income DECIMAL(15, 2),
    
    -- KYC/AML
    kyc_status VARCHAR(20) NOT NULL DEFAULT 'NOT_VERIFIED'
        CHECK (kyc_status IN ('NOT_VERIFIED', 'PENDING', 'VERIFIED', 'REJECTED', 'EXPIRED')),
    kyc_verified_at TIMESTAMPTZ,
    kyc_verified_by UUID, -- REFERENCES auth.users(id),
    
    -- Risk
    risk_level VARCHAR(20) NOT NULL DEFAULT 'LOW',
    
    -- Relationship Management
    relationship_manager_id UUID, -- REFERENCES auth.users(id),
    referral_source VARCHAR(100),
    
    -- System
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at TIMESTAMPTZ,
    created_by UUID, -- REFERENCES auth.users(id),
    updated_by UUID, -- REFERENCES auth.users(id),
    version INTEGER NOT NULL DEFAULT 1,
    
    -- Constraints
    CONSTRAINT chk_email_format CHECK (email IS NULL OR email ~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$'),
    CONSTRAINT chk_phone_format CHECK (phone IS NULL OR phone ~* '^\\+?[0-9\\s-]+$')
    -- CONSTRAINT chk_client_number_format CHECK (client_number ~ '^[A-Z0-9]{3}-[A-Z0-9]{4}-[A-Z0-9]{3}$')
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_clients_client_number ON core.clients(client_number);
-- CREATE INDEX IF NOT EXISTS idx_clients_full_name ON core.clients USING GIN (full_name gin_trgm_ops);
CREATE INDEX IF NOT EXISTS idx_clients_status ON core.clients(status);
CREATE INDEX IF NOT EXISTS idx_clients_kyc_status ON core.clients(kyc_status);
CREATE INDEX IF NOT EXISTS idx_clients_created_at ON core.clients(created_at);

-- +goose Down
DROP TABLE IF EXISTS core.clients;
DROP SCHEMA IF EXISTS core;
