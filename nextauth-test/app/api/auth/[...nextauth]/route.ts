import NextAuth from "next-auth";
import CredentialsProvider from "next-auth/providers/credentials";

const handler = NextAuth({
  providers: [
    CredentialsProvider({
      name: "Credentials",
      credentials: {
        email: { label: "Email", type: "email" },
        password: { label: "Password", type: "password" },
      },
      async authorize(credentials) {
        // Always return a hardcoded user
        return {
          id: "1",
          email: credentials?.email || "test@example.com",
          name: "Test User",
        };
      },
    }),
  ],
  session: {
    strategy: "jwt",
  },
  secret: "test-secret-key",
});

export { handler as GET, handler as POST }; 