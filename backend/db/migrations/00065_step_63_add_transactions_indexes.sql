-- +goose Up
-- step_63: Add recommended indexes to core.transactions

-- +goose StatementBegin
CREATE INDEX idx_transactions_transaction_type_id ON core.transactions (transaction_type_id);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE INDEX idx_transactions_parent_transaction_id ON core.transactions (parent_transaction_id);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE INDEX idx_transactions_related_transaction_id ON core.transactions (related_transaction_id);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE INDEX idx_transactions_branch_id ON core.transactions (branch_id);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE INDEX idx_transactions_teller_id ON core.transactions (teller_id);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE INDEX idx_transactions_created_by ON core.transactions (created_by);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE INDEX idx_transactions_updated_by ON core.transactions (updated_by);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE INDEX idx_transactions_status_transaction_date ON core.transactions (status, transaction_date DESC);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE INDEX idx_transactions_teller_id_transaction_date ON core.transactions (teller_id, transaction_date DESC);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE INDEX idx_transactions_branch_id_transaction_date ON core.transactions (branch_id, transaction_date DESC);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE INDEX idx_transactions_created_at_desc ON core.transactions (created_at DESC);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE INDEX idx_transactions_transaction_date ON core.transactions (transaction_date);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE INDEX idx_transactions_status_branch_transaction_date ON core.transactions (status, branch_id, transaction_date DESC);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE INDEX idx_transactions_status_teller_transaction_date ON core.transactions (status, teller_id, transaction_date DESC);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE INDEX idx_transactions_pending_status ON core.transactions (status) WHERE status = 'pending';
-- +goose StatementEnd

-- +goose Down
-- Remove indexes if rolling back
-- +goose StatementBegin
DROP INDEX IF EXISTS core.idx_transactions_transaction_type_id;
-- +goose StatementEnd
-- +goose StatementBegin
DROP INDEX IF EXISTS core.idx_transactions_parent_transaction_id;
-- +goose StatementEnd
-- +goose StatementBegin
DROP INDEX IF EXISTS core.idx_transactions_related_transaction_id;
-- +goose StatementEnd
-- +goose StatementBegin
DROP INDEX IF EXISTS core.idx_transactions_branch_id;
-- +goose StatementEnd
-- +goose StatementBegin
DROP INDEX IF EXISTS core.idx_transactions_teller_id;
-- +goose StatementEnd
-- +goose StatementBegin
DROP INDEX IF EXISTS core.idx_transactions_created_by;
-- +goose StatementEnd
-- +goose StatementBegin
DROP INDEX IF EXISTS core.idx_transactions_updated_by;
-- +goose StatementEnd
-- +goose StatementBegin
DROP INDEX IF EXISTS core.idx_transactions_status_transaction_date;
-- +goose StatementEnd
-- +goose StatementBegin
DROP INDEX IF EXISTS core.idx_transactions_teller_id_transaction_date;
-- +goose StatementEnd
-- +goose StatementBegin
DROP INDEX IF EXISTS core.idx_transactions_branch_id_transaction_date;
-- +goose StatementEnd
-- +goose StatementBegin
DROP INDEX IF EXISTS core.idx_transactions_created_at_desc;
-- +goose StatementEnd
-- +goose StatementBegin
DROP INDEX IF EXISTS core.idx_transactions_transaction_date;
-- +goose StatementEnd
-- +goose StatementBegin
DROP INDEX IF EXISTS core.idx_transactions_status_branch_transaction_date;
-- +goose StatementEnd
-- +goose StatementBegin
DROP INDEX IF EXISTS core.idx_transactions_status_teller_transaction_date;
-- +goose StatementEnd
-- +goose StatementBegin
DROP INDEX IF EXISTS core.idx_transactions_pending_status;
-- +goose StatementEnd 