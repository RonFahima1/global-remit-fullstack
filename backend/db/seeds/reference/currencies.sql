INSERT INTO config.currencies (code, name, symbol, decimal_places, is_active, is_base_currency)
VALUES 
    ('USD', 'United States Dollar', '$', 2, true, true),
    ('EUR', 'Euro', '€', 2, true, false),
    ('JPY', 'Japanese Yen', '¥', 0, true, false),
    ('GBP', 'British Pound', '£', 2, true, false),
    ('AUD', 'Australian Dollar', '$', 2, true, false),
    ('CAD', 'Canadian Dollar', '$', 2, true, false)
ON CONFLICT (code) 
DO UPDATE SET 
    name = EXCLUDED.name,
    symbol = EXCLUDED.symbol,
    decimal_places = EXCLUDED.decimal_places,
    is_active = EXCLUDED.is_active,
    is_base_currency = EXCLUDED.is_base_currency,
    updated_at = NOW();
