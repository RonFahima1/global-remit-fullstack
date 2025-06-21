import NextAuth, { NextAuthOptions } from "next-auth";
import CredentialsProvider from "next-auth/providers/credentials";

const authOptions: NextAuthOptions = {
  providers: [
    CredentialsProvider({
      name: "credentials",
      credentials: {
        email: { label: "Email", type: "email" },
        password: { label: "Password", type: "password" }
      },
      async authorize(credentials: Record<string, string> | undefined, req: any) {
        try {
          const backendUrl = process.env.BACKEND_URL || 'http://localhost:8080/api/v1';
          console.log('AUTHORIZE CALLED', credentials, backendUrl);
          
          if (!credentials || !credentials.email || !credentials.password) {
            console.log('Missing credentials');
            return null;
          }
          
          const res = await fetch(`${backendUrl}/auth/login`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
              email: credentials.email,
              password: credentials.password,
            }),
          });

          const text = await res.text();
          console.log('Login response:', res.status, text);

          if (!res.ok) {
            console.error('Backend login failed:', res.status, text);
            throw new Error('Backend login failed: ' + text);
          }

          const data = JSON.parse(text);
          console.log('Parsed backend data:', data);
          
          // Fallback: if data.user is undefined but data.id and data.email exist, use data directly
          let user = data.user;
          if (!user && data.id && data.email) {
            user = data;
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
    signIn: "http://localhost:3000/login",
    error: "http://localhost:3000/login",
  },
  session: {
    strategy: "jwt" as const,
    maxAge: 30 * 60,
  },
  callbacks: {
    async jwt({ token, user }: { token: any, user?: any }) {
      if (user) {
        token.id = user.id;
        token.email = user.email;
        token.name = user.name;
        token.role = user.role;
        token.status = user.status;
        token.permissions = user.permissions;
      }
      return token;
    },
    async session({ session, token }: { session: any, token: any }) {
      if (token) {
        session.user.id = token.id;
        session.user.email = token.email;
        session.user.name = token.name;
        session.user.role = token.role;
        session.user.status = token.status;
        session.user.permissions = token.permissions;
      }
      return session;
    },
    async redirect({ url, baseUrl }) {
      // Handle redirects properly
      console.log('Redirect callback:', { url, baseUrl });
      
      // If the URL is relative, make it absolute
      if (url.startsWith('/')) {
        return `${baseUrl}${url}`;
      }
      
      // If the URL is on the same origin, allow it
      if (url.startsWith(baseUrl)) {
        return url;
      }
      
      // Default to dashboard
      return `${baseUrl}/dashboard`;
    },
  },
  debug: process.env.NODE_ENV === 'development',
};

const handler = NextAuth(authOptions);
export { handler as GET, handler as POST }; 