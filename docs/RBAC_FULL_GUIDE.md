# Full RBAC Implementation Guide (Go + Gin + PostgreSQL + JWT)

This guide provides a complete, practical, and detailed walkthrough for implementing a robust Role-Based Access Control (RBAC) system in your project. It covers database schema, permissions, roles, JWT structure, login flow, route protection, admin UI, and best practices.

---

## 1. Database Schema

**Core tables:**
- `roles`: System roles (e.g., admin, teller, manager)
- `permissions`: Actions/resources (e.g., users:create, clients:read)
- `role_permissions`: Mapping between roles and permissions
- `user_roles`: Mapping between users and roles

```sql
CREATE TABLE auth.roles (
    id SERIAL PRIMARY KEY,
    name VARCHAR(50) UNIQUE NOT NULL,
    description TEXT
);

CREATE TABLE auth.permissions (
    id SERIAL PRIMARY KEY,
    code VARCHAR(100) UNIQUE NOT NULL, -- e.g. 'users:create'
    name VARCHAR(100) NOT NULL,
    category VARCHAR(50)
);

CREATE TABLE auth.role_permissions (
    role_id INT REFERENCES auth.roles(id),
    permission_id INT REFERENCES auth.permissions(id),
    PRIMARY KEY (role_id, permission_id)
);

CREATE TABLE auth.user_roles (
    user_id UUID REFERENCES auth.users(id),
    role_id INT REFERENCES auth.roles(id),
    PRIMARY KEY (user_id, role_id)
);
```

---

## 2. Permissions by Page/Feature (Based on Actual App)

| Page/Section (Path)                | Permission Code              | Description                       |
|------------------------------------|------------------------------|-----------------------------------|
| **Dashboard** (`/dashboard`)       | dashboard:view               | View dashboard overview           |
| **User Management** (`/admin/users`, `/users`) | users:read, users:create, users:update, users:delete, users:invite, users:reset-password | Manage users, invite, edit, delete, reset password |
| **Role Management** (`/admin/roles`) | roles:read, roles:update     | View and manage roles/permissions |
| **Branches** (`/admin/branches`)   | branches:read, branches:update| View and manage branches          |
| **Currencies** (`/admin/currencies`)| currencies:read, currencies:update| View and manage currencies   |
| **Organization Settings** (`/admin/organization-settings`) | org-settings:read, org-settings:update | View/update org settings |
| **System Settings** (`/admin/system`, `/settings`) | settings:read, settings:update | View/update system settings |
| **Clients** (`/clients`)           | clients:read, clients:create, clients:update, clients:delete | Manage clients |
| **Client Balance** (`/client-balance`) | client-balance:read         | View client balances              |
| **Transactions** (`/transactions`, `/cash-register`, `/deposit`, `/withdrawal`, `/exchange`, `/send-money`, `/payout`) | transactions:read, transactions:create, transactions:update, transactions:delete, transactions:approve | Manage all transaction types |
| **Reports** (`/reports`)           | reports:read                 | View reports                      |
| **KYC** (`/kyc`, `/compliance`)    | kyc:read, kyc:approve        | View/approve KYC/compliance       |
| **Audit Log** (`/audit-log`)       | audit:read                   | View audit logs                   |
| **Profile** (`/profile`)           | profile:read, profile:update | View/update own profile           |
| **Teller** (`/teller`)             | teller:dashboard, teller:transact | Teller dashboard, perform teller actions |
| **Manager** (`/manager`)           | manager:dashboard            | Manager dashboard                 |
| **Limits** (`/limits`)             | limits:read, limits:update   | View/update transaction limits    |

> **Note:** For subpages (e.g., `/admin/users/create`), use the most specific permission (e.g., `users:create`).

---

## 3. Roles and Their Permissions (Actual App Roles)

### ORG_ADMIN (System Admin)
- All permissions (superuser)

### ORG_MANAGER
- dashboard:view
- users:read, users:create, users:update, users:invite
- clients:read, clients:create, clients:update
- transactions:read, transactions:approve
- reports:read
- kyc:read, kyc:approve
- profile:read, profile:update
- settings:read
- manager:dashboard

