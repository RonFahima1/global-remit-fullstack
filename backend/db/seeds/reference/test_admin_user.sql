-- Insert a test admin user (email: admin@example.com, password: password)
INSERT INTO auth.users (
    id, username, email, email_verified, password_hash, status, first_name, last_name, created_at, updated_at
) VALUES (
    gen_random_uuid(), 'admin', 'admin@example.com', true, '$2b$12$u1Qw8Qw8Qw8Qw8Qw8Qw8QeQw8Qw8Qw8Qw8Qw8Qw8Qw8Qw8Qw8Qw8Q', 'ACTIVE', 'Admin', 'User', NOW(), NOW()
) ON CONFLICT (email) DO NOTHING;

-- Assign ORG_ADMIN role to the test user
INSERT INTO auth.user_roles (user_id, role_id)
SELECT u.id, r.id FROM auth.users u, auth.roles r
WHERE u.email = 'admin@example.com' AND r.name = 'ORG_ADMIN'
ON CONFLICT (user_id, role_id) DO NOTHING; 