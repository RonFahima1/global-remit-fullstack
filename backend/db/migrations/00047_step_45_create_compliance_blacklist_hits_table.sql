-- +goose Up
CREATE SCHEMA IF NOT EXISTS compliance;
CREATE TABLE IF NOT EXISTS compliance.blacklist_hits (
    id BIGSERIAL PRIMARY KEY,
    client_id uuid REFERENCES core.clients(id) ON DELETE CASCADE,
    transaction_id uuid REFERENCES core.transactions(id) ON DELETE CASCADE,
    hit_date TIMESTAMPTZ NOT NULL DEFAULT now(),
    blacklist_source TEXT NOT NULL,
    hit_details JSONB NOT NULL,
    resolved BOOLEAN NOT NULL DEFAULT FALSE,
    resolved_by uuid REFERENCES auth.users(id),
    resolved_at TIMESTAMPTZ,
    notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_blacklist_hits_client_id ON compliance.blacklist_hits(client_id);
CREATE INDEX IF NOT EXISTS idx_blacklist_hits_transaction_id ON compliance.blacklist_hits(transaction_id);
CREATE INDEX IF NOT EXISTS idx_blacklist_hits_resolved ON compliance.blacklist_hits(resolved);

-- +goose Down
DROP TABLE IF EXISTS compliance.blacklist_hits CASCADE; 