-- Add all roles used in the frontend
INSERT INTO auth.roles (name, description, is_system) VALUES
  ('ORG_ADMIN', 'Organization Admin', true),
  ('AGENT_ADMIN', 'Agent Admin', true),
  ('AGENT_USER', 'Agent User', true),
  ('COMPLIANCE_USER', 'Compliance User', true),
  ('ORG_USER', 'Organization User', true)
ON CONFLICT (name) DO NOTHING;

-- (Optional) Remove legacy roles if not used
-- DELETE FROM auth.roles WHERE name IN ('admin', 'teller', 'compliance', 'super_admin');

-- Assign ORG_USER to demo@example.com (update as needed for other users)
INSERT INTO auth.user_roles (user_id, role_id)
SELECT u.id, r.id
FROM auth.users u, auth.roles r
WHERE u.email = 'demo@example.com' AND r.name = 'ORG_USER'
ON CONFLICT DO NOTHING; 