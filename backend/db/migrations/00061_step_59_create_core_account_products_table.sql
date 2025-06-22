-- +goose Up
CREATE SCHEMA IF NOT EXISTS core;
CREATE TABLE IF NOT EXISTS core.account_products (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    account_id UUID NOT NULL,
    product_id UUID NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'active', -- 'active', 'inactive', 'archived'
    assigned_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    unassigned_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_by UUID,
    updated_by UUID,
    version INTEGER NOT NULL DEFAULT 1,
    CONSTRAINT uq_account_product UNIQUE (account_id, product_id)
);

CREATE INDEX IF NOT EXISTS idx_account_products_account_id ON core.account_products(account_id);
CREATE INDEX IF NOT EXISTS idx_account_products_product_id ON core.account_products(product_id);
CREATE INDEX IF NOT EXISTS idx_account_products_status ON core.account_products(status);

-- +goose Down
DROP TABLE IF EXISTS core.account_products CASCADE; 