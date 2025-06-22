-- Insert one test user for each role
-- Password for all users: password

-- ORG_ADMIN
INSERT INTO auth.users (id, username, email, email_verified, password_hash, status, first_name, last_name, created_at, updated_at)
VALUES (gen_random_uuid(), 'orgadmin', 'orgadmin@example.com', true, '$2b$12$5RZp0YVAs0xNP18VEPz6tOIxEfRWkFXBpkkqCsDKF5MnjkzZCeKi.', 'ACTIVE', 'Org', 'Admin', NOW(), NOW())
ON CONFLICT (email) DO NOTHING;

-- AGENT_ADMIN
INSERT INTO auth.users (id, username, email, email_verified, password_hash, status, first_name, last_name, created_at, updated_at)
VALUES (gen_random_uuid(), 'agentadmin', 'agentadmin@example.com', true, '$2b$12$5RZp0YVAs0xNP18VEPz6tOIxEfRWkFXBpkkqCsDKF5MnjkzZCeKi.', 'ACTIVE', 'Agent', 'Admin', NOW(), NOW())
ON CONFLICT (email) DO NOTHING;

-- AGENT_USER
INSERT INTO auth.users (id, username, email, email_verified, password_hash, status, first_name, last_name, created_at, updated_at)
VALUES (gen_random_uuid(), 'agentuser', 'agentuser@example.com', true, '$2b$12$5RZp0YVAs0xNP18VEPz6tOIxEfRWkFXBpkkqCsDKF5MnjkzZCeKi.', 'ACTIVE', 'Agent', 'User', NOW(), NOW())
ON CONFLICT (email) DO NOTHING;

-- COMPLIANCE_USER
INSERT INTO auth.users (id, username, email, email_verified, password_hash, status, first_name, last_name, created_at, updated_at)
VALUES (gen_random_uuid(), 'complianceuser', 'complianceuser@example.com', true, '$2b$12$5RZp0YVAs0xNP18VEPz6tOIxEfRWkFXBpkkqCsDKF5MnjkzZCeKi.', 'ACTIVE', 'Compliance', 'User', NOW(), NOW())
ON CONFLICT (email) DO NOTHING;

-- ORG_USER
INSERT INTO auth.users (id, username, email, email_verified, password_hash, status, first_name, last_name, created_at, updated_at)
VALUES (gen_random_uuid(), 'orguser', 'orguser@example.com', true, '$2b$12$5RZp0YVAs0xNP18VEPz6tOIxEfRWkFXBpkkqCsDKF5MnjkzZCeKi.', 'ACTIVE', 'Org', 'User', NOW(), NOW())
ON CONFLICT (email) DO NOTHING;

-- GLOBAL_VIEWER
INSERT INTO auth.users (id, username, email, email_verified, password_hash, status, first_name, last_name, created_at, updated_at)
VALUES (gen_random_uuid(), 'viewer', 'viewer@example.com', true, '$2b$12$u1Qw8Qw8Qw8Qw8Qw8Qw8QeQw8Qw8Qw8Qw8Qw8Qw8Qw8Qw8Qw8Qw8Q', 'ACTIVE', 'Global', 'Viewer', NOW(), NOW())
ON CONFLICT (email) DO NOTHING;

-- Assign each user to their respective role
INSERT INTO auth.user_roles (user_id, role_id)
SELECT u.id, r.id FROM auth.users u, auth.roles r WHERE u.email = 'orgadmin@example.com' AND r.name = 'ORG_ADMIN' ON CONFLICT (user_id, role_id) DO NOTHING;
INSERT INTO auth.user_roles (user_id, role_id)
SELECT u.id, r.id FROM auth.users u, auth.roles r WHERE u.email = 'agentadmin@example.com' AND r.name = 'AGENT_ADMIN' ON CONFLICT (user_id, role_id) DO NOTHING;
INSERT INTO auth.user_roles (user_id, role_id)
SELECT u.id, r.id FROM auth.users u, auth.roles r WHERE u.email = 'agentuser@example.com' AND r.name = 'AGENT_USER' ON CONFLICT (user_id, role_id) DO NOTHING;
INSERT INTO auth.user_roles (user_id, role_id)
SELECT u.id, r.id FROM auth.users u, auth.roles r WHERE u.email = 'complianceuser@example.com' AND r.name = 'COMPLIANCE_USER' ON CONFLICT (user_id, role_id) DO NOTHING;
INSERT INTO auth.user_roles (user_id, role_id)
SELECT u.id, r.id FROM auth.users u, auth.roles r WHERE u.email = 'orguser@example.com' AND r.name = 'ORG_USER' ON CONFLICT (user_id, role_id) DO NOTHING;
INSERT INTO auth.user_roles (user_id, role_id)
SELECT u.id, r.id FROM auth.users u, auth.roles r WHERE u.email = 'viewer@example.com' AND r.name = 'GLOBAL_VIEWER' ON CONFLICT (user_id, role_id) DO NOTHING; 