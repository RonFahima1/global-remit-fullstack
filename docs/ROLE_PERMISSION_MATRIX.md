# Role-Based Access Control (RBAC) System

## 1. Roles & Descriptions

| Role            | Description                                                                 |
|-----------------|-----------------------------------------------------------------------------|
| ORG_ADMIN       | Full organization admin: manage users, settings, clients, transactions, etc.|
| AGENT_ADMIN     | Manages agents and teller users, limited org settings.                      |
| AGENT_USER      | Teller: can process transactions, view clients, limited create/edit.        |
| COMPLIANCE_USER | Handles compliance reviews, KYC, can view reports, limited edit.            |
| ORG_USER        | Regular org user: limited access, mostly view, some create.                 |
| GLOBAL_VIEWER   | **NEW:** Can view everything, cannot create/edit/delete/approve anything.   |

---

## 2. Page/Feature & Role Matrix

| Page/Feature         | ORG_ADMIN | AGENT_ADMIN | AGENT_USER | COMPLIANCE_USER | ORG_USER | GLOBAL_VIEWER |
|----------------------|:---------:|:-----------:|:----------:|:---------------:|:--------:|:-------------:|
| Dashboard            |   Full    |    Full     |   Full     |     Full        |  View    |     View      |
| Admin Panel          |   Full    |   Limited   |    -       |       -         |    -     |     View      |
| User Management      |   CRUD    |   CRUD      |    -       |       -         |    -     |     View      |
| Role Management      |   CRUD    |   View      |    -       |       -         |    -     |     View      |
| Settings             |   Full    |   Limited   |    -       |       -         |    -     |     View      |
| Audit Logs           |   View    |     -       |    -       |       -         |    -     |     View      |
| Manager Dashboard    |     -     |   Full      |    -       |       -         |    -     |     View      |
| Teller Dashboard     |     -     |     -       |   Full     |       -         |    -     |     View      |
| Compliance Dashboard |   View    |     -       |    -       |     Full        |    -     |     View      |
| Clients              |   CRUD    |   CRUD      |   View     |       -         |  View    |     View      |
| Exchange             |   CRUD    |   CRUD      |   View     |       -         |  View    |     View      |
| Payout               |   CRUD    |   CRUD      |   View     |       -         |  View    |     View      |
| Reports              |   View    |   View      |   View     |     View        |  View    |     View      |
| KYC                  | Approve   |     -       |    -       |   Approve       |    -     |     View      |
| Transactions         |   CRUD    |   CRUD      |   View     |     View        |  View    |     View      |
| Send Money           |   CRUD    |   CRUD      |   View     |       -         |  View    |     View      |
| Profile              |   Edit    |   Edit      |   Edit     |     Edit        |  Edit    |     View      |

**Legend:**
- **Full**: All actions (CRUD, manage, approve, etc.)
- **CRUD**: Create, Read, Update, Delete
- **View**: Read-only
- **Edit**: Can update own profile/settings
- **Approve**: Can approve/reject (e.g., KYC, compliance)
- **Limited**: Subset of actions (e.g., can manage users but not roles)
- **"-"**: No access

---

## 3. Permission Codes

- `users:create`, `users:read`, `users:update`, `users:delete`
- `roles:read`, `roles:update`
- `settings:update`
- `audit:read`
- `clients:create`, `clients:read`, `clients:update`, `clients:delete`
- `transactions:create`, `transactions:read`, `transactions:update`, `transactions:delete`, `transactions:approve`
- `kyc:approve`
- `reports:read`
- `profile:update`
- (Add more as needed for business logic)

---

## 4. UI/UX Guidelines

- **Role Indicator:**
  - Always show the current user’s role in the app header/sidebar.
- **Permission Feedback:**
  - Actions the user cannot perform are visible but grayed out/disabled, with a tooltip: “You do not have permission to perform this action.”
- **Navigation:**
  - Hide or disable navigation links to pages the user cannot access.
- **Global Viewer:**
  - All actions are disabled, all data is visible (read-only).

---

## 5. Implementation Notes

### Database
- Only the six roles above in `auth.roles`.
- All permission codes in `auth.permissions`.
- Map each role to its allowed permissions in `auth.role_permissions`.
- Every user must have one of these roles in `auth.user_roles`.
- Remove legacy roles/permissions, add new ones, update mappings.
- Seed demo users for each role.

### Backend
- Centralize permission checks in middleware/service.
- JWT/session must include role and permissions.
- All endpoints must check permissions, not just roles.
- Business logic must use permission codes.
- Admin APIs for managing roles/permissions, only accessible to ORG_ADMIN.
- Tests for all role/permission scenarios.
- Return clear forbidden/unauthorized errors.

### Frontend
- Store role and permissions in context, update on login/session refresh.
- Use a single source of truth for allowed roles/permissions per page.
- Show role indicator, gray out forbidden actions, show tooltips.
- Hide/disable navigation links for inaccessible pages.
- For `GLOBAL_VIEWER`, all actions are disabled, all data is visible (read-only).
- E2E and unit tests for all role/permission scenarios.

### Documentation
- Keep this file up to date.
- Explain all roles, permissions, and their mapping.
- Step-by-step for DB, backend, frontend changes.
- Manual and automated test instructions.
- Security best practices: least privilege, audit logging, etc. 