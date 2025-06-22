-- +goose Up
CREATE SCHEMA IF NOT EXISTS compliance;
CREATE TABLE IF NOT EXISTS compliance.case_notes (
    id BIGSERIAL PRIMARY KEY,
    case_id BIGINT REFERENCES compliance.case_management(id) ON DELETE CASCADE,
    note_text TEXT NOT NULL,
    created_by uuid REFERENCES auth.users(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_case_notes_case_id ON compliance.case_notes(case_id);
CREATE INDEX IF NOT EXISTS idx_case_notes_created_by ON compliance.case_notes(created_by);

-- +goose Down
DROP TABLE IF EXISTS compliance.case_notes CASCADE; 