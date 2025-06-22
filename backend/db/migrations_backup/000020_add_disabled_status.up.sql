-- +goose Up
ALTER TABLE auth.users DROP CONSTRAINT IF EXISTS users_status_check;
 
ALTER TABLE auth.users ADD CONSTRAINT users_status_check 
CHECK (status::text = ANY (ARRAY['PENDING_VERIFICATION'::character varying, 'ACTIVE'::character varying, 'SUSPENDED'::character varying, 'LOCKED'::character varying, 'DISABLED'::character varying]::text[]));

-- +goose Down
ALTER TABLE auth.users DROP CONSTRAINT IF EXISTS users_status_check;

ALTER TABLE auth.users ADD CONSTRAINT users_status_check 
CHECK (status::text = ANY (ARRAY['PENDING_VERIFICATION'::character varying, 'ACTIVE'::character varying, 'SUSPENDED'::character varying, 'LOCKED'::character varying]::text[])); 