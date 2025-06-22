// Permission mapping for frontend route/page access and feature control
// This should be imported wherever permission checks are needed

export const PAGE_PERMISSIONS: Record<string, string[]> = {
  // Dashboard: all roles have some access, no granular permission needed
  "/dashboard": [],
  // Admin Panel and subpages
  "/admin": ["settings:update", "roles:read"],
  "/admin/organization-settings": ["settings:update"],
  "/admin/users": ["users:read"],
  "/admin/product": ["settings:update"],
  "/admin/exchange-rates": ["settings:update"],
  "/admin/operator": ["users:read"],
  // User Management
  "/admin/users/create": ["users:create"],
  "/admin/users/update": ["users:update"],
  "/admin/users/delete": ["users:delete"],
  // Role Management
  "/admin/roles": ["roles:read"],
  "/admin/roles/update": ["roles:update"],
  // Settings/Profile
  "/settings": ["settings:update"],
  "/settings/profile": ["profile:update"],
  // Audit Logs
  "/admin/audit-logs": ["audit:read"],
  // Teller Dashboard (role-based, AGENT_USER)
  "/dashboard/teller": [],
  // Compliance Dashboard (role-based, COMPLIANCE_USER)
  "/dashboard/compliance": [],
  // Clients
  "/clients": ["clients:read"],
  "/clients/create": ["clients:create"],
  "/clients/update": ["clients:update"],
  "/clients/delete": ["clients:delete"],
  // Exchange
  "/exchange": ["transactions:create", "transactions:read"],
  // Payout
  "/payout": ["transactions:create", "transactions:read"],
  // Reports
  "/reports": ["reports:read"],
  // KYC
  "/kyc": ["kyc:approve"],
  // Transactions
  "/transactions": ["transactions:read"],
  "/transactions/create": ["transactions:create"],
  "/transactions/update": ["transactions:update"],
  "/transactions/delete": ["transactions:delete"],
  "/transactions/approve": ["transactions:approve"],
  // Send Money
  "/send-money": ["transactions:create"],
};

// Utility: check if user has permission for a page/feature
export function hasPagePermission(userPermissions: string[], page: string): boolean {
  const required = PAGE_PERMISSIONS[page] || [];
  if (required.length === 0) return true; // No specific permission required
  return required.some(perm => userPermissions.includes(perm) || userPermissions.includes("*:*"));
} 