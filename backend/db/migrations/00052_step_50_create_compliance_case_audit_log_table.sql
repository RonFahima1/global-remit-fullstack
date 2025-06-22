-- +goose Up
CREATE SCHEMA IF NOT EXISTS compliance;
CREATE TABLE IF NOT EXISTS compliance.case_audit_log (
    id BIGSERIAL PRIMARY KEY,
    case_id BIGINT REFERENCES compliance.case_management(id) ON DELETE CASCADE,
    event_type TEXT NOT NULL,
    event_details JSONB NOT NULL,
    created_by uuid REFERENCES auth.users(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_case_audit_log_case_id ON compliance.case_audit_log(case_id);
CREATE INDEX IF NOT EXISTS idx_case_audit_log_created_by ON compliance.case_audit_log(created_by);
CREATE INDEX IF NOT EXISTS idx_case_audit_log_event_type ON compliance.case_audit_log(event_type);

-- +goose Down
DROP TABLE IF EXISTS compliance.case_audit_log CASCADE; 