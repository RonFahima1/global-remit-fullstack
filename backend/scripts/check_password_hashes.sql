-- Check password hashes for test users
SELECT 
    email,
    password_hash,
    CASE 
        WHEN password_hash LIKE '$2a$10$u1QwQwQwQwQwQwQwQwQwQeQwQwQwQwQwQwQwQwQwQwQwQwQwQwQw' THEN 'INVALID_HASH'
        ELSE 'VALID_HASH'
    END as hash_status
FROM auth.users 
WHERE email IN (
    'orgadmin@example.com',
    'agentadmin@example.com',
    'agentuser@example.com',
    'complianceuser@example.com',
    'orguser@example.com'
);
