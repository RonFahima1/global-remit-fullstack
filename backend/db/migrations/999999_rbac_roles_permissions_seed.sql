-- RBAC Migration: Canonical Roles, Permissions, and Mappings

-- 1. Remove legacy roles and permissions
DELETE FROM auth.role_permissions WHERE role_id NOT IN (SELECT id FROM auth.roles WHERE name IN ('ORG_ADMIN','AGENT_ADMIN','AGENT_USER','COMPLIANCE_USER','ORG_USER','GLOBAL_VIEWER'));
DELETE FROM auth.roles WHERE name NOT IN ('ORG_ADMIN','AGENT_ADMIN','AGENT_USER','COMPLIANCE_USER','ORG_USER','GLOBAL_VIEWER');
DELETE FROM auth.permissions WHERE code NOT IN (
  'users:create','users:read','users:update','users:delete',
  'roles:read','roles:update',
  'settings:update',
  'audit:read',
  'clients:create','clients:read','clients:update','clients:delete',
  'transactions:create','transactions:read','transactions:update','transactions:delete','transactions:approve',
  'kyc:approve',
  'reports:read',
  'profile:update'
);

-- 2. Insert canonical roles (idempotent)
INSERT INTO auth.roles (name, description, is_system)
VALUES
  ('ORG_ADMIN', 'Full organization admin', true),
  ('AGENT_ADMIN', 'Manages agents and teller users', true),
  ('AGENT_USER', 'Teller: can process transactions', true),
  ('COMPLIANCE_USER', 'Handles compliance reviews, KYC', true),
  ('ORG_USER', 'Regular org user: limited access', true),
  ('GLOBAL_VIEWER', 'View everything, no changes', true)
ON CONFLICT (name) DO NOTHING;

-- 3. Insert permission codes (idempotent)
INSERT INTO auth.permissions (code, name, description, category)
VALUES
  ('users:create', 'Create Users', 'Can create users', 'users'),
  ('users:read', 'Read Users', 'Can view users', 'users'),
  ('users:update', 'Update Users', 'Can update users', 'users'),
  ('users:delete', 'Delete Users', 'Can delete users', 'users'),
  ('roles:read', 'Read Roles', 'Can view roles', 'roles'),
  ('roles:update', 'Update Roles', 'Can update roles', 'roles'),
  ('settings:update', 'Update Settings', 'Can update settings', 'settings'),
  ('audit:read', 'Read Audit Logs', 'Can view audit logs', 'audit'),
  ('clients:create', 'Create Clients', 'Can create clients', 'clients'),
  ('clients:read', 'Read Clients', 'Can view clients', 'clients'),
  ('clients:update', 'Update Clients', 'Can update clients', 'clients'),
  ('clients:delete', 'Delete Clients', 'Can delete clients', 'clients'),
  ('transactions:create', 'Create Transactions', 'Can create transactions', 'transactions'),
  ('transactions:read', 'Read Transactions', 'Can view transactions', 'transactions'),
  ('transactions:update', 'Update Transactions', 'Can update transactions', 'transactions'),
  ('transactions:delete', 'Delete Transactions', 'Can delete transactions', 'transactions'),
  ('transactions:approve', 'Approve Transactions', 'Can approve transactions', 'transactions'),
  ('kyc:approve', 'Approve KYC', 'Can approve KYC', 'kyc'),
  ('reports:read', 'Read Reports', 'Can view reports', 'reports'),
  ('profile:update', 'Update Profile', 'Can update own profile', 'profile')
ON CONFLICT (code) DO NOTHING;

-- 4. Map permissions to roles (idempotent)
-- First, clear all role_permissions
DELETE FROM auth.role_permissions;

-- ORG_ADMIN: all permissions
INSERT INTO auth.role_permissions (role_id, permission_id)
SELECT r.id, p.id FROM auth.roles r, auth.permissions p WHERE r.name = 'ORG_ADMIN';

-- AGENT_ADMIN: all except roles:update, audit:read
INSERT INTO auth.role_permissions (role_id, permission_id)
SELECT r.id, p.id FROM auth.roles r, auth.permissions p
WHERE r.name = 'AGENT_ADMIN' AND p.code NOT IN ('roles:update','audit:read');

-- AGENT_USER: teller actions, view clients, view transactions, update profile
INSERT INTO auth.role_permissions (role_id, permission_id)
SELECT r.id, p.id FROM auth.roles r, auth.permissions p
WHERE r.name = 'AGENT_USER' AND p.code IN ('transactions:create','transactions:read','clients:read','reports:read','profile:update');

-- COMPLIANCE_USER: approve KYC, view reports, view transactions, update profile
INSERT INTO auth.role_permissions (role_id, permission_id)
SELECT r.id, p.id FROM auth.roles r, auth.permissions p
WHERE r.name = 'COMPLIANCE_USER' AND p.code IN ('kyc:approve','reports:read','transactions:read','profile:update');

-- ORG_USER: view only, update profile
INSERT INTO auth.role_permissions (role_id, permission_id)
SELECT r.id, p.id FROM auth.roles r, auth.permissions p
WHERE r.name = 'ORG_USER' AND p.code IN ('users:read','clients:read','transactions:read','reports:read','profile:update');

-- GLOBAL_VIEWER: all read-only permissions
INSERT INTO auth.role_permissions (role_id, permission_id)
SELECT r.id, p.id FROM auth.roles r, auth.permissions p
WHERE r.name = 'GLOBAL_VIEWER' AND p.code LIKE '%:read';

-- 5. (Optional) Seed demo users for each role (if not present)
-- (Assume user table has columns: id, email, password, status, created_at)
-- Passwords should be hashed using backend's bcrypt config; skip here for security.
-- Map demo users to roles in auth.user_roles as needed.
-- (Manual step or handled by backend seed logic) 