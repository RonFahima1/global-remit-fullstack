-- Check user email, status, and password hash for test users
SELECT 
    email, 
    status, 
    failed_login_attempts,
    locked_until,
    substring(password_hash, 1, 30) || '...' as password_hash_preview,
    length(password_hash) as hash_length
FROM auth.users 
WHERE email IN (
    'orgadmin@example.com',
    'agentadmin@example.com',
    'agentuser@example.com',
    'complianceuser@example.com',
    'orguser@example.com'
);
