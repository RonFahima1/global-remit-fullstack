import NextAuth from 'next-auth';
import CredentialsProvider from 'next-auth/providers/credentials';

const handler = NextAuth({
  providers: [
    CredentialsProvider({
      name: 'credentials',
      credentials: {
        email: { label: 'Email', type: 'email' },
        password: { label: 'Password', type: 'password' }
      },
      async authorize(credentials, req) {
        try {
          console.log('Authorize called with credentials:', credentials);
          if (!credentials || !credentials.email || !credentials.password) {
            console.error('Missing credentials:', credentials);
            throw new Error('Missing email or password');
          }
          const res = await fetch(`${process.env.BACKEND_URL}/api/v1/auth/login`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
              email: credentials.email,
              password: credentials.password,
            }),
          });

          if (!res.ok) {
            const errorText = await res.text();
            console.error('Backend login failed:', res.status, errorText);
            throw new Error(`Backend login failed: ${res.status} ${errorText}`);
          }

          const data = await res.json();
          console.log('Backend login response:', data);
          if (data && data.user && data.user.id && data.user.email) {
            return {
              id: data.user.id,
              email: data.user.email,
              name: data.user.name,
              accessToken: data.accessToken,
              refreshToken: data.refreshToken,
              ...data.user,
            };
          }
          console.error('Unexpected backend response:', data);
          throw new Error('Unexpected backend response: missing user info');
        } catch (err) {
          console.error('Authorize error:', err);
          throw err;
        }
      },
    })
  ],
  callbacks: {
    async jwt({ token, user }) {
      console.log('JWT callback:', { token, user });
      if (user) {
        token.accessToken = user.accessToken;
        token.refreshToken = user.refreshToken;
        token.user = user.user || user;
      }
      return token;
    },
    async session({ session, token }) {
      console.log('Session callback:', { session, token });
      session.accessToken = token.accessToken;
      session.refreshToken = token.refreshToken;
      session.user = token.user;
      return session;
    },
  },
  pages: {
    signIn: '/login',
    error: '/login',
  },
  session: {
    strategy: 'jwt',
    maxAge: 30 * 60,
  },
});

export { handler as GET, handler as POST }; 