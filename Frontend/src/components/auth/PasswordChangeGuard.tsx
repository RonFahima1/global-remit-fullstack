"use client";

import { useSession } from "next-auth/react";
import { useRouter, usePathname } from "next/navigation";
import { useEffect, useState } from "react";
import PasswordChangeForm from "./PasswordChangeForm";

interface PasswordChangeGuardProps {
  children: React.ReactNode;
}

export default function PasswordChangeGuard({ children }: PasswordChangeGuardProps) {
  const { data: session, status } = useSession();
  const router = useRouter();
  const pathname = usePathname();
  const [showPasswordForm, setShowPasswordForm] = useState(false);

  // Paths that don't require password change check
  const excludedPaths = [
    '/login',
    '/register',
    '/api',
    '/_next',
    '/favicon.ico',
  ];

  useEffect(() => {
    // Don't check on excluded paths
    if (excludedPaths.some(path => pathname?.startsWith(path))) {
      return;
    }

    // Wait for session to load
    if (status === 'loading') {
      return;
    }

    // If not authenticated, redirect to login
    if (status === 'unauthenticated') {
      router.push('/login');
      return;
    }

    // If authenticated and must change password, show password form
    if (session?.user?.mustChangePassword) {
      setShowPasswordForm(true);
    } else {
      setShowPasswordForm(false);
    }
  }, [session, status, pathname, router]);

  // Show loading while checking session
  if (status === 'loading') {
    return (
      <div className="min-h-screen flex items-center justify-center">
        <div className="animate-spin rounded-full h-32 w-32 border-b-2 border-gray-900"></div>
      </div>
    );
  }

  // Show password change form if required
  if (showPasswordForm) {
    return (
      <PasswordChangeForm 
        onSuccess={() => {
          setShowPasswordForm(false);
          // Refresh the page to update the session
          window.location.reload();
        }} 
      />
    );
  }

  // Show children if no password change required
  return <>{children}</>;
} 