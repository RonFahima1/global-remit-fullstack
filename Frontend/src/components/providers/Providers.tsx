'use client';

import { ThemeProvider } from 'next-themes';
import { SessionProvider } from 'next-auth/react';
import { LanguageProvider } from './LanguageProvider';
import { CurrentUserProvider } from '@/context/CurrentUserContext';
import { NotificationProvider } from '@/context/NotificationContext';
import { Toaster } from '@/components/ui/toaster';
import { Toaster as SonnerToaster } from 'sonner';

export function Providers({ children }: { children: React.ReactNode }) {
  return (
    <SessionProvider>
      <ThemeProvider attribute="class" defaultTheme="dark">
        <LanguageProvider>
          <CurrentUserProvider>
            <NotificationProvider>
              <>
                {children}
                <Toaster />
                <SonnerToaster position="top-right" />
              </>
            </NotificationProvider>
          </CurrentUserProvider>
        </LanguageProvider>
      </ThemeProvider>
    </SessionProvider>
  );
}