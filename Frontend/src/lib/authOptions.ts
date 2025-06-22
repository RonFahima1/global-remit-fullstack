import type { NextAuthOptions, User, Session } from "next-auth";
import CredentialsProvider from "next-auth/providers/credentials";

// API base URL from environment variables
const API_BASE_URL = process.env.NEXT_PUBLIC_API_URL || 'http://localhost:8080/api/v1';
console.log('NEXT_PUBLIC_API_URL:', process.env.NEXT_PUBLIC_API_URL);

declare module "next-auth" {
  interface Session {
    accessToken?: string;
    refreshToken?: string;
    error?: string;
    user: {
      id: string;
      email: string;
      name?: string;
      role: string;
      status?: string;
      mustChangePassword?: boolean;
      permissions?: string[];
    };
  }
}

export const authOptions: NextAuthOptions = {
  // Using JWT strategy for session management
  session: {
    strategy: "jwt",
    maxAge: 30 * 60, // 30 minutes
  },
  
  // Custom pages
  pages: {
    signIn: "/login",
    error: "/login",
  },
  providers: [
    CredentialsProvider({
      name: "credentials",
      credentials: {
        email: { label: "Email", type: "email" },
        password: { label: "Password", type: "password" }
      },
      async authorize(credentials) {
        console.log('AUTHORIZE FUNCTION CALLED', credentials);
        if (!credentials?.email || !credentials?.password) {
          console.log('Missing credentials');
          return null;
        }

        try {
          // Call the backend API for authentication
          const response = await fetch(`${API_BASE_URL}/auth/login`, {
            method: 'POST',
            headers: {
              'Content-Type': 'application/json',
            },
            body: JSON.stringify({
              email: credentials.email,
              password: credentials.password,
            }),
          });

          const data = await response.json();

          if (!response.ok) {
            console.log('Login failed:', data);
            // Handle specific error cases
            if (data.error === 'Account is locked') {
              throw new Error('Account is locked. Please contact support.');
            }
            if (data.error === 'invalid credentials') {
              throw new Error('Invalid email or password.');
            }
            throw new Error(data.error || 'Login failed');
          }

          // Check if user must change password
          if (data.user.must_change_password) {
            // Store the flag in the user object
            return {
              id: data.user.id || data.user.user_id,
              email: data.user.email,
              name: data.user.name || data.user.email,
              role: data.user.role,
              status: data.user.status,
              mustChangePassword: true,
              accessToken: data.accessToken,
              refreshToken: data.refreshToken,
              permissions: data.user.permissions || [],
            } as User & { 
              accessToken: string; 
              refreshToken: string; 
              mustChangePassword: boolean;
              permissions: string[];
            };
          }

          // Return the user object with tokens
          return {
            id: data.user.id || data.user.user_id,
            email: data.user.email,
            name: data.user.name || data.user.email,
            role: data.user.role,
            status: data.user.status,
            mustChangePassword: false,
            accessToken: data.accessToken,
            refreshToken: data.refreshToken,
            permissions: data.user.permissions || [],
          } as User & { 
            accessToken: string; 
            refreshToken: string; 
            mustChangePassword: boolean;
            permissions: string[];
          };
        } catch (error) {
          console.error('Authentication error:', error);
          throw error; // Re-throw to show error message
        }
      },
    }),
  ],
  callbacks: {
    async jwt({ token, user, account }) {
      // Initial sign in
      if (account && user) {
        return {
          ...token,
          accessToken: (user as any)?.accessToken,
          refreshToken: (user as any)?.refreshToken,
          role: user.role,
          id: user.id,
          mustChangePassword: (user as any)?.mustChangePassword || false,
          permissions: (user as any)?.permissions || [],
          expiresAt: Date.now() + 30 * 60 * 1000, // 30 minutes
        };
      }

      // Return previous token if the access token has not expired yet
      if (Date.now() < (token as any).expiresAt) {
        return token;
      }

      // Access token has expired, try to update it
      return refreshAccessToken(token);
    },
    async session({ session, token }) {
      if (session?.user) {
        session.user.id = (token.sub as string) || ((token as any).id as string) || '';
        session.user.role = (token as any).role || 'USER';
        session.user.mustChangePassword = (token as any).mustChangePassword || false;
        session.user.permissions = (token as any).permissions || [];
        session.accessToken = (token as any)?.accessToken as string || '';
        session.refreshToken = (token as any)?.refreshToken as string || '';
        session.error = (token as any)?.error as string || undefined;
      }
      return session;
    },
  },
};

// Helper to refresh the access token
async function refreshAccessToken(token: any) {
  try {
    const response = await fetch(`${API_BASE_URL}/auth/refresh`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({ refreshToken: token.refreshToken }),
      credentials: 'include',
    });

    const data = await response.json();

    if (!response.ok) {
      throw new Error((data.message as string) || 'Failed to refresh token');
    }

    return {
      ...token,
      accessToken: data.accessToken,
      refreshToken: data.refreshToken || token.refreshToken,
      expiresAt: Date.now() + (data.expiresIn || 1800) * 1000,
    };
  } catch (error) {
    console.error('Error refreshing access token:', error);
    return {
      ...token,
      error: 'RefreshAccessTokenError',
    };
  }
}