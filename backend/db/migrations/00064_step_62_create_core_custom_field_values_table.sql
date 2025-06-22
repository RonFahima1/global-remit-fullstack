-- +goose Up
CREATE SCHEMA IF NOT EXISTS core;
CREATE TABLE IF NOT EXISTS core.custom_field_values (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    entity_type VARCHAR(50) NOT NULL, -- e.g., 'client', 'account', 'transaction', etc.
    entity_id UUID NOT NULL,
    field_id UUID NOT NULL,
    field_name VARCHAR(100) NOT NULL,
    value TEXT,
    data_type VARCHAR(20) NOT NULL DEFAULT 'string', -- 'string', 'number', 'boolean', 'date', 'json', etc.
    status VARCHAR(20) NOT NULL DEFAULT 'active', -- 'active', 'inactive', 'archived'
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_by UUID,
    updated_by UUID,
    version INTEGER NOT NULL DEFAULT 1,
    CONSTRAINT uq_custom_field_value UNIQUE (entity_type, entity_id, field_id)
);

CREATE INDEX IF NOT EXISTS idx_custom_field_values_entity ON core.custom_field_values(entity_type, entity_id);
CREATE INDEX IF NOT EXISTS idx_custom_field_values_field_id ON core.custom_field_values(field_id);
CREATE INDEX IF NOT EXISTS idx_custom_field_values_status ON core.custom_field_values(status);

-- +goose Down
DROP TABLE IF EXISTS core.custom_field_values CASCADE; 