-- Add audit columns to users table
-- This migration adds the missing updated_by and deleted_by columns that are used by the repository

-- +goose Up
ALTER TABLE auth.users 
ADD COLUMN IF NOT EXISTS updated_by UUID REFERENCES auth.users(id),
ADD COLUMN IF NOT EXISTS deleted_by UUID REFERENCES auth.users(id);

-- Add indexes for performance
CREATE INDEX IF NOT EXISTS idx_users_updated_by ON auth.users(updated_by);
CREATE INDEX IF NOT EXISTS idx_users_deleted_by ON auth.users(deleted_by);

-- +goose Down
DROP INDEX IF EXISTS idx_users_deleted_by;
DROP INDEX IF EXISTS idx_users_updated_by;

ALTER TABLE auth.users
DROP COLUMN IF EXISTS deleted_by,
DROP COLUMN IF EXISTS updated_by; 