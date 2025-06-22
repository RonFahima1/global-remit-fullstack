-- +goose Up
CREATE SCHEMA IF NOT EXISTS core;
CREATE TABLE IF NOT EXISTS core.custom_fields (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    entity_type VARCHAR(50) NOT NULL, -- e.g., 'client', 'account', 'transaction', etc.
    field_name VARCHAR(100) NOT NULL,
    label VARCHAR(100) NOT NULL,
    data_type VARCHAR(20) NOT NULL DEFAULT 'string', -- 'string', 'number', 'boolean', 'date', 'json', etc.
    is_required BOOLEAN NOT NULL DEFAULT false,
    options JSONB, -- for select fields, etc.
    status VARCHAR(20) NOT NULL DEFAULT 'active', -- 'active', 'inactive', 'archived'
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_by UUID,
    updated_by UUID,
    version INTEGER NOT NULL DEFAULT 1,
    CONSTRAINT uq_custom_field UNIQUE (entity_type, field_name)
);

CREATE INDEX IF NOT EXISTS idx_custom_fields_entity_type ON core.custom_fields(entity_type);
CREATE INDEX IF NOT EXISTS idx_custom_fields_status ON core.custom_fields(status);

-- +goose Down
DROP TABLE IF EXISTS core.custom_fields CASCADE; 