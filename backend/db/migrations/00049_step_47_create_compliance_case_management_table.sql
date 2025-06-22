-- +goose Up
CREATE SCHEMA IF NOT EXISTS compliance;
CREATE TABLE IF NOT EXISTS compliance.case_management (
    id BIGSERIAL PRIMARY KEY,
    client_id uuid REFERENCES core.clients(id) ON DELETE CASCADE,
    case_type TEXT NOT NULL,
    status TEXT NOT NULL,
    opened_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    closed_at TIMESTAMPTZ,
    assigned_to uuid REFERENCES auth.users(id),
    case_details JSONB NOT NULL,
    notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_case_management_client_id ON compliance.case_management(client_id);
CREATE INDEX IF NOT EXISTS idx_case_management_status ON compliance.case_management(status);
CREATE INDEX IF NOT EXISTS idx_case_management_assigned_to ON compliance.case_management(assigned_to);

-- +goose Down
DROP TABLE IF EXISTS compliance.case_management CASCADE; 