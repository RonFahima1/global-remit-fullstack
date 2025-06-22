-- +goose Up
-- +goose StatementBegin
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.table_constraints
        WHERE constraint_name = 'uq_account_holder' AND table_name = 'account_holders' AND table_schema = 'core'
    ) THEN
        ALTER TABLE core.account_holders ADD CONSTRAINT uq_account_holder UNIQUE (account_id, client_id, holder_type);
    END IF;
END$$;
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.table_constraints
        WHERE constraint_name = 'chk_holder_type' AND table_name = 'account_holders' AND table_schema = 'core'
    ) THEN
        ALTER TABLE core.account_holders ADD CONSTRAINT chk_holder_type CHECK (holder_type IN ('PRIMARY', 'JOINT', 'AUTHORIZED', 'BENEFICIARY', 'POWER_OF_ATTORNEY'));
    END IF;
END$$;
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.table_constraints
        WHERE constraint_name = 'chk_removal_date' AND table_name = 'account_holders' AND table_schema = 'core'
    ) THEN
        ALTER TABLE core.account_holders ADD CONSTRAINT chk_removal_date CHECK ((removed_date IS NULL) OR (removed_date IS NOT NULL AND removed_date >= added_date));
    END IF;
END$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
ALTER TABLE core.account_holders DROP CONSTRAINT IF EXISTS uq_account_holder;
ALTER TABLE core.account_holders DROP CONSTRAINT IF EXISTS chk_holder_type;
ALTER TABLE core.account_holders DROP CONSTRAINT IF EXISTS chk_removal_date;
-- +goose StatementEnd
