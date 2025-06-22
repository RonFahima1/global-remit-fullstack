-- Reset test users status and failed login attempts
UPDATE auth.users 
SET 
    status = 'ACTIVE',
    failed_login_attempts = 0,
    locked_until = NULL,
    updated_at = NOW()
WHERE email IN (
    'orgadmin@example.com',
    'agentadmin@example.com',
    'agentuser@example.com',
    'complianceuser@example.com',
    'orguser@example.com'
);

-- Verify the changes
SELECT email, status, failed_login_attempts, locked_until 
FROM auth.users 
WHERE email IN (
    'orgadmin@example.com',
    'agentadmin@example.com',
    'agentuser@example.com',
    'complianceuser@example.com',
    'orguser@example.com'
);
