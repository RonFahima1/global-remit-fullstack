-- +goose Up
CREATE SCHEMA IF NOT EXISTS compliance;
CREATE TABLE IF NOT EXISTS compliance.case_attachments (
    id BIGSERIAL PRIMARY KEY,
    case_id BIGINT REFERENCES compliance.case_management(id) ON DELETE CASCADE,
    file_name TEXT NOT NULL,
    file_url TEXT NOT NULL,
    description TEXT,
    uploaded_by uuid REFERENCES auth.users(id),
    uploaded_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_case_attachments_case_id ON compliance.case_attachments(case_id);
CREATE INDEX IF NOT EXISTS idx_case_attachments_uploaded_by ON compliance.case_attachments(uploaded_by);

-- +goose Down
DROP TABLE IF EXISTS compliance.case_attachments CASCADE; 