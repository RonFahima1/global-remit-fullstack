-- +goose Up
-- +goose StatementBegin
SELECT 'up SQL query';
ALTER TABLE core.clients ADD COLUMN IF NOT EXISTS middle_name VARCHAR(100);
ALTER TABLE core.clients ADD COLUMN IF NOT EXISTS title VARCHAR(10);
ALTER TABLE core.clients ADD COLUMN IF NOT EXISTS email VARCHAR(255);
ALTER TABLE core.clients ADD COLUMN IF NOT EXISTS email_verified BOOLEAN DEFAULT false;
ALTER TABLE core.clients ADD COLUMN IF NOT EXISTS phone VARCHAR(20);
ALTER TABLE core.clients ADD COLUMN IF NOT EXISTS phone_verified BOOLEAN DEFAULT false;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
SELECT 'down SQL query';
ALTER TABLE core.clients DROP COLUMN IF EXISTS middle_name;
ALTER TABLE core.clients DROP COLUMN IF EXISTS title;
ALTER TABLE core.clients DROP COLUMN IF EXISTS email;
ALTER TABLE core.clients DROP COLUMN IF EXISTS email_verified;
ALTER TABLE core.clients DROP COLUMN IF EXISTS phone;
ALTER TABLE core.clients DROP COLUMN IF EXISTS phone_verified;
-- +goose StatementEnd
