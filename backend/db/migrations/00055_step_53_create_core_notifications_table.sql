-- +goose Up
CREATE SCHEMA IF NOT EXISTS core;
CREATE TABLE IF NOT EXISTS core.notifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    recipient_type VARCHAR(20) NOT NULL, -- 'user', 'client', etc.
    recipient_id UUID NOT NULL,
    notification_type VARCHAR(50) NOT NULL, -- e.g., 'system', 'transaction', 'compliance', etc.
    title VARCHAR(255) NOT NULL,
    message TEXT NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'unread', -- 'unread', 'read', 'archived', etc.
    priority VARCHAR(20) NOT NULL DEFAULT 'normal', -- 'low', 'normal', 'high', 'critical'
    metadata JSONB,
    sent_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    read_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    version INTEGER NOT NULL DEFAULT 1
);

CREATE INDEX IF NOT EXISTS idx_notifications_recipient ON core.notifications(recipient_type, recipient_id);
CREATE INDEX IF NOT EXISTS idx_notifications_status ON core.notifications(status);
CREATE INDEX IF NOT EXISTS idx_notifications_type ON core.notifications(notification_type);

-- +goose Down
DROP TABLE IF EXISTS core.notifications CASCADE; 