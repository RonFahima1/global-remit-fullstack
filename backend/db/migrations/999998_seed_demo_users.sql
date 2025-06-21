-- Insert demo users for each role
-- Password is 'Password123!' (bcrypt hash)
-- You may need to update the hash if your bcrypt cost changes

-- ORG_ADMIN
INSERT INTO auth.users (id, username, email, email_verified, password_hash, status, first_name, last_name, created_at, updated_at, version)
VALUES (gen_random_uuid(), 'orgadmin', 'orgadmin@example.com', true, '$2b$10$u1QwQwQwQwQwQwQwQwQwQeQwQwQwQwQwQwQwQwQwQwQwQwQwQwQw', 'ACTIVE', 'Org', 'Admin', NOW(), NOW(), 1)
ON CONFLICT (email) DO NOTHING;

-- AGENT_ADMIN
INSERT INTO auth.users (id, username, email, email_verified, password_hash, status, first_name, last_name, created_at, updated_at, version)
VALUES (gen_random_uuid(), 'agentadmin', 'agentadmin@example.com', true, '$2b$10$u1QwQwQwQwQwQwQwQwQwQeQwQwQwQwQwQwQwQwQwQwQwQwQwQwQw', 'ACTIVE', 'Agent', 'Admin', NOW(), NOW(), 1)
ON CONFLICT (email) DO NOTHING;

-- AGENT_USER
INSERT INTO auth.users (id, username, email, email_verified, password_hash, status, first_name, last_name, created_at, updated_at, version)
VALUES (gen_random_uuid(), 'agentuser', 'agentuser@example.com', true, '$2b$10$u1QwQwQwQwQwQwQwQwQwQeQwQwQwQwQwQwQwQwQwQwQwQwQwQwQw', 'ACTIVE', 'Agent', 'User', NOW(), NOW(), 1)
ON CONFLICT (email) DO NOTHING;

-- COMPLIANCE_USER
INSERT INTO auth.users (id, username, email, email_verified, password_hash, status, first_name, last_name, created_at, updated_at, version)
VALUES (gen_random_uuid(), 'complianceuser', 'complianceuser@example.com', true, '$2b$10$u1QwQwQwQwQwQwQwQwQwQeQwQwQwQwQwQwQwQwQwQwQwQwQwQwQw', 'ACTIVE', 'Compliance', 'User', NOW(), NOW(), 1)
ON CONFLICT (email) DO NOTHING;

-- ORG_USER
INSERT INTO auth.users (id, username, email, email_verified, password_hash, status, first_name, last_name, created_at, updated_at, version)
VALUES (gen_random_uuid(), 'orguser', 'orguser@example.com', true, '$2b$10$u1QwQwQwQwQwQwQwQwQwQeQwQwQwQwQwQwQwQwQwQwQwQwQwQwQw', 'ACTIVE', 'Org', 'User', NOW(), NOW(), 1)
ON CONFLICT (email) DO NOTHING;

-- Assign roles to users
INSERT INTO auth.user_roles (user_id, role_id)
SELECT u.id, r.id FROM auth.users u, auth.roles r WHERE u.email = 'orgadmin@example.com' AND r.name = 'ORG_ADMIN' ON CONFLICT DO NOTHING;
INSERT INTO auth.user_roles (user_id, role_id)
SELECT u.id, r.id FROM auth.users u, auth.roles r WHERE u.email = 'agentadmin@example.com' AND r.name = 'AGENT_ADMIN' ON CONFLICT DO NOTHING;
INSERT INTO auth.user_roles (user_id, role_id)
SELECT u.id, r.id FROM auth.users u, auth.roles r WHERE u.email = 'agentuser@example.com' AND r.name = 'AGENT_USER' ON CONFLICT DO NOTHING;
INSERT INTO auth.user_roles (user_id, role_id)
SELECT u.id, r.id FROM auth.users u, auth.roles r WHERE u.email = 'complianceuser@example.com' AND r.name = 'COMPLIANCE_USER' ON CONFLICT DO NOTHING;
INSERT INTO auth.user_roles (user_id, role_id)
SELECT u.id, r.id FROM auth.users u, auth.roles r WHERE u.email = 'orguser@example.com' AND r.name = 'ORG_USER' ON CONFLICT DO NOTHING; 