### TELLER
- dashboard:view
- clients:read
- transactions:read, transactions:create
- teller:dashboard, teller:transact
- profile:read, profile:update

### AUDITOR
- audit:read
- reports:read
- dashboard:view

### KYC_OFFICER
- kyc:read, kyc:approve
- clients:read
- dashboard:view

### COMPLIANCE_USER
- compliance:read
- kyc:read
- audit:read
- dashboard:view

### GLOBAL_VIEWER
- dashboard:view
- users:read
- clients:read
- transactions:read
- reports:read

---

## 4. JWT Structure and Login Flow

### JWT Claims Example
```json
{
  "user_id": "3191383c-b565-4135-a34c-ee9cd6987c91",
  "role": "ORG_ADMIN",
  "permissions": [
    "users:create",
    "users:read",
    ...
  ],
  ...
}
```

### Login Flow
1. User submits email and password.
2. Backend authenticates user and fetches all permissions from DB.
3. Backend issues JWT containing all permissions.
4. JWT is sent to the client and used for all subsequent requests.

---

## 5. Route Protection (Gin Example, Actual App)

```go
protected.GET("/dashboard", middleware.PermissionMiddleware("dashboard:view"), dashboardHandler.Page)
protected.GET("/admin/users", middleware.PermissionMiddleware("users:read"), adminUserHandler.List)
protected.POST("/admin/users", middleware.PermissionMiddleware("users:create"), adminUserHandler.Create)
protected.PUT("/admin/users/:id", middleware.PermissionMiddleware("users:update"), adminUserHandler.Update)
protected.DELETE("/admin/users/:id", middleware.PermissionMiddleware("users:delete"), adminUserHandler.Delete)
protected.POST("/admin/users/invite", middleware.PermissionMiddleware("users:invite"), adminUserHandler.Invite)
protected.POST("/admin/users/:id/reset-password", middleware.PermissionMiddleware("users:reset-password"), adminUserHandler.ResetPassword)
protected.GET("/admin/roles", middleware.PermissionMiddleware("roles:read"), adminRoleHandler.List)
protected.PUT("/admin/roles/:id", middleware.PermissionMiddleware("roles:update"), adminRoleHandler.Update)
protected.GET("/admin/branches", middleware.PermissionMiddleware("branches:read"), adminBranchHandler.List)
protected.PUT("/admin/branches/:id", middleware.PermissionMiddleware("branches:update"), adminBranchHandler.Update)
protected.GET("/admin/currencies", middleware.PermissionMiddleware("currencies:read"), adminCurrencyHandler.List)
protected.PUT("/admin/currencies/:id", middleware.PermissionMiddleware("currencies:update"), adminCurrencyHandler.Update)
protected.GET("/admin/organization-settings", middleware.PermissionMiddleware("org-settings:read"), orgSettingsHandler.View)
protected.PUT("/admin/organization-settings", middleware.PermissionMiddleware("org-settings:update"), orgSettingsHandler.Update)
protected.GET("/settings", middleware.PermissionMiddleware("settings:read"), settingsHandler.View)
protected.PUT("/settings", middleware.PermissionMiddleware("settings:update"), settingsHandler.Update)
protected.GET("/clients", middleware.PermissionMiddleware("clients:read"), clientHandler.List)
protected.POST("/clients", middleware.PermissionMiddleware("clients:create"), clientHandler.Create)
protected.PUT("/clients/:id", middleware.PermissionMiddleware("clients:update"), clientHandler.Update)
protected.DELETE("/clients/:id", middleware.PermissionMiddleware("clients:delete"), clientHandler.Delete)
protected.GET("/client-balance", middleware.PermissionMiddleware("client-balance:read"), clientBalanceHandler.View)
protected.GET("/transactions", middleware.PermissionMiddleware("transactions:read"), transactionHandler.List)
protected.POST("/transactions", middleware.PermissionMiddleware("transactions:create"), transactionHandler.Create)
protected.PUT("/transactions/:id", middleware.PermissionMiddleware("transactions:update"), transactionHandler.Update)
protected.DELETE("/transactions/:id", middleware.PermissionMiddleware("transactions:delete"), transactionHandler.Delete)
protected.POST("/transactions/:id/approve", middleware.PermissionMiddleware("transactions:approve"), transactionHandler.Approve)
protected.GET("/cash-register", middleware.PermissionMiddleware("transactions:read"), cashRegisterHandler.View)
protected.GET("/deposit", middleware.PermissionMiddleware("transactions:create"), depositHandler.View)
protected.GET("/withdrawal", middleware.PermissionMiddleware("transactions:create"), withdrawalHandler.View)
protected.GET("/exchange", middleware.PermissionMiddleware("transactions:read"), exchangeHandler.View)
protected.GET("/send-money", middleware.PermissionMiddleware("transactions:create"), sendMoneyHandler.View)
protected.GET("/payout", middleware.PermissionMiddleware("transactions:create"), payoutHandler.View)
protected.GET("/reports", middleware.PermissionMiddleware("reports:read"), reportHandler.List)
protected.GET("/kyc", middleware.PermissionMiddleware("kyc:read"), kycHandler.List)
protected.POST("/kyc/:id/approve", middleware.PermissionMiddleware("kyc:approve"), kycHandler.Approve)
protected.GET("/audit-log", middleware.PermissionMiddleware("audit:read"), auditLogHandler.List)
protected.GET("/profile", middleware.PermissionMiddleware("profile:read"), profileHandler.View)
protected.PUT("/profile", middleware.PermissionMiddleware("profile:update"), profileHandler.Update)
protected.GET("/teller", middleware.PermissionMiddleware("teller:dashboard"), tellerHandler.Dashboard)
protected.POST("/teller/transaction", middleware.PermissionMiddleware("teller:transact"), tellerHandler.Transact)
protected.GET("/manager", middleware.PermissionMiddleware("manager:dashboard"), managerHandler.Dashboard)
protected.GET("/limits", middleware.PermissionMiddleware("limits:read"), limitsHandler.View)
protected.PUT("/limits", middleware.PermissionMiddleware("limits:update"), limitsHandler.Update)
```

---

## 6. Admin UI for RBAC

- **Admin Dashboard**: `/admin` — quick links to all admin features (requires `dashboard:view` + relevant permissions)
- **User Management**: `/admin/users` — list, create, edit, delete, invite users (see permissions above)
- **Role Management**: `/admin/roles` — manage roles and permissions
- **Organization Settings**: `/admin/organization-settings` — org-level settings
- **Branches/Currencies**: `/admin/branches`, `/admin/currencies` — manage branches/currencies
- **System Settings**: `/admin/system`, `/settings` — system-wide settings

---

## 7. Best Practices

- **Always** check permissions at the route/controller level.
- **Never** trust only the frontend for access control.
- **Update JWT** only on login/refresh; changes in DB require re-login to take effect.
- **Log** all permission denials and suspicious access attempts.
- **Seed** your DB with default roles and permissions for new environments.

---

## 8. Full Flow Example

1. **User logs in** → JWT issued with all permissions.
2. **User requests a protected page** (e.g., /users):
   - Frontend checks if user has permission (optional, for UX)
   - Backend checks JWT and required permission via middleware
   - If allowed, handler executes; else, 403 Forbidden
3. **Admin changes a user's role**:
   - DB updated (user_roles, role_permissions)
   - User must re-login to get updated permissions in JWT

---

## 9. Extending the System

- Add new permissions by inserting into `auth.permissions`.
- Add new roles by inserting into `auth.roles` and mapping permissions.
- Protect new features by adding the relevant permission and using the middleware.

---

## 10. Troubleshooting

- If a user cannot access a page, check:
  - The user's roles and permissions in the DB
  - The JWT payload (permissions array)
  - The route's required permission
- If permissions change in DB, users must re-login to get a new JWT.

---

**This guide is designed to be a living document. Update it as your system grows!** 