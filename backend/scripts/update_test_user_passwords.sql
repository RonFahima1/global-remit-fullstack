-- Update all test users to use 'password' as their password
UPDATE auth.users 
SET 
    password_hash = '$2a$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', -- bcrypt hash of 'password'
    updated_at = NOW()
WHERE email IN (
    'orgadmin@example.com',
    'agentadmin@example.com',
    'agentuser@example.com',
    'complianceuser@example.com',
    'orguser@example.com'
);

-- Verify the updates
SELECT email, substring(password_hash, 1, 10) || '...' as password_hash_preview 
FROM auth.users 
WHERE email IN (
    'orgadmin@example.com',
    'agentadmin@example.com',
    'agentuser@example.com',
    'complianceuser@example.com',
    'orguser@example.com'
);
