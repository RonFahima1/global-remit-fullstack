-- +goose Up
ALTER TABLE auth.users
ADD COLUMN IF NOT EXISTS failed_login_attempts INT NOT NULL DEFAULT 0,
ADD COLUMN IF NOT EXISTS lockout_until TIMESTAMPTZ;
 
COMMENT ON COLUMN auth.users.failed_login_attempts IS 'Tracks the number of consecutive failed login attempts.';
COMMENT ON COLUMN auth.users.lockout_until IS 'The timestamp until which the user account is locked.';

-- +goose Down
ALTER TABLE auth.users
DROP COLUMN IF EXISTS lockout_until,
DROP COLUMN IF EXISTS failed_login_attempts; 