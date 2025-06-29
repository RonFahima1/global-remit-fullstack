-- +goose Up
CREATE TYPE user_status AS ENUM ('PENDING_VERIFICATION', 'ACTIVE', 'DISABLED', 'SUSPENDED', 'LOCKED', 'DELETED');

ALTER TABLE auth.users
ADD COLUMN IF NOT EXISTS status user_status NOT NULL DEFAULT 'PENDING_VERIFICATION',
ADD COLUMN IF NOT EXISTS must_change_password BOOLEAN NOT NULL DEFAULT FALSE;

UPDATE auth.users SET status = 'ACTIVE' WHERE status IS NULL;

-- +goose Down
ALTER TABLE auth.users
DROP COLUMN IF EXISTS must_change_password,
DROP COLUMN IF EXISTS status;

DROP TYPE IF EXISTS user_status; 