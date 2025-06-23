"use client";

import { Button } from "@/components/ui/button";
import { useToast } from "@/components/ui/use-toast";
import { 
  Bot, 
  UserCheck, 
  Loader2, 
  Server, 
  Monitor, 
  RefreshCw, 
  X, 
  Terminal,
  CheckCircle2,
  AlertCircle,
  Clock,
  ChevronDown,
  ChevronUp,
  XCircle,
  Check,
  Copy,
  LogIn
} from 'lucide-react';
import { useState, useRef, useEffect, useCallback } from "react";
import { signIn } from "next-auth/react";
import { useRouter } from "next/navigation";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import { cn } from '@/lib/utils';
import { ScrollArea } from '@/components/ui/scroll-area';

// Types
type LogLevel = 'info' | 'warn' | 'error' | 'debug';

interface LogEntry {
  timestamp: Date;
  level: LogLevel;
  message: string;
  data?: any;
}

interface HealthStatus {
  status: 'ok' | 'error' | 'checking';
  message: string;
  timestamp: string;
  service?: string;
  version?: string;
}

interface TestUser {
  id: string;
  email: string;
  role: string;
  password: string;
  label: string;
  color: string;
  icon: string;
  description: string;
};

// Test users configuration - must match seeded users in the database
// All users have password: 'password' (bcrypt hash: $2a$10$XFDq3wKmXldYHLsINnQx8uW5wvkAdgfKUkIDzW8kW8X8Jl9CoWb3a)
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
  onEmailChange: (email: string) => void;
  onPasswordChange: (password: string) => void;
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
  
  // State management
  const [activeTab, setActiveTab] = useState('health');
  const [loadingUser, setLoadingUser] = useState<string | null>(null);
  const [isExpanded, setIsExpanded] = useState(false);
  const [logs, setLogs] = useState<LogEntry[]>([]);
  const [healthStatus, setHealthStatus] = useState<HealthStatus>({
    status: 'checking',
    message: 'Checking service status...',
    timestamp: new Date().toISOString()
  });
  const [lastChecked, setLastChecked] = useState<string>('');
  const [isLoading, setIsLoading] = useState(false);
  const logsEndRef = useRef<HTMLDivElement>(null);

  // Add a log entry
  const addLog = useCallback((level: LogEntry['level'], message: string, data?: any) => {
    const entry: LogEntry = {
      timestamp: new Date(),
      level,
      message,
      data
    };
    setLogs(prev => [...prev, entry].slice(-100)); // Keep last 100 logs
  }, []);

  // Auto-scroll logs to bottom when new entries are added
  useEffect(() => {
    logsEndRef.current?.scrollIntoView({ behavior: 'smooth' });
  }, [logs]);

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

  const handleFormAutomation = async (user: TestUser) => {
    if (!emailRef.current || !passwordRef.current || !formRef.current) {
      throw new Error('Form elements not found');
    }

    addLog('info', `Attempting form automation for ${user.email}`);

    try {
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
      addLog('info', 'Form submitted successfully');
    } catch (error) {
      const errorMessage = error instanceof Error ? error.message : 'Unknown error';
      addLog('error', `Form automation failed: ${errorMessage}`, { error });
      throw error;
    }
  };

  const handleExpandToggle = () => {
    setIsExpanded(!isExpanded);
  };

  // Handle tab changes
  const handleTabChange = useCallback((value: string) => {
    setActiveTab(value);
  }, []);

  // Get color based on health status
  const getStatusColor = useCallback(() => {
    switch (healthStatus.status) {
      case 'ok': return 'bg-green-500';
      case 'error': return 'bg-red-500';
      case 'checking':
      default: return 'bg-yellow-500';
    }
  }, [healthStatus.status]);

  // Format time for display
  const formatTime = useCallback((dateString?: string) => {
    if (!dateString) return 'Never';
    const date = new Date(dateString);
    return date.toLocaleTimeString();
  }, []);

  // Clear all logs
  const clearLogs = useCallback(() => {
    setLogs([]);
    addLog('info', 'Logs cleared');
  }, []);

  // Check backend health
  const checkHealth = useCallback(async () => {
    setIsLoading(true);
    setHealthStatus(prev => ({
      ...prev,
      status: 'checking',
      message: 'Checking backend health...',
      timestamp: new Date().toISOString()
    }));

    try {
      const response = await fetch('/api/health');
      const data = await response.json();
      
      if (response.ok) {
        setHealthStatus({
          status: 'ok',
          message: 'Backend is healthy',
          timestamp: new Date().toISOString(),
          service: data.service || 'unknown',
          version: data.version || 'unknown'
        });
        addLog('info', 'Backend health check passed', data);
      } else {
        throw new Error(data.error || 'Health check failed');
      }
    } catch (error) {
      const errorMessage = error instanceof Error ? error.message : 'Unknown error';
      setHealthStatus(prev => ({
        ...prev,
        status: 'error',
        message: `Health check failed: ${errorMessage}`,
        timestamp: new Date().toISOString()
      }));
      addLog('error', 'Health check failed', { error: errorMessage });
    } finally {
      setIsLoading(false);
    }
  }, [addLog]);

  // Initialize component
  useEffect(() => {
    addLog('info', 'Developer Helper initialized');
    checkHealth();
  }, [addLog, checkHealth]);

  // Update last checked time when health status changes
  useEffect(() => {
    if (healthStatus.timestamp) {
      setLastChecked(healthStatus.timestamp);
    }
  }, [healthStatus]);

  // Only show in development
  if (process.env.NODE_ENV !== 'development') {
    return null;
  }

  return (
    <div className="fixed bottom-4 right-4 z-50">
      {/* Collapsed State */}
      {!isExpanded ? (
        <Button
          onClick={() => setIsExpanded(true)}
          className="bg-blue-600 hover:bg-blue-700 text-white rounded-full w-12 h-12 shadow-lg flex items-center justify-center"
          title="Developer Tools"
        >
          <Terminal size={20} />
        </Button>
      ) : (
        <div className="w-80 bg-white dark:bg-gray-800 rounded-lg shadow-lg border border-gray-200 dark:border-gray-700 overflow-hidden">
          <div className="px-4 py-3 bg-gray-50 dark:bg-gray-900 border-b border-gray-200 dark:border-gray-700 flex items-center justify-between">
            <div className="flex items-center space-x-2">
              <Terminal className="w-5 h-5 text-blue-500" />
              <h3 className="font-medium">Developer Tools</h3>
            </div>
            <div className="flex items-center space-x-2">
              <button
                onClick={checkHealth}
                disabled={isLoading}
                className="text-gray-400 hover:text-gray-600 dark:hover:text-gray-200 p-1"
                title="Refresh"
              >
                <RefreshCw className={`w-4 h-4 ${isLoading ? 'animate-spin' : ''}`} />
              </button>
              <button
                onClick={() => setIsExpanded(false)}
                className="text-gray-400 hover:text-gray-600 dark:hover:text-gray-200 p-1"
                title="Minimize"
              >
                <X className="w-4 h-4" />
              </button>
            </div>
          </div>

          <Tabs 
            value={activeTab} 
            onValueChange={handleTabChange}
            className="p-2"
          >
            <TabsList className="grid w-full grid-cols-3">
              <TabsTrigger value="health" className="text-xs">Health</TabsTrigger>
              <TabsTrigger value="logins" className="text-xs">Logins</TabsTrigger>
              <TabsTrigger value="logs" className="text-xs">Logs</TabsTrigger>
            </TabsList>

            <TabsContent value="health" className="mt-2 space-y-3 max-h-64 overflow-y-auto">
              <div className="space-y-2">
                <div className="flex items-center">
                  <div className={`w-2 h-2 rounded-full mr-2 ${getStatusColor()}`} />
                  <span className="text-sm font-medium">
                    {healthStatus.status === 'checking' ? 'Checking...' : healthStatus.message}
                  </span>
                </div>
                
                <div className="flex flex-col space-y-2">
                  <div className="flex items-center justify-between">
                    <div className="flex items-center space-x-2">
                      <Server className="w-4 h-4 text-gray-500" />
                      <span className="text-sm">Backend</span>
                    </div>
                    <span className={`text-xs px-2 py-0.5 rounded-full ${getStatusColor().replace('bg-', 'bg-opacity-20 text-')}`}>
                      {healthStatus.status === 'ok' ? 'Operational' : healthStatus.status === 'error' ? 'Degraded' : 'Checking...'}
                    </span>
                  </div>
                  
                  <div className="flex items-center justify-between">
                    <div className="flex items-center space-x-2">
                      <Monitor className="w-4 h-4 text-gray-500" />
                      <span className="text-sm">Frontend</span>
                    </div>
                    <span className="text-xs px-2 py-0.5 rounded-full bg-green-100 text-green-800 dark:bg-green-900/30 dark:text-green-400">
                      Operational
                    </span>
                  </div>
                </div>
                
                <div className="text-xs text-gray-500 dark:text-gray-400 mt-2 border-t border-gray-100 dark:border-gray-700 pt-2">
                  <p>Last checked: {lastChecked ? formatTime(lastChecked) : 'Never'}</p>
                  <p className="truncate">{healthStatus.message}</p>
                </div>
              </div>
            </TabsContent>

            <TabsContent value="logins" className="mt-2 space-y-2 max-h-64 overflow-y-auto">
              <p className="text-xs text-gray-500 dark:text-gray-400 mb-2">One-click login as:</p>
              <div className="space-y-2">
                {TEST_USERS.map((user) => (
                  <button
                    key={user.id}
                    onClick={() => handleOneClickLogin(user)}
                    disabled={!!loadingUser}
                    className={`w-full text-left p-2 rounded text-sm flex items-center space-x-2 ${user.color} text-white`}
                    title={user.description}
                  >
                    <span>{user.icon}</span>
                    <span className="flex-1">{user.label}</span>
                    <span className="text-xs opacity-75">({user.role})</span>
                    {loadingUser === user.id && (
                      <Loader2 className="w-3 h-3 animate-spin" />
                    )}
                  </button>
                ))}
              </div>
              <div className="text-xs text-gray-500 dark:text-gray-400 mt-2 pt-2 border-t border-gray-100 dark:border-gray-700">
                <p>All users: <span className="font-mono">password</span></p>
              </div>
            </TabsContent>

            <TabsContent value="logs" className="mt-2">
              <div className="flex justify-between items-center mb-2">
                <p className="text-xs text-gray-500 dark:text-gray-400">System logs:</p>
                <button 
                  onClick={clearLogs}
                  className="text-xs text-blue-500 hover:underline"
                >
                  Clear logs
                </button>
              </div>
              <div className="bg-black/80 text-green-400 font-mono text-xs p-2 rounded h-48 overflow-y-auto">
                {logs.length === 0 ? (
                  <p className="text-gray-500 italic">No logs yet</p>
                ) : (
                  <div className="space-y-1">
                    {logs.map((log, i) => (
                      <div key={i} className="flex">
                        <span className="text-gray-500 mr-2">
                          {log.timestamp.toLocaleTimeString()}
                        </span>
                        <span className={`${
                          log.level === 'error' ? 'text-red-400' : 
                          log.level === 'warn' ? 'text-yellow-400' : 'text-green-400'
                        }`}>
                          {log.message}
                        </span>
                      </div>
                    ))}
                    <div ref={logsEndRef} />
                  </div>
                )}
              </div>
            </TabsContent>
          </Tabs>
        </div>
      )}
    </div>
  );
} 