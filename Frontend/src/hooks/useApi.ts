import { useCallback } from 'react';
import apiClient, { AxiosRequestConfig } from '@/lib/api-client';
import { useSession } from 'next-auth/react';

interface ApiResponse<T> {
  data: T | null;
  error: string | null;
  loading: boolean;
}

type CustomRequestInit = Omit<RequestInit, 'body' | 'method' | 'headers'> & {
  body?: any;
  headers?: Record<string, string>;
};

interface UseApiOptions extends CustomRequestInit {
  requireAuth?: boolean;
}

const useApi = () => {
  const { data: session, status } = useSession();
  const isLoading = status === 'loading';

  const request = useCallback(
    async <T = any>(
      endpoint: string,
      options: UseApiOptions = {}
    ): Promise<{ data: T | null; error: string | null }> => {
      const { requireAuth = true, ...fetchOptions } = options;
      const accessToken = (session as any)?.accessToken || (session as any)?.user?.accessToken;

      if (requireAuth && !accessToken && !isLoading) {
        return { data: null, error: 'Not authenticated' };
      }

      try {
        const config: AxiosRequestConfig = {
          ...fetchOptions,
          url: endpoint,
          method: fetchOptions.method as any,
          data: fetchOptions.body,
          headers: {
            'Content-Type': 'application/json',
            ...fetchOptions.headers,
            ...(accessToken && {
              Authorization: `Bearer ${accessToken}`,
            }),
          },
        };

        const response = await apiClient.request<T>(config);

        return { data: response.data, error: null };
      } catch (error: any) {
        console.error('API request failed:', error);
        
        // Handle different types of errors
        let errorMessage = 'An unexpected error occurred';
        
        if (error.response) {
          // The request was made and the server responded with a status code
          // that falls out of the range of 2xx
          errorMessage = error.response.data?.message || error.response.statusText;
        } else if (error.request) {
          // The request was made but no response was received
          errorMessage = 'No response from server';
        }
        
        return { data: null, error: errorMessage };
      }
    },
    [session?.accessToken, isLoading]
  );

  return {
    get: <T = any>(endpoint: string, options?: Omit<UseApiOptions, 'body'>) =>
      request<T>(endpoint, { ...options, method: 'GET' }),
    
    post: <T = any>(endpoint: string, data?: any, options?: Omit<UseApiOptions, 'body'>) =>
      request<T>(endpoint, { ...options, method: 'POST', body: data }),
    
    put: <T = any>(endpoint: string, data?: any, options?: Omit<UseApiOptions, 'body'>) =>
      request<T>(endpoint, { ...options, method: 'PUT', body: data }),
    
    del: <T = any>(endpoint: string, options?: Omit<UseApiOptions, 'body'>) =>
      request<T>(endpoint, { ...options, method: 'DELETE' }),
    
    patch: <T = any>(endpoint: string, data?: any, options?: Omit<UseApiOptions, 'body'>) =>
      request<T>(endpoint, { ...options, method: 'PATCH', body: data }),
  };
};

export default useApi;
