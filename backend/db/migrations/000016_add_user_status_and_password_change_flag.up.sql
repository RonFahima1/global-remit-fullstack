-- Add user_status type
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'user_status') THEN
        CREATE TYPE user_status AS ENUM ('PENDING_VERIFICATION', 'ACTIVE', 'DISABLED', 'SUSPENDED', 'LOCKED', 'DELETED');
    END IF;
END$$;

-- Add new columns to auth.users table
ALTER TABLE auth.users
ADD COLUMN IF NOT EXISTS status user_status NOT NULL DEFAULT 'PENDING_VERIFICATION',
ADD COLUMN IF NOT EXISTS must_change_password BOOLEAN NOT NULL DEFAULT FALSE;

-- Update existing users to have a default status if they don't have one
UPDATE auth.users SET status = 'ACTIVE' WHERE status IS NULL; 