import { signIn, signOut, useSession } from 'next-auth/react';
import { useRouter } from 'next/navigation';

export const useAuth = () => {
  const { data: session, status } = useSession();
  const router = useRouter();

  const login = async (email: string, password: string) => {
    try {
      const result = await signIn('credentials', {
        redirect: false,
        email,
        password,
        callbackUrl: '/dashboard',
      });

      if (result?.error) {
        throw new Error(result.error);
      }

      // If we got here, login was successful
      router.push('/dashboard');
      router.refresh();
      return { success: true };
    } catch (error) {
      console.error('Login failed:', error);
      return { 
        success: false, 
        error: error instanceof Error ? error.message : 'Login failed' 
      };
    }
  };

  const logout = async () => {
    try {
      // Clear the session on the client side
      await signOut({ 
        redirect: false,
        callbackUrl: '/login'
      });
      
      // Redirect to login page
      router.push('/login');
      router.refresh();
    } catch (error) {
      console.error('Logout failed:', error);
      throw error;
    }
  };

  return {
    user: session?.user,
    isAuthenticated: status === 'authenticated',
    isLoading: status === 'loading',
    login,
    logout,
  };
};