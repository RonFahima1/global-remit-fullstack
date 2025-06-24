# Full RBAC Guide for Global Remit

## 1. Database Structure

- **Main Tables:**
  - `auth.users` — Users table.
  - `auth.roles` — Roles table.
  - `auth.permissions` — Permissions table.
  - `auth.user_roles` — User-to-role mapping.
  - `auth.role_permissions` — Role-to-permission mapping.

- **Example Permissions:**
  - `users:create`, `users:read`, `users:update`, `users:delete`
  - `roles:read`, `roles:update`
  - `clients:create`, `clients:read`, `clients:update`, `clients:delete`
  - `transactions:create`, `transactions:read`, `transactions:update`, `transactions:delete`, `transactions:approve`
  - `kyc:approve`, `reports:read`, `profile:update`, `settings:update`, `audit:read`

---

## 2. Main Roles

- **ORG_ADMIN** — Organization admin, has all permissions.
- **ORG_USER** — Regular organization user, basic permissions.
- **AGENT_ADMIN** — Branch/agent admin.
- **AGENT_USER** — Branch/agent user.
- **COMPLIANCE_USER** — Compliance/regulation user.
- **SUPPORT_USER** — Support.

---

## 3. Creating a New Admin User

### a. Create the user in Postgres (via Docker):

```sh
docker compose exec postgres psql -U postgres -d global_remit -c "CREATE EXTENSION IF NOT EXISTS pgcrypto;"
docker compose exec postgres psql -U postgres -d global_remit -c "INSERT INTO auth.users (id, email, username, first_name, last_name, password_hash, status) VALUES (gen_random_uuid(), 'superadmin@example.com', 'superadmin', 'Super', 'Admin', crypt('Password123!', gen_salt('bf')), 'ACTIVE');"
```

### b. Assign the ORG_ADMIN role:

```sh
docker compose exec postgres psql -U postgres -d global_remit -c "INSERT INTO auth.user_roles (user_id, role_id) SELECT id, (SELECT id FROM auth.roles WHERE name = 'ORG_ADMIN') FROM auth.users WHERE email = 'superadmin@example.com' ON CONFLICT (user_id, role_id) DO NOTHING;"
```

### c. Test login:

```sh
curl -X POST http://localhost:8080/api/v1/auth/login -H 'Content-Type: application/json' -d '{"email":"superadmin@example.com","password":"Password123!"}'
```

---

## 4. Verifying Permissions

- A successful login will return a JWT with `role: ORG_ADMIN` and all permissions.
- You can also check permissions directly in the DB:
```sh
docker compose exec postgres psql -U postgres -d global_remit -c "SELECT p.code FROM auth.users u JOIN auth.user_roles ur ON u.id = ur.user_id JOIN auth.roles r ON ur.role_id = r.id JOIN auth.role_permissions rp ON r.id = rp.role_id JOIN auth.permissions p ON rp.permission_id = p.id WHERE u.email = 'superadmin@example.com';"
```

---

## 5. Troubleshooting

- **Login fails or wrong permissions:**  
  Make sure the Docker DB is the same one you are using in your CLI.  
  Ensure `user_roles` and `role_permissions` tables are up to date.
- **Adding new permissions:**  
  Add new permissions to `auth.permissions` and map them in `auth.role_permissions`.
- **Adding users:**  
  Always use a strong password and assign the correct role.
- **Enable pgcrypto:**  
  You must run `CREATE EXTENSION IF NOT EXISTS pgcrypto;` before using `crypt`.

---

## 6. Production Best Practices

- Never leave test endpoints open in production.
- Set `GIN_MODE=release` in production.
- Use strong passwords and assign only the minimum required permissions.
- Always run a full seed for roles and permissions with a proper seed script.

---

## 7. Example: Mapping Permissions to Main Pages

| Page/Feature            | Required Permission(s)      | Allowed Roles                |
|-------------------------|----------------------------|------------------------------|
| User Management         | users:read                 | ORG_ADMIN, AGENT_ADMIN       |
| Create User             | users:create               | ORG_ADMIN                    |
| Update User             | users:update               | ORG_ADMIN, AGENT_ADMIN       |
| Reports                 | reports:read               | ORG_ADMIN, ORG_USER          |
| Client Management       | clients:read               | ORG_ADMIN, ORG_USER          |
| KYC Approval            | kyc:approve                | COMPLIANCE_USER              |
| Role Management         | roles:read, roles:update   | ORG_ADMIN                    |
| System Settings         | settings:update            | ORG_ADMIN                    |

---

## 8. Advanced Tips

- You can add users via the Admin UI (if available).
- Always separate dev/prod environments and ensure proper seeding for each.
- Use Redis for session/token management if required.

---

## 9. Example JWT Structure

```json
{
  "user_id": "9497c7ab-628b-420f-87dd-678bd0a197e8",
  "role": "ORG_ADMIN",
  "permissions": [
    "users:create",
    "users:read",
    ...
  ],
  "exp": 1750719456
}
```

---

## 10. Summary

- Every user must be assigned a role.
- Every role must be mapped to permissions.
- Always check that your Docker DB is the same as your CLI DB.
- Only update/create users in the correct DB.
- Close all dangerous/test endpoints in production.

---

If you need a more detailed guide, code examples, or help writing a full seed script — just ask! 