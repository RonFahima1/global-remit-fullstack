"use client";

import { Button } from "@/components/ui/button";
import { useToast } from "@/components/ui/use-toast";
import { Bot, UserCheck, Loader2 } from 'lucide-react';
import { useState, useRef } from "react";
import { signIn } from "next-auth/react";
import { useRouter } from "next/navigation";

// Test users configuration - must match seeded users in the database
// All users have password: 'password'
const TEST_USERS = [
  {
    id: 'org-admin',
    email: 'orgadmin@example.com',
    role: 'ORG_ADMIN',
    password: 'password',
    label: 'Org Admin',
    color: 'bg-purple-600 hover:bg-purple-700',
    icon: '👑',
    description: 'Full system access with administrative privileges'
  },
  {
    id: 'agent-admin',
    email: 'agentadmin@example.com',
    role: 'AGENT_ADMIN',
    password: 'password',
    label: 'Agent Admin',
    color: 'bg-green-600 hover:bg-green-700',
    icon: '🛡️',
    description: 'Manage agents and view all agent activities'
  },
  {
    id: 'agent-user',
    email: 'agentuser@example.com',
    role: 'AGENT_USER',
    password: 'password',
    label: 'Agent',
    color: 'bg-blue-600 hover:bg-blue-700',
    icon: '👤',
    description: 'Standard agent with transaction capabilities'
  },
  {
    id: 'compliance-user',
    email: 'complianceuser@example.com',
    role: 'COMPLIANCE_USER',
    password: 'password',
    label: 'Compliance',
    color: 'bg-yellow-600 hover:bg-yellow-700',
    icon: '🔍',
    description: 'Review and approve transactions'
  },
  {
    id: 'org-user',
    email: 'orguser@example.com',
    role: 'ORG_USER',
    password: 'password',
    label: 'Org User',
    color: 'bg-gray-600 hover:bg-gray-700',
    icon: '👥',
    description: 'Basic organization user with limited access'
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
  // We don't need to store toast references since we're not manually dismissing toasts

  // Developer login helper is now visible in all environments for testing purposes

  const handleOneClickLogin = async (user: typeof TEST_USERS[0]) => {
    if (loadingUser) return; // Prevent multiple simultaneous logins
    
    setLoadingUser(user.id);
    
      // Show loading toast
    toast({
      title: `🔐 Logging in...`,
      description: `Signing in as ${user.label} (${user.role})`,
      variant: 'default',
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
        // Handle specific error cases
        let errorMessage = result.error;
        if (result.error.includes('password')) {
          errorMessage = 'Incorrect password';
        } else if (result.error.includes('locked')) {
          errorMessage = 'Account is temporarily locked';
        }
        throw new Error(errorMessage);
      }

      if (result?.ok) {
        // Show success toast
        toast({
          title: "✅ Login Successful",
          description: `Welcome, ${user.label} (${user.role})`,
          variant: 'default',
        });
        
        // Small delay before redirect to show success message
        await new Promise(resolve => setTimeout(resolve, 500));
        window.location.href = '/dashboard';
      } else {
        throw new Error('Login failed - no response from server');
      }
      
    } catch (error) {
      console.error('One-click login error:', error);
      
      // Fallback: Try form automation
      try {
        toast({
          title: "🔄 Trying alternative login method...",
          description: `Attempting to sign in as ${user.label}`,
          variant: 'default',
        });
        
        await handleFormAutomation(user);
      } catch (fallbackError) {
        console.error('Fallback login error:', fallbackError);
        toast({
          variant: "destructive",
          title: "❌ Login Failed",
          description: `Failed to login as ${user.label}: ${error instanceof Error ? error.message : 'Unknown error'}`,
        });
        // Error handling complete
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
                className={`w-full justify-start text-left h-auto p-3 ${user.color} text-white border-0 transition-all hover:shadow-md`}
              >
                <div className="flex items-center justify-between w-full">
                  <div className="flex items-center gap-3">
                    <div className="text-xl">{user.icon}</div>
                    <div>
                      <div className="font-medium flex items-center gap-2">
                        {loadingUser === user.id && (
                          <Loader2 size={14} className="animate-spin" />
                        )}
                        {user.label}
                      </div>
                      <div className="text-xs opacity-90 mt-0.5">{user.role}</div>
                      <div className="text-xs opacity-70 mt-1 line-clamp-1">{user.description}</div>
                    </div>
                  </div>
                  <div className="text-xs bg-black/10 dark:bg-white/10 px-2 py-1 rounded">
                    {user.email.split('@')[0]}
                  </div>
                </div>
              </Button>
            ))}
          </div>

          {/* Footer */}
          <div className="mt-4 pt-3 border-t border-gray-200 dark:border-gray-700">
            <div className="text-xs text-gray-500 dark:text-gray-400 text-center space-y-1">
              <div>Development Mode • All users: <span className="font-mono">password</span></div>
              <div className="text-2xs opacity-75">Click any user to log in automatically</div>
            </div>
          </div>
        </div>
      )}
    </div>
  );
} 