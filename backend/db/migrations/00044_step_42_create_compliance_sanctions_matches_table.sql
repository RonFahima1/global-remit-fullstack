-- +goose Up
CREATE SCHEMA IF NOT EXISTS core;
CREATE SCHEMA IF NOT EXISTS auth;
CREATE SCHEMA IF NOT EXISTS compliance;
DROP TABLE IF EXISTS compliance.sanctions_matches CASCADE;
CREATE TABLE compliance.sanctions_matches (
    id BIGSERIAL PRIMARY KEY,
    client_id uuid REFERENCES core.clients(id) ON DELETE CASCADE,
    transaction_id uuid REFERENCES core.transactions(id) ON DELETE CASCADE,
    match_date TIMESTAMPTZ NOT NULL DEFAULT now(),
    match_source TEXT NOT NULL,
    match_details JSONB NOT NULL,
    resolved BOOLEAN NOT NULL DEFAULT FALSE,
    resolved_by uuid REFERENCES auth.users(id),
    resolved_at TIMESTAMPTZ,
    notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_sanctions_matches_client_id ON compliance.sanctions_matches(client_id);
CREATE INDEX IF NOT EXISTS idx_sanctions_matches_transaction_id ON compliance.sanctions_matches(transaction_id);
CREATE INDEX IF NOT EXISTS idx_sanctions_matches_resolved ON compliance.sanctions_matches(resolved);

-- +goose Down
DROP TABLE IF EXISTS compliance.sanctions_matches CASCADE;
