"use client";

import type { ReactNode } from 'react';
import AppLayout from '@/components/layout/AppLayout';
import { CustomSidebarProvider } from '@/components/providers/SidebarProvider';
import { SearchProvider } from '@/components/providers/SearchProvider';

export default function AppAreaLayout({ children }: { children: ReactNode }) {
  return (
    <CustomSidebarProvider>
      <SearchProvider>
        <AppLayout>{children}</AppLayout>
      </SearchProvider>
    </CustomSidebarProvider>
  );
}

