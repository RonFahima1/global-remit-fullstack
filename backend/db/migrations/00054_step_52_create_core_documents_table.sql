-- +goose Up
CREATE SCHEMA IF NOT EXISTS core;
CREATE TABLE IF NOT EXISTS core.documents (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    owner_type VARCHAR(30) NOT NULL, -- e.g., 'client', 'user', 'account', 'transaction', etc.
    owner_id UUID NOT NULL, -- references the owning entity
    document_type VARCHAR(50) NOT NULL, -- e.g., 'kyc', 'aml', 'contract', etc.
    file_name VARCHAR(255) NOT NULL,
    file_url TEXT NOT NULL,
    mime_type VARCHAR(100) NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'active', -- e.g., 'active', 'archived', 'deleted'
    metadata JSONB,
    uploaded_by UUID,
    uploaded_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    version INTEGER NOT NULL DEFAULT 1
);

CREATE INDEX IF NOT EXISTS idx_documents_owner_type_id ON core.documents(owner_type, owner_id);
CREATE INDEX IF NOT EXISTS idx_documents_document_type ON core.documents(document_type);
CREATE INDEX IF NOT EXISTS idx_documents_status ON core.documents(status);

-- +goose Down
DROP TABLE IF EXISTS core.documents CASCADE; 