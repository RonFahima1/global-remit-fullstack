'use client';

import { ThemeProvider } from 'next-themes';
import { SessionProvider } from 'next-auth/react';
import { LanguageProvider } from './LanguageProvider';
import { CurrentUserProvider } from '@/context/CurrentUserContext';
import { NotificationProvider } from '@/context/NotificationContext';
import { Toaster } from '@/components/ui/toaster';
import { Toaster as SonnerToaster } from 'sonner';
import PasswordChangeGuard from '@/components/auth/PasswordChangeGuard';

export function Providers({ children }: { children: React.ReactNode }) {
  return (
    <SessionProvider>
      <ThemeProvider attribute="class" defaultTheme="dark">
        <LanguageProvider>
          <CurrentUserProvider>
            <NotificationProvider>
              <PasswordChangeGuard>
              <>
                {children}
                <Toaster />
                <SonnerToaster position="top-right" />
              </>
              </PasswordChangeGuard>
            </NotificationProvider>
          </CurrentUserProvider>
        </LanguageProvider>
      </ThemeProvider>
    </SessionProvider>
  );
}