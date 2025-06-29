-- +goose Up
ALTER TABLE core.clients DROP CONSTRAINT IF EXISTS chk_email_format;

-- +goose Down
ALTER TABLE core.clients ADD CONSTRAINT chk_email_format CHECK (email IS NULL OR email ~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$');
