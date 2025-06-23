import NextAuth, { type NextAuthOptions, type User } from "next-auth";
import CredentialsProvider from "next-auth/providers/credentials";
import { JWT } from "next-auth/jwt";

// Extend the User type to include custom fields
type CustomUser = User & {
  id: string;
  email: string;
  name?: string | null;
  role: string; // Make role required with a default value
  status: string; // Make status required with a default value
  permissions: string[];
};

// Extend the JWT type to include custom fields
interface CustomJWT extends JWT {
  user?: CustomUser;
}

// Log environment variables at startup
console.log('=== NextAuth Environment Variables ===');
console.log('NEXTAUTH_URL:', process.env.NEXTAUTH_URL);
console.log('BACKEND_URL:', process.env.BACKEND_URL);
console.log('NODE_ENV:', process.env.NODE_ENV);
console.log('NEXTAUTH_SECRET:', process.env.NEXTAUTH_SECRET ? '***' : 'Not set');
console.log('====================================');

// Log when this module is loaded
console.log('NextAuth route handler initialized at:', new Date().toISOString());

const authOptions: NextAuthOptions = {
  // Enable debug logging in development
  debug: true, // Always enable debug in development
  logger: {
    debug: (message: string, ...args: any[]) => {
      console.debug(`[next-auth:debug][${new Date().toISOString()}]`, message, ...args);
    },
    error: (message: string, ...args: any[]) => {
      console.error(`[next-auth:error][${new Date().toISOString()}]`, message, ...args);
    },
    warn: (message: string, ...args: any[]) => {
      console.warn(`[next-auth:warn][${new Date().toISOString()}]`, message, ...args);
    },
  },
  
  // Explicit cookie settings
  cookies: {
    sessionToken: {
      name: `__Secure-next-auth.session-token`,
      options: {
        httpOnly: true,
        sameSite: 'lax',
        path: '/',
        secure: process.env.NODE_ENV === 'production',
      },
    },
    callbackUrl: {
      name: `__Secure-next-auth.callback-url`,
      options: {
        httpOnly: true,
        sameSite: 'lax',
        path: '/',
        secure: process.env.NODE_ENV === 'production',
      },
    },
    csrfToken: {
      name: `__Host-next-auth.csrf-token`,
      options: {
        httpOnly: true,
        sameSite: 'lax',
        path: '/',
        secure: process.env.NODE_ENV === 'production',
      },
    },
  },
  
  providers: [
    CredentialsProvider({
      name: "credentials",
      credentials: {
        email: { label: "Email", type: "email" },
        password: { label: "Password", type: "password" }
      },
      
      async authorize(credentials: Record<string, string> | undefined, req: any) {
        try {
          console.log('\n========== AUTHORIZE FUNCTION CALLED ==========');
          console.log('Timestamp:', new Date().toISOString());
          console.log('Request URL:', req?.url);
          console.log('Request method:', req?.method);
          console.log('Request headers:', JSON.stringify(req?.headers, null, 2));
          console.log('Request body:', credentials ? { ...credentials, password: '***' } : 'No credentials');
          console.log('Environment:');
          console.log('- NODE_ENV:', process.env.NODE_ENV);
          console.log('- NEXTAUTH_URL:', process.env.NEXTAUTH_URL);
          console.log('- BACKEND_URL:', process.env.BACKEND_URL);
          console.log('==============================================\n');
          
          const backendUrl = process.env.BACKEND_URL || 'http://localhost:8080/api/v1';
          console.log('Backend URL:', backendUrl);
          
          if (!credentials || !credentials.email || !credentials.password) {
            console.error('Missing credentials in authorize function');
            console.log('Credentials object:', credentials);
            return null;
          }
          
          console.log('Sending login request to backend:', `${backendUrl}/auth/login`);
          const res = await fetch(`${backendUrl}/auth/login`, {
            method: 'POST',
            headers: { 
              'Content-Type': 'application/json',
              'X-Requested-With': 'XMLHttpRequest'
            },
            body: JSON.stringify({
              email: credentials.email,
              password: credentials.password,
            }),
          });

          const text = await res.text();
          console.log('Backend login response status:', res.status);
          console.log('Backend login response headers:', JSON.stringify([...res.headers.entries()]));
          console.log('Backend login response body:', text);

          if (!res.ok) {
            console.error('Backend login failed with status:', res.status);
            console.error('Backend error response:', text);
            throw new Error('Backend login failed: ' + text);
          }

          let data;
          try {
            data = JSON.parse(text);
            console.log('Successfully parsed backend response:', data);
          } catch (parseError) {
            console.error('Failed to parse backend response as JSON:', parseError);
            console.error('Response text:', text);
            throw new Error('Invalid response from authentication server');
          }
          
          // Fallback: if data.user is undefined but data.id and data.email exist, use data directly
          let user = data.user;
          if (!user && data.id && data.email) {
            console.log('Using direct user data as fallback');
            user = data;
          } else if (user) {
            console.log('Using user data from response.user');
          } else {
            console.warn('No valid user data found in response:', data);
          }
          
          console.log('User object to return:', user);
          if (!user || !user.id || !user.email) {
            console.log('Invalid user data');
            return null;
          }
          
          return {
            id: user.id.toString(),
            email: user.email,
            name: user.name || '',
            role: user.role || '',
            status: user.status || '',
            permissions: user.permissions || [],
          } as any;
        } catch (err) {
          console.error('AUTHORIZE ERROR', err);
          throw new Error('Authorize error: ' + (err instanceof Error ? err.message : JSON.stringify(err)));
        }
      },
    })
  ],
  pages: {
    signIn: "/login",
    error: "/login",
  },
  theme: {
    colorScheme: "light",
    logo: "/app-logo.png",
    brandColor: "#0070f3",
  },
  secret: process.env.NEXTAUTH_SECRET || 'your-secret-key',
  useSecureCookies: process.env.NODE_ENV === 'production',
  session: {
    strategy: "jwt" as const,
    maxAge: 30 * 60, // 30 minutes
    updateAge: 5 * 60, // 5 minutes - update the session every 5 minutes
  },
  // Use secure cookies in production
  useSecureCookies: process.env.NODE_ENV === 'production',
  // Trust the host in development for secure cookies
  // Note: trustHost is not a valid option in the current NextAuth version
  // It's handled automatically based on NEXTAUTH_URL
  callbacks: {
    async jwt({ token, user, trigger, session }) {
      // Initial sign in
      if (user) {
        const customUser = user as CustomUser;
        console.log('JWT callback - User signed in:', { user: customUser });
        return {
          ...token,
          id: customUser.id,
          email: customUser.email,
          name: customUser.name,
          role: customUser.role || 'user', // Default role
          status: customUser.status || 'active', // Default status
          permissions: customUser.permissions || [],
        };
      }

      // Update token from session if needed (e.g., when updating user data)
      if (trigger === 'update' && session) {
        console.log('JWT callback - Updating token from session:', { session });
        return { ...token, ...session.user };
      }

      return token;
    },
    async session({ session, token, user }) {
      console.log('Session callback - Token:', JSON.stringify(token, null, 2));
      
      // Add user data to session
      if (token) {
        session.user = {
          ...session.user,
          id: token.id as string,
          email: token.email as string,
          name: token.name ? String(token.name) : undefined,
          // Ensure role and status are always strings with defaults
          role: (token.role as string) || 'user',
          status: (token.status as string) || 'active',
          permissions: (token.permissions || []) as string[],
        };
      }
      
      console.log('Session callback - Final session:', JSON.stringify(session, null, 2));
      return session;
    },
    async redirect({ url, baseUrl }) {
      console.log('Redirect callback - Input:', { url, baseUrl });
      
      try {
        // If no callback URL is provided, redirect to dashboard
        if (!url) {
          console.log('No URL provided, redirecting to dashboard');
          return `${baseUrl}/dashboard`;
        }
        
        // If the URL is relative, make it absolute
        if (url.startsWith('/')) {
          const redirectUrl = `${baseUrl}${url}`;
          console.log('Redirecting to:', redirectUrl);
          return redirectUrl;
        } 
        // If the URL is on the same origin, allow it
        else if (url.startsWith(baseUrl)) {
          console.log('Redirecting to same origin:', url);
          return url;
        }
        // If the URL is a full URL to a different domain, log a warning and use dashboard
        else if (url.startsWith('http')) {
          console.warn('Attempted redirect to external URL, using dashboard instead');
          return `${baseUrl}/dashboard`;
        }
        
        // Default fallback to dashboard
        console.log('No matching redirect condition, using dashboard');
        return `${baseUrl}/dashboard`;
      } catch (error) {
        console.error('Error in redirect callback:', error);
        return `${baseUrl}/dashboard`;
      }
    },
  },

};

const handler = NextAuth(authOptions);
export { handler as GET, handler as POST }; 