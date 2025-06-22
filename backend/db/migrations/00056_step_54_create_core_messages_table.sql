-- +goose Up
CREATE SCHEMA IF NOT EXISTS core;
CREATE TABLE IF NOT EXISTS core.messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    sender_type VARCHAR(20) NOT NULL, -- 'user', 'system', etc.
    sender_id UUID NOT NULL,
    recipient_type VARCHAR(20) NOT NULL, -- 'user', 'client', etc.
    recipient_id UUID NOT NULL,
    message_type VARCHAR(50) NOT NULL, -- e.g., 'email', 'sms', 'internal', etc.
    subject VARCHAR(255),
    body TEXT NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'sent', -- 'sent', 'delivered', 'read', 'failed', etc.
    direction VARCHAR(10) NOT NULL DEFAULT 'out', -- 'in', 'out'
    metadata JSONB,
    sent_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    read_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    version INTEGER NOT NULL DEFAULT 1
);

CREATE INDEX IF NOT EXISTS idx_messages_sender ON core.messages(sender_type, sender_id);
CREATE INDEX IF NOT EXISTS idx_messages_recipient ON core.messages(recipient_type, recipient_id);
CREATE INDEX IF NOT EXISTS idx_messages_status ON core.messages(status);
CREATE INDEX IF NOT EXISTS idx_messages_type ON core.messages(message_type);

-- +goose Down
DROP TABLE IF EXISTS core.messages CASCADE; 