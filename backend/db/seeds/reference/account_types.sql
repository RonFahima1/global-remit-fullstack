INSERT INTO core.account_types (id, type_code, name, description, features, restrictions, is_active)
VALUES
    (gen_random_uuid(), 'CHECKING', 'Checking Account', 'Standard checking account for daily transactions', '{}', '{}', true),
    (gen_random_uuid(), 'SAVINGS', 'Savings Account', 'Interest-bearing savings account', '{}', '{}', true),
    (gen_random_uuid(), 'LOAN', 'Loan Account', 'Account for loans and repayments', '{}', '{}', true),
    (gen_random_uuid(), 'CREDIT', 'Credit Account', 'Credit line account', '{}', '{}', true),
    (gen_random_uuid(), 'INVEST', 'Investment Account', 'Account for investments and securities', '{}', '{}', true)
ON CONFLICT (type_code)
DO UPDATE SET
    name = EXCLUDED.name,
    description = EXCLUDED.description,
    features = EXCLUDED.features,
    restrictions = EXCLUDED.restrictions,
    is_active = EXCLUDED.is_active,
    updated_at = NOW(); 