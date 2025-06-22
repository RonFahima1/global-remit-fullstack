-- +goose Up
CREATE SCHEMA IF NOT EXISTS compliance;
CREATE TABLE IF NOT EXISTS compliance.pep_screenings (
    id BIGSERIAL PRIMARY KEY,
    client_id uuid REFERENCES core.clients(id) ON DELETE CASCADE,
    transaction_id uuid REFERENCES core.transactions(id) ON DELETE CASCADE,
    screening_date TIMESTAMPTZ NOT NULL DEFAULT now(),
    pep_source TEXT NOT NULL,
    screening_details JSONB NOT NULL,
    is_pep BOOLEAN NOT NULL DEFAULT FALSE,
    resolved BOOLEAN NOT NULL DEFAULT FALSE,
    resolved_by uuid REFERENCES auth.users(id),
    resolved_at TIMESTAMPTZ,
    notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_pep_screenings_client_id ON compliance.pep_screenings(client_id);
CREATE INDEX IF NOT EXISTS idx_pep_screenings_transaction_id ON compliance.pep_screenings(transaction_id);
CREATE INDEX IF NOT EXISTS idx_pep_screenings_resolved ON compliance.pep_screenings(resolved);

-- +goose Down
DROP TABLE IF EXISTS compliance.pep_screenings CASCADE; 