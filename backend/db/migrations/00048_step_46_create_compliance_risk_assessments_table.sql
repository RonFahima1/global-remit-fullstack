-- +goose Up
CREATE SCHEMA IF NOT EXISTS compliance;
CREATE TABLE IF NOT EXISTS compliance.risk_assessments (
    id BIGSERIAL PRIMARY KEY,
    client_id uuid REFERENCES core.clients(id) ON DELETE CASCADE,
    transaction_id uuid REFERENCES core.transactions(id) ON DELETE CASCADE,
    assessment_date TIMESTAMPTZ NOT NULL DEFAULT now(),
    risk_score NUMERIC(5,2) NOT NULL,
    risk_level TEXT NOT NULL,
    assessment_details JSONB NOT NULL,
    assessed_by uuid REFERENCES auth.users(id),
    notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_risk_assessments_client_id ON compliance.risk_assessments(client_id);
CREATE INDEX IF NOT EXISTS idx_risk_assessments_transaction_id ON compliance.risk_assessments(transaction_id);
CREATE INDEX IF NOT EXISTS idx_risk_assessments_risk_level ON compliance.risk_assessments(risk_level);

-- +goose Down
DROP TABLE IF EXISTS compliance.risk_assessments CASCADE; 