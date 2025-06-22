INSERT INTO config.fee_structures (
    id, name, description, fee_type, calculation_method, is_active, applies_to_all_transaction_types, applies_to_all_account_types, applies_to_all_currencies, min_fee_amount, max_fee_amount, fee_percentage, fixed_fee_amount, fee_currency
) VALUES
    (gen_random_uuid(), 'Standard Transaction Fee', 'Flat fee for all transactions', 'transaction', 'fixed', true, true, true, true, 0.00, 10.00, NULL, 1.00, 'USD'),
    (gen_random_uuid(), 'Premium Account Fee', 'Monthly fee for premium accounts', 'account', 'fixed', true, false, false, true, 0.00, 50.00, NULL, 10.00, 'USD'),
    (gen_random_uuid(), 'International Transfer Fee', 'Percentage fee for international transfers', 'transaction', 'percentage', true, false, false, false, 0.00, 100.00, 0.5, NULL, 'USD')
ON CONFLICT (name)
DO UPDATE SET
    description = EXCLUDED.description,
    fee_type = EXCLUDED.fee_type,
    calculation_method = EXCLUDED.calculation_method,
    is_active = EXCLUDED.is_active,
    applies_to_all_transaction_types = EXCLUDED.applies_to_all_transaction_types,
    applies_to_all_account_types = EXCLUDED.applies_to_all_account_types,
    applies_to_all_currencies = EXCLUDED.applies_to_all_currencies,
    min_fee_amount = EXCLUDED.min_fee_amount,
    max_fee_amount = EXCLUDED.max_fee_amount,
    fee_percentage = EXCLUDED.fee_percentage,
    fixed_fee_amount = EXCLUDED.fixed_fee_amount,
    fee_currency = EXCLUDED.fee_currency,
    updated_at = NOW(); 