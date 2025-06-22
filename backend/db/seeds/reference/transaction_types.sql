INSERT INTO core.transaction_types (id, code, name, description, direction, affects_balance, requires_approval, is_active)
VALUES
    (gen_random_uuid(), 'DEPOSIT', 'Deposit', 'Deposit of funds', 'credit', true, false, true),
    (gen_random_uuid(), 'WITHDRAWAL', 'Withdrawal', 'Withdrawal of funds', 'debit', true, false, true),
    (gen_random_uuid(), 'TRANSFER', 'Transfer', 'Transfer between accounts', 'debit', true, false, true),
    (gen_random_uuid(), 'PAYMENT', 'Payment', 'Payment to third party', 'debit', true, false, true),
    (gen_random_uuid(), 'FEE', 'Fee', 'Bank fee or charge', 'debit', false, false, true),
    (gen_random_uuid(), 'INTEREST', 'Interest', 'Interest credit', 'credit', false, false, true),
    (gen_random_uuid(), 'REVERSAL', 'Reversal', 'Reversal of previous transaction', 'credit', true, true, true)
ON CONFLICT (code)
DO UPDATE SET
    name = EXCLUDED.name,
    description = EXCLUDED.description,
    direction = EXCLUDED.direction,
    affects_balance = EXCLUDED.affects_balance,
    requires_approval = EXCLUDED.requires_approval,
    is_active = EXCLUDED.is_active,
    updated_at = NOW(); 