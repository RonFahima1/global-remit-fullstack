'use client';
import { useRouter } from "next/navigation";
import { useEffect, useState, useRef } from 'react';
import { useToast } from "@/components/ui/use-toast";
import { Banknote, Key, Eye, EyeOff, Loader2 } from "lucide-react";
import { motion, AnimatePresence } from "framer-motion";
import { signIn } from "next-auth/react";
import { DeveloperLoginHelper } from '@/components/auth/DeveloperLoginHelper';
import { Button } from '@/components/ui/button';
import { cn } from "@/lib/utils";
import { Logo } from "@/components/ui/logo";
import { Input } from '@/components/ui/input';
import { startAuthentication } from '@simplewebauthn/browser';

// Microsoft blue four-square logo (no wordmark)
function MicrosoftIcon({ className = "" }) {
  return (
    <svg className={className} width="22" height="22" viewBox="0 0 24 24" fill="none">
      <rect x="2" y="2" width="9" height="9" fill="#0078D4"/>
      <rect x="13" y="2" width="9" height="9" fill="#0078D4"/>
      <rect x="2" y="13" width="9" height="9" fill="#0078D4"/>
      <rect x="13" y="13" width="9" height="9" fill="#0078D4"/>
    </svg>
  );
}

const QUOTES = [
  {
    id: 1,
    text: "Global Remit made it so easy to support my family abroad. I feel secure and valued every step of the way.",
    author: "Maria, Customer"
  },
  {
    id: 2,
    text: "The interface is so intuitive, I can process transactions in seconds. It feels like using a native iOS app.",
    author: "Alex R., Operations Manager"
  },
  {
    id: 3,
    text: "I love the security and transparency. Global Remit is the gold standard for international transfers.",
    author: "Sam T., Branch Teller"
  }
];

export default function LoginPage() {
  const router = useRouter();
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [showPassword, setShowPassword] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [success, setSuccess] = useState<string | null>(null);
  const [passkeyLoading, setPasskeyLoading] = useState(false);
  const [passwordLoading, setPasswordLoading] = useState(false);
  const [loginMethod, setLoginMethod] = useState<'password' | 'passkey'>('password');
  const { success: toastSuccess, error: toastError, loading: toastLoading, dismiss: toastDismiss } = useToast();

  const emailRef = useRef<HTMLInputElement>(null);
  const passwordRef = useRef<HTMLInputElement>(null);
  const formRef = useRef<HTMLFormElement>(null);

  // Quote rotator
  const [quoteIdx, setQuoteIdx] = useState(0);
  useEffect(() => {
    const timer = setInterval(() => {
      setQuoteIdx((idx) => (idx + 1) % QUOTES.length);
    }, 5000);
    return () => clearInterval(timer);
  }, []);

  const handlePasswordLogin = async (e: React.FormEvent) => {
    console.log('=== handlePasswordLogin START ===');
    console.log('Event type:', e.type);
    console.log('Form values:', { email, password: password ? '[REDACTED]' : 'empty' });
    
    // Initialize toastId as an empty string
    let toastId = '';
    
    try {
      e.preventDefault();
      console.log('Prevented default form submission');
      
      setPasswordLoading(true);
      console.log('Set loading state to true');
      
      // Show loading toast and store the ID
      const newToastId = toastLoading("Signing in...");
      if (newToastId) {
        toastId = newToastId;
        console.log('Showing loading toast with ID:', toastId);
      } else {
        console.warn('Failed to create loading toast');
      }
      
      console.log('Calling signIn with credentials...');
      const result = await signIn('credentials', { 
        email, 
        password, 
        redirect: false, 
        callbackUrl: '/dashboard' 
      });
      
      console.log('=== signIn RESULT ===');
      console.log('Result received:', JSON.stringify(result, null, 2));
      console.log('Error property:', result?.error);
      console.log('OK property:', result?.ok);
      
      // Dismiss the loading toast if it exists
      if (toastId) {
        try {
          toastDismiss(toastId);
          console.log('Dismissed loading toast');
          toastId = ''; // Clear the toastId after dismissing
        } catch (toastError) {
          console.error('Error dismissing toast:', toastError);
        }
      }
      
      if (result) {
        if (result.error) {
          console.error('❌ Login error:', result.error);
          setError(result.error);
          toastError(`Login Failed: ${result.error}`);
        } else if (result.ok) {
          console.log('✅ Login successful, redirecting to dashboard');
          toastSuccess("Login Successful!");
          // Use window.location for reliable redirect
          const redirectUrl = result.url || '/dashboard';
          console.log('Redirecting to:', redirectUrl);
          window.location.href = redirectUrl;
        } else {
          console.error('❌ Unexpected result from signIn:', result);
          setError('Unexpected response from server');
          toastError('Login failed: Unexpected response');
        }
      } else {
        console.error('❌ No result returned from signIn');
        setError('No response from authentication service');
        toastError('Login failed: No response');
      }
    } catch (err) {
      console.error('Login error:', err);
      toastDismiss(toastId);
      const errorMessage = err instanceof Error ? err.message : 'An unknown error occurred';
      setError(errorMessage);
      toastError(`Login Failed: ${errorMessage}`);
    } finally {
      setPasswordLoading(false);
    }
  };

  const handlePasskeyLogin = async () => {
    if (!email) {
      setError('Please enter your email first');
      return;
    }

    try {
      setPasskeyLoading(true);
      setError(null);
      setSuccess(null);

      // Step 1: Generate authentication options
      const generateResponse = await fetch('/api/v1/passkey/authenticate', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ action: 'generate', email }),
      });

      if (!generateResponse.ok) {
        throw new Error('No passkeys found for this email');
      }

      const { options } = await generateResponse.json();

      // Step 2: Start authentication on the client
      const authenticationResponse = await startAuthentication(options);

      // Step 3: Verify authentication
      const verifyResponse = await fetch('/api/v1/passkey/authenticate', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ 
          action: 'verify', 
          email,
          response: authenticationResponse 
        }),
      });

      if (!verifyResponse.ok) {
        throw new Error('Passkey authentication failed');
      }

      const { user: userData } = await verifyResponse.json();
      
      // For demo purposes, we'll use the demo login
      await signIn('credentials', { email: 'demo@example.com', password: 'demo' });
      
    } catch (error) {
      console.error('Passkey login error:', error);
      setError(error instanceof Error ? error.message : 'Passkey authentication failed');
    } finally {
      setPasskeyLoading(false);
    }
  };

  const handleDemoLogin = async () => {
    setError(null);
    setSuccess(null);
    const loadingToast = toastLoading("Signing in as Demo User...");
    try {
      const result = await signIn('credentials', { 
        email: 'demo@example.com', 
        password: 'demo', 
        redirect: false, 
        callbackUrl: '/dashboard' 
      });
      toastDismiss(loadingToast);
      
      if (result?.error) {
        setError(result.error);
        toastError(`Demo Login Failed: ${result.error}`);
        return;
      }
      
      if (result?.ok) {
        toastSuccess("Demo Login Successful!");
        // Use window.location for reliable redirect
        window.location.href = '/dashboard';
      }
    } catch (err) {
      toastDismiss(loadingToast);
      setError('Demo login failed');
      toastError('Demo login failed');
    }
  };

  return (
    <div className="min-h-screen flex items-start justify-center bg-gradient-to-br from-[#F5F5F7] to-[#E5E5EA] dark:from-gray-900 dark:to-gray-800 pt-8 sm:pt-20 font-['-apple-system','BlinkMacSystemFont','SF Pro Text',sans-serif]">
      <div className="flex flex-col md:flex-row w-full max-w-5xl md:rounded-2xl rounded-xl shadow-[0_8px_32px_0_rgba(31,38,135,0.1)] dark:shadow-[0_8px_32px_0_rgba(0,0,0,0.3)] overflow-hidden bg-white/0 md:min-h-[350px] min-h-[55vh] mx-4">
        {/* Left: Blue Panel */}
        <div className="flex-1 bg-gradient-to-br from-[#0A84FF] to-[#007AFF] text-white flex flex-col justify-between p-4 sm:p-8 md:p-14 relative md:rounded-none rounded-t-xl md:rounded-l-3xl shadow-[0_8px_32px_0_rgba(10,132,255,0.1)] backdrop-blur-sm">
          {/* Top: Logo, Motto, Description */}
          <div>
            <div className="flex items-center gap-3 mb-10 transition-all duration-200 hover:scale-105">
              <div className="relative inline-block transition-transform duration-200">
                <img src="/app-logo.png" alt="Global Remit Logo" className="h-12 w-auto max-w-[96px]" />
              </div>
              <span className="font-bold text-2xl tracking-tight">Global Remit</span>
            </div>
            <div className="text-lg font-semibold mb-2">Beyond Banking</div>
            <div className="text-sm text-white/80">Fast, secure international money transfers</div>
            <div className="text-base opacity-90 mb-8 max-w-md">
              Your trusted partner for fast, secure international money transfers with competitive rates and robust compliance.
            </div>
          </div>
          {/* Bottom: Animated Inspiring Quote */}
          <div className="mt-10 min-h-[90px]">
            <AnimatePresence mode="wait">
              <motion.div
                key={QUOTES[quoteIdx].id}
                initial={{ opacity: 0 }}
                animate={{ opacity: 1 }}
                exit={{ opacity: 0 }}
                transition={{ duration: 0.8 }}
                className="italic text-white/70 text-base sm:text-lg"
              >
                "{QUOTES[quoteIdx].text}"
                <div className="mt-2 text-sm font-semibold opacity-80 not-italic">— {QUOTES[quoteIdx].author}</div>
              </motion.div>
            </AnimatePresence>
          </div>
        </div>
        {/* Right: Login Form */}
        <div className="flex-1 flex flex-col justify-center px-4 py-8 sm:px-8 sm:py-12 md:px-12 md:py-14 bg-white dark:bg-gray-900 transition-colors duration-300">
          <div className="w-full max-w-md mx-auto p-4 sm:p-8 md:p-10 flex flex-col gap-10 transition-all duration-200 relative">
            {/* Top divider only (no logo) */}
            <div className="flex flex-col items-center gap-2 mb-2">
              <span className="block w-10 h-1 rounded-full bg-gray-200/70 dark:bg-gray-700/70 mb-2" />
            </div>
            <div className="flex flex-col gap-1">
              <h2 className="text-2xl font-bold text-gray-900 dark:text-white text-center">Welcome Back</h2>
              <p className="text-gray-500 dark:text-gray-400 text-center">Sign in to your account</p>
            </div>

            {/* Login Method Tabs */}
            <div className="flex bg-gray-100 dark:bg-gray-800 rounded-lg p-1">
              <button
                onClick={() => setLoginMethod('password')}
                className={cn(
                  "flex-1 py-2 px-4 rounded-md text-sm font-medium transition-all",
                  loginMethod === 'password'
                    ? "bg-white dark:bg-gray-700 text-gray-900 dark:text-white shadow-sm"
                    : "text-gray-600 dark:text-gray-400 hover:text-gray-900 dark:hover:text-white"
                )}
              >
                Password
              </button>
              <button
                onClick={() => setLoginMethod('passkey')}
                className={cn(
                  "flex-1 py-2 px-4 rounded-md text-sm font-medium transition-all flex items-center justify-center gap-2",
                  loginMethod === 'passkey'
                    ? "bg-white dark:bg-gray-700 text-gray-900 dark:text-white shadow-sm"
                    : "text-gray-600 dark:text-gray-400 hover:text-gray-900 dark:hover:text-white"
                )}
              >
                <Key className="h-4 w-4" />
                Passkey
              </button>
            </div>

            {loginMethod === 'password' ? (
              <form 
                ref={formRef}
                key="password-form"
                className="space-y-6" 
                onSubmit={(e) => {
                  console.log('Form submitted, calling handlePasswordLogin...');
                  handlePasswordLogin(e).catch(err => {
                    console.error('Error in form submission:', err);
                    setError(err.message || 'An error occurred');
                    toastError('Login failed: ' + (err.message || 'Unknown error'));
                  });
                }}
                autoComplete="off"
              >
                <div className="flex flex-col gap-1">
                  <label htmlFor="email" className="text-sm font-medium text-gray-700 dark:text-gray-300">Email</label>
                  <Input
                    ref={emailRef}
                    id="email"
                    name="email"
                    type="email"
                    placeholder="Enter your email"
                    value={email}
                    onChange={(e: React.ChangeEvent<HTMLInputElement>) => setEmail(e.target.value)}
                    className="w-full h-14 px-5 rounded-xl border border-gray-200 dark:border-gray-700 bg-white/80 dark:bg-gray-800/80 focus:border-[#007AFF] focus:ring-2 focus:ring-[#007AFF]/40 transition-all text-base font-medium placeholder-gray-400 dark:placeholder-gray-500 hover:border-gray-300 dark:hover:border-gray-600 dark:text-white"
                    required
                  />
                </div>
                <div className="flex flex-col gap-1">
                  <label htmlFor="password" className="text-sm font-medium text-gray-700 dark:text-gray-300">Password</label>
                  <div className="relative">
                    <Input
                      ref={passwordRef}
                      id="password"
                      name="password"
                      type={showPassword ? "text" : "password"}
                      placeholder="Enter your password"
                      value={password}
                      onChange={(e: React.ChangeEvent<HTMLInputElement>) => setPassword(e.target.value)}
                      className="w-full h-14 px-5 rounded-xl border border-gray-200 dark:border-gray-700 bg-white/80 dark:bg-gray-800/80 focus:border-[#007AFF] focus:ring-2 focus:ring-[#007AFF]/40 transition-all text-base font-medium placeholder-gray-400 dark:placeholder-gray-500 hover:border-gray-300 dark:hover:border-gray-600 dark:text-white pr-12"
                      required
                    />
                    <button
                      type="button"
                      onClick={() => setShowPassword(!showPassword)}
                      className="absolute inset-y-0 right-0 flex items-center pr-4 text-gray-500 dark:text-gray-400"
                    >
                      {showPassword ? <EyeOff size={20} /> : <Eye size={20} />}
                    </button>
                  </div>
                </div>
                <div className="flex items-center justify-between">
                  <a href="#" className="text-sm font-medium text-[#007AFF] hover:underline">Forgot password?</a>
                </div>
                {error && (
                  <div className="py-2 px-3 rounded text-red-500 dark:text-red-400 text-sm bg-red-50 dark:bg-red-900/20 border border-red-100 dark:border-red-800/30 text-center">{error}</div>
                )}
                {success && (
                  <div className="py-2 px-3 rounded text-green-600 dark:text-green-400 text-sm bg-green-50 dark:bg-green-900/20 border border-green-100 dark:border-green-800/30 text-center">{success}</div>
                )}
                <div className="flex items-center justify-between">
                  <Button type="submit" className="w-full" disabled={passwordLoading}>
                    {passwordLoading ? (
                      <motion.div
                        animate={{ rotate: 360 }}
                        transition={{ repeat: Infinity, duration: 1, ease: "linear" }}
                      >
                        <Loader2 className="mr-2 h-4 w-4" />
                      </motion.div>
                    ) : (
                      "Sign In"
                    )}
                  </Button>
                </div>
              </form>
            ) : (
              <div className="text-center">
                <p className="mb-4 text-gray-600 dark:text-gray-400">Passkey login is not yet fully implemented.</p>
                <Button onClick={handlePasskeyLogin} disabled={passkeyLoading}>
                  {passkeyLoading ? 'Loading...' : 'Sign in with Passkey'}
                </Button>
              </div>
            )}

            <div className="relative flex items-center justify-center my-4">
              <span className="absolute inset-x-0 h-px bg-gray-200 dark:bg-gray-700"></span>
              <span className="relative bg-white dark:bg-gray-900 px-4 text-sm text-gray-500 dark:text-gray-400">Or continue with</span>
            </div>

            <div className="flex flex-col gap-4">
              <motion.div whileHover={{ scale: 1.02 }} whileTap={{ scale: 0.98 }}>
                <Button variant="outline" className="w-full flex items-center justify-center gap-2 h-12 rounded-xl" onClick={handleDemoLogin}>
                  <MicrosoftIcon className="h-5 w-5" />
                  Sign in with Microsoft
                </Button>
              </motion.div>
              <motion.div whileHover={{ scale: 1.02 }} whileTap={{ scale: 0.98 }}>
                <Button variant="outline" className="w-full flex items-center justify-center gap-2 h-12 rounded-xl" onClick={handleDemoLogin}>
                  Login as Demo User
                </Button>
              </motion.div>
            </div>

            {/* Footer */}
            <div className="mt-4 text-center text-xs text-gray-400 dark:text-gray-500">
              <span className="text-[10px] text-gray-300 dark:text-gray-600"> {new Date().getFullYear()} Global Remit</span>
            </div>
          </div>
        </div>
      </div>
      <DeveloperLoginHelper 
        emailRef={emailRef} 
        passwordRef={passwordRef} 
        formRef={formRef}
        onEmailChange={setEmail}
        onPasswordChange={setPassword}
      />
    </div>
  );
}
