'use client'

import { toast } from 'react-hot-toast';

export function useToast() {
  return {
    success: (message: string, options?: { duration?: number }) => {
      return toast.success(message, options);
    },
    error: (message: string, options?: { duration?: number }) => {
      return toast.error(message, options);
    },
    info: (message: string, options?: { duration?: number }) => {
      return toast(message, options);
    },
    loading: (message: string, options?: { duration?: number }) => {
      return toast.loading(message, options);
    },
    dismiss: (id: string) => {
      return toast.dismiss(id);
    },
    toast: (args: { title: string; description?: string; variant?: string }) => {
      // For destructive variant, use error, else use success
      if (args.variant === 'destructive') {
        return toast.error(`${args.title}${args.description ? ': ' + args.description : ''}`);
      }
      return toast.success(`${args.title}${args.description ? ': ' + args.description : ''}`);
    },
  };
}
