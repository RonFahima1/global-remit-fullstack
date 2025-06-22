-- +goose Up
-- +goose StatementBegin
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.table_constraints
        WHERE constraint_name = 'fk_clients_branch' AND table_name = 'clients' AND table_schema = 'core'
    ) THEN
        ALTER TABLE core.clients
            ADD CONSTRAINT fk_clients_branch FOREIGN KEY (branch_id) REFERENCES core.branches(id);
    END IF;
END$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
ALTER TABLE core.clients DROP CONSTRAINT IF EXISTS fk_clients_branch;
-- +goose StatementEnd
