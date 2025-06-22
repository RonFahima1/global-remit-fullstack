-- +goose Up
CREATE SCHEMA IF NOT EXISTS compliance;
CREATE TABLE IF NOT EXISTS compliance.watchlist_hits (
    id BIGSERIAL PRIMARY KEY,
    client_id uuid REFERENCES core.clients(id) ON DELETE CASCADE,
    transaction_id uuid REFERENCES core.transactions(id) ON DELETE CASCADE,
    hit_date TIMESTAMPTZ NOT NULL DEFAULT now(),
    watchlist_source TEXT NOT NULL,
    hit_details JSONB NOT NULL,
    resolved BOOLEAN NOT NULL DEFAULT FALSE,
    resolved_by uuid REFERENCES auth.users(id),
    resolved_at TIMESTAMPTZ,
    notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_watchlist_hits_client_id ON compliance.watchlist_hits(client_id);
CREATE INDEX IF NOT EXISTS idx_watchlist_hits_transaction_id ON compliance.watchlist_hits(transaction_id);
CREATE INDEX IF NOT EXISTS idx_watchlist_hits_resolved ON compliance.watchlist_hits(resolved);

-- +goose Down
DROP TABLE IF EXISTS compliance.watchlist_hits CASCADE; 