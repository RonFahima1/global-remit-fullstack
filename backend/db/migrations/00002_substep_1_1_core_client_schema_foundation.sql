-- +goose Up
-- +goose StatementBegin
CREATE TABLE IF NOT EXISTS core.branches (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    branch_name VARCHAR(150) NOT NULL,
    branch_code VARCHAR(20) UNIQUE,
    address TEXT,
    city VARCHAR(100),
    state VARCHAR(100),
    postal_code VARCHAR(20),
    country_code CHAR(2),
    phone VARCHAR(30),
    email VARCHAR(255),
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by UUID,
    updated_by UUID,
    version INTEGER NOT NULL DEFAULT 1
);

CREATE TABLE IF NOT EXISTS core.client_profile_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    client_id UUID NOT NULL,
    changed_by UUID,
    change_type VARCHAR(50),
    old_values JSONB,
    new_values JSONB,
    changed_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    reason TEXT,
    version INTEGER
);

CREATE TABLE IF NOT EXISTS core.client_versions (
    version_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    client_id UUID NOT NULL,
    version INTEGER NOT NULL,
    data JSONB NOT NULL,
    modified_by UUID,
    modified_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    reason_for_change TEXT
);

ALTER TABLE core.clients
ADD COLUMN IF NOT EXISTS branch_id UUID,
ADD CONSTRAINT fk_clients_branch FOREIGN KEY (branch_id) REFERENCES core.branches(id);

ALTER TABLE auth.users
ADD COLUMN IF NOT EXISTS branch_id UUID,
ADD CONSTRAINT fk_users_branch FOREIGN KEY (branch_id) REFERENCES core.branches(id);

-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
ALTER TABLE core.clients DROP CONSTRAINT IF EXISTS fk_clients_branch;
ALTER TABLE auth.users DROP CONSTRAINT IF EXISTS fk_users_branch;

ALTER TABLE core.clients DROP COLUMN IF EXISTS branch_id;
ALTER TABLE auth.users DROP COLUMN IF EXISTS branch_id;

DROP TABLE IF EXISTS core.client_versions;
DROP TABLE IF EXISTS core.client_profile_logs;
DROP TABLE IF EXISTS core.branches;
-- +goose StatementEnd
