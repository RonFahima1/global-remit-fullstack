"use client";

import { Button } from "@/components/ui/button";
import { useToast } from "@/components/ui/use-toast";
import { Bot, UserCheck, Loader2 } from 'lucide-react';
import { useState } from "react";
import { signIn } from "next-auth/react";
import { useRouter } from "next/navigation";

// Test users configuration
const TEST_USERS = [
  {
    id: 'test-admin',
    email: 'test@example.com',
    role: 'ORG_ADMIN',
    password: 'Password123!',
    label: 'Test Admin',
    color: 'bg-blue-500 hover:bg-blue-600'
  },
  {
    id: 'org-admin',
    email: 'orgadmin@example.com',
    role: 'ORG_ADMIN',
    password: 'Password123!',
    label: 'Org Admin',
    color: 'bg-purple-500 hover:bg-purple-600'
  },
  {
    id: 'agent-admin',
    email: 'agentadmin@example.com',
    role: 'AGENT_ADMIN',
    password: 'Password123!',
    label: 'Agent Admin',
    color: 'bg-green-500 hover:bg-green-600'
  },
  {
    id: 'agent-user',
    email: 'agentuser@example.com',
    role: 'AGENT_USER',
    password: 'Password123!',
    label: 'Agent User',
    color: 'bg-orange-500 hover:bg-orange-600'
  },
  {
    id: 'compliance-user',
    email: 'complianceuser@example.com',
    role: 'COMPLIANCE_USER',
    password: 'Password123!',
    label: 'Compliance User',
    color: 'bg-red-500 hover:bg-red-600'
  },
  {
    id: 'org-user',
    email: 'orguser@example.com',
    role: 'ORG_USER',
    password: 'Password123!',
    label: 'Org User',
    color: 'bg-gray-500 hover:bg-gray-600'
  }
];

interface DeveloperLoginHelperProps {
  emailRef: React.RefObject<HTMLInputElement>;
  passwordRef: React.RefObject<HTMLInputElement>;
  formRef: React.RefObject<HTMLFormElement>;
  onEmailChange?: (email: string) => void;
  onPasswordChange?: (password: string) => void;
}

export function DeveloperLoginHelper({ 
  emailRef, 
  passwordRef, 
  formRef, 
  onEmailChange, 
  onPasswordChange 
}: DeveloperLoginHelperProps) {
  const { toast } = useToast();
  const router = useRouter();
  const [loadingUser, setLoadingUser] = useState<string | null>(null);
  const [isExpanded, setIsExpanded] = useState(false);

  // Show only in development mode
  if (process.env.NODE_ENV !== 'development') {
    return null;
  }

  const handleOneClickLogin = async (user: typeof TEST_USERS[0]) => {
    if (loadingUser) return; // Prevent multiple simultaneous logins
    
    setLoadingUser(user.id);
    
    toast({
      title: `Logging in as ${user.label}`,
      description: `Role: ${user.role}`,
    });

    try {
      // Attempt direct login using NextAuth
      const result = await signIn('credentials', {
        email: user.email,
        password: user.password,
        redirect: false,
        callbackUrl: '/dashboard'
      });

      if (result?.error) {
        throw new Error(result.error);
      }

      if (result?.ok) {
        toast({
          title: "✅ Login Successful!",
          description: `Welcome, ${user.label} (${user.role})`,
        });
        
        // Use window.location for reliable redirect
        window.location.href = '/dashboard';
      } else {
        throw new Error('Login failed - no response');
      }
      
    } catch (error) {
      console.error('One-click login error:', error);
      
      // Fallback: Try form automation
      try {
        await handleFormAutomation(user);
      } catch (fallbackError) {
        toast({
          variant: "destructive",
          title: "❌ Login Failed",
          description: `Failed to login as ${user.label}. Please try manually.`,
        });
      }
    } finally {
      setLoadingUser(null);
    }
  };

  const handleFormAutomation = async (user: typeof TEST_USERS[0]) => {
    if (!emailRef.current || !passwordRef.current || !formRef.current) {
      throw new Error('Form elements not found');
    }

    // Update React state
    if (onEmailChange) onEmailChange(user.email);
    if (onPasswordChange) onPasswordChange(user.password);

    // Update form fields
    emailRef.current.value = user.email;
    passwordRef.current.value = user.password;

    // Trigger change events
    emailRef.current.dispatchEvent(new Event('input', { bubbles: true }));
    passwordRef.current.dispatchEvent(new Event('input', { bubbles: true }));

    // Wait for state updates
    await new Promise(resolve => setTimeout(resolve, 100));

    // Submit form
    formRef.current.requestSubmit();
  };

  const handleExpandToggle = () => {
    setIsExpanded(!isExpanded);
  };

  return (
    <div className="fixed bottom-4 right-4 z-50">
      {/* Collapsed State */}
      {!isExpanded && (
        <Button
          onClick={handleExpandToggle}
          className="bg-blue-600 hover:bg-blue-700 text-white rounded-full w-12 h-12 shadow-lg"
          title="One-Click Login Helper"
        >
          <Bot size={20} />
        </Button>
      )}

      {/* Expanded State */}
      {isExpanded && (
        <div className="bg-white dark:bg-gray-800 rounded-lg shadow-2xl border border-gray-200 dark:border-gray-700 p-4 max-w-sm w-80">
          {/* Header */}
          <div className="flex items-center justify-between mb-4">
            <div className="flex items-center gap-2">
              <Bot size={20} className="text-blue-600" />
              <h3 className="font-bold text-gray-900 dark:text-gray-100">
                One-Click Login
              </h3>
            </div>
            <Button
              variant="ghost"
              size="sm"
              onClick={handleExpandToggle}
              className="h-6 w-6 p-0"
            >
              ×
            </Button>
          </div>

          {/* User Buttons */}
          <div className="space-y-2 max-h-64 overflow-y-auto">
            {TEST_USERS.map((user) => (
              <Button
                key={user.id}
                onClick={() => handleOneClickLogin(user)}
                disabled={!!loadingUser}
                className={`w-full justify-start text-left h-auto p-3 ${user.color} text-white border-0`}
              >
                <div className="flex items-center justify-between w-full">
                  <div className="flex items-center gap-2">
                    {loadingUser === user.id ? (
                      <Loader2 size={16} className="animate-spin" />
                    ) : (
                      <UserCheck size={16} />
                    )}
                    <div>
                      <div className="font-medium">{user.label}</div>
                      <div className="text-xs opacity-90">{user.role}</div>
                    </div>
                  </div>
                  {loadingUser === user.id && (
                    <div className="text-xs">Logging in...</div>
                  )}
                </div>
              </Button>
            ))}
          </div>

          {/* Footer */}
          <div className="mt-3 pt-3 border-t border-gray-200 dark:border-gray-700">
            <div className="text-xs text-gray-500 dark:text-gray-400 text-center">
              Development Mode • All users: Password123!
            </div>
          </div>
        </div>
      )}
    </div>
  );
} 