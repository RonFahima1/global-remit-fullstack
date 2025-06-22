INSERT INTO core.branches (id, branch_name, branch_code, address, city, state, postal_code, country_code, phone, email, is_active)
VALUES
    (gen_random_uuid(), 'Main Branch', 'MAIN', '123 Main St', 'Metropolis', 'State', '12345', 'US', '+1-555-1000', 'main@bank.com', true),
    (gen_random_uuid(), 'Downtown Branch', 'DTWN', '456 Downtown Ave', 'Metropolis', 'State', '12346', 'US', '+1-555-2000', 'downtown@bank.com', true),
    (gen_random_uuid(), 'Uptown Branch', 'UPTN', '789 Uptown Blvd', 'Metropolis', 'State', '12347', 'US', '+1-555-3000', 'uptown@bank.com', true)
ON CONFLICT (branch_code)
DO UPDATE SET
    branch_name = EXCLUDED.branch_name,
    address = EXCLUDED.address,
    city = EXCLUDED.city,
    state = EXCLUDED.state,
    postal_code = EXCLUDED.postal_code,
    country_code = EXCLUDED.country_code,
    phone = EXCLUDED.phone,
    email = EXCLUDED.email,
    is_active = EXCLUDED.is_active,
    updated_at = NOW(); 