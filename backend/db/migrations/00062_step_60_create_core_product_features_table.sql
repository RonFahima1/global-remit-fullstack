-- +goose Up
CREATE SCHEMA IF NOT EXISTS core;
CREATE TABLE IF NOT EXISTS core.product_features (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    product_id UUID NOT NULL,
    feature_name VARCHAR(100) NOT NULL,
    feature_value TEXT,
    data_type VARCHAR(20) NOT NULL DEFAULT 'string', -- 'string', 'number', 'boolean', 'json', etc.
    status VARCHAR(20) NOT NULL DEFAULT 'active', -- 'active', 'inactive', 'archived'
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_by UUID,
    updated_by UUID,
    version INTEGER NOT NULL DEFAULT 1,
    CONSTRAINT uq_product_feature UNIQUE (product_id, feature_name)
);

CREATE INDEX IF NOT EXISTS idx_product_features_product_id ON core.product_features(product_id);
CREATE INDEX IF NOT EXISTS idx_product_features_status ON core.product_features(status);

-- +goose Down
DROP TABLE IF EXISTS core.product_features CASCADE; 