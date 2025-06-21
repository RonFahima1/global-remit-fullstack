'use client';

import { createContext, useContext } from 'react';

export type UserRole = 'ORG_ADMIN' | 'AGENT_ADMIN' | 'AGENT_USER' | 'COMPLIANCE_USER' | 'ORG_USER';

export interface CurrentUser {
  id: string;
  email: string;
  role: UserRole;
  permissions: string[];
}

const mockCurrentUser: CurrentUser = {
  id: '1',
  email: 'admin@globalremit.com',
  role: 'ORG_ADMIN',
  permissions: [
    'manage_users',
    'manage_transactions',
    'manage_clients',
    'approve_kyc',
    'manage_compliance',
    'view_reports',
    'manage_settings',
  ]
};

export const CurrentUserContext = createContext<CurrentUser>(mockCurrentUser);

export function useCurrentUser() {
  return useContext(CurrentUserContext);
}

export function CurrentUserProvider({ children }: { children: React.ReactNode }) {
  // In a real app, fetch user from auth/session
  return (
    <CurrentUserContext.Provider value={mockCurrentUser}>
      {children}
    </CurrentUserContext.Provider>
  );
} 