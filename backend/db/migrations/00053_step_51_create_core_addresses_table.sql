-- +goose Up
CREATE SCHEMA IF NOT EXISTS core;
CREATE TABLE IF NOT EXISTS core.addresses (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    address_type VARCHAR(30) NOT NULL, -- e.g., 'residential', 'mailing', 'business', etc.
    line1 VARCHAR(255) NOT NULL,
    line2 VARCHAR(255),
    city VARCHAR(100) NOT NULL,
    state VARCHAR(100),
    postal_code VARCHAR(20),
    country_code CHAR(2) NOT NULL, -- ISO 3166-1 alpha-2
    latitude NUMERIC(10, 7),
    longitude NUMERIC(10, 7),
    is_primary BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_by UUID,
    updated_by UUID,
    version INTEGER NOT NULL DEFAULT 1
);

CREATE INDEX IF NOT EXISTS idx_addresses_city ON core.addresses(city);
CREATE INDEX IF NOT EXISTS idx_addresses_country_code ON core.addresses(country_code);
CREATE INDEX IF NOT EXISTS idx_addresses_postal_code ON core.addresses(postal_code);

-- +goose Down
DROP TABLE IF EXISTS core.addresses CASCADE; 