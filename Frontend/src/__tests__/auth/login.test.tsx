/**
 * @jest-environment jsdom
 */
import React from 'react';
import { render, screen, fireEvent, waitFor } from '@testing-library/react';
import { LoginForm } from '@/components/auth/login-form';
import { useRouter } from 'next/navigation';
import { signIn } from 'next-auth/react';
import { toast } from 'react-hot-toast';

// Mock Next.js router
jest.mock('next/navigation', () => ({
  useRouter: jest.fn(),
}));

// Mock NextAuth
jest.mock('next-auth/react', () => ({
  signIn: jest.fn(),
}));

// Mock react-hot-toast
jest.mock('react-hot-toast', () => ({
  toast: {
    success: jest.fn(),
    error: jest.fn(),
  },
}));

// Mock AuthContext
const mockLogin = jest.fn();
const mockUseAuth = jest.fn(() => ({
  login: mockLogin,
  loading: false,
  user: null,
}));

jest.mock('@/context/AuthContext', () => ({
  useAuth: () => mockUseAuth(),
}));

describe('LoginForm', () => {
  const mockRouter = {
    push: jest.fn(),
    refresh: jest.fn(),
  };

  beforeEach(() => {
    jest.clearAllMocks();
    (useRouter as jest.Mock).mockReturnValue(mockRouter);
    mockUseAuth.mockReturnValue({
      login: mockLogin,
      loading: false,
      user: null,
    });
  });

  it('should render login form with all required fields', () => {
    render(<LoginForm />);
    
    expect(screen.getByLabelText(/email/i)).toBeInTheDocument();
    expect(screen.getByLabelText(/password/i)).toBeInTheDocument();
    expect(screen.getByRole('button', { name: /login/i })).toBeInTheDocument();
    expect(screen.getByRole('button', { name: /try demo/i })).toBeInTheDocument();
  });

  it('should handle successful login with AuthContext', async () => {
    mockLogin.mockResolvedValueOnce(undefined);
    
    render(<LoginForm />);
    
    const emailInput = screen.getByLabelText(/email/i);
    const passwordInput = screen.getByLabelText(/password/i);
    const loginButton = screen.getByRole('button', { name: /login/i });
    
    fireEvent.change(emailInput, { target: { value: 'test@example.com' } });
    fireEvent.change(passwordInput, { target: { value: 'password123' } });
    fireEvent.click(loginButton);
    
    await waitFor(() => {
      expect(mockLogin).toHaveBeenCalledWith('test@example.com', 'password123');
    });
  });

  it('should handle successful login with NextAuth fallback', async () => {
    // Mock AuthContext to return undefined login function
    mockUseAuth.mockReturnValue({
      login: undefined as any,
      loading: false,
      user: null,
    });
    
    (signIn as jest.Mock).mockResolvedValueOnce({ ok: true });
    
    render(<LoginForm />);
    
    const emailInput = screen.getByLabelText(/email/i);
    const passwordInput = screen.getByLabelText(/password/i);
    const loginButton = screen.getByRole('button', { name: /login/i });
    
    fireEvent.change(emailInput, { target: { value: 'test@example.com' } });
    fireEvent.change(passwordInput, { target: { value: 'password123' } });
    fireEvent.click(loginButton);
    
    await waitFor(() => {
      expect(signIn).toHaveBeenCalledWith('credentials', {
        redirect: false,
        email: 'test@example.com',
        password: 'password123',
        callbackUrl: '/test-login-success',
      });
    });
  });

  it('should handle login error', async () => {
    mockLogin.mockRejectedValueOnce(new Error('Invalid credentials'));
    
    render(<LoginForm />);
    
    const emailInput = screen.getByLabelText(/email/i);
    const passwordInput = screen.getByLabelText(/password/i);
    const loginButton = screen.getByRole('button', { name: /login/i });
    
    fireEvent.change(emailInput, { target: { value: 'test@example.com' } });
    fireEvent.change(passwordInput, { target: { value: 'wrongpassword' } });
    fireEvent.click(loginButton);
    
    await waitFor(() => {
      expect(screen.getByText(/invalid credentials/i)).toBeInTheDocument();
    });
  });

  it('should handle NextAuth login error', async () => {
    mockUseAuth.mockReturnValue({
      login: undefined as any,
      loading: false,
      user: null,
    });
    
    (signIn as jest.Mock).mockResolvedValueOnce({ 
      error: 'Invalid credentials',
      ok: false 
    });
    
    render(<LoginForm />);
    
    const emailInput = screen.getByLabelText(/email/i);
    const passwordInput = screen.getByLabelText(/password/i);
    const loginButton = screen.getByRole('button', { name: /login/i });
    
    fireEvent.change(emailInput, { target: { value: 'test@example.com' } });
    fireEvent.change(passwordInput, { target: { value: 'wrongpassword' } });
    fireEvent.click(loginButton);
    
    await waitFor(() => {
      expect(screen.getByText(/invalid credentials/i)).toBeInTheDocument();
    });
  });

  it('should show loading state during login', async () => {
    mockLogin.mockImplementation(() => new Promise(resolve => setTimeout(resolve, 100)));
    
    render(<LoginForm />);
    
    const emailInput = screen.getByLabelText(/email/i);
    const passwordInput = screen.getByLabelText(/password/i);
    const loginButton = screen.getByRole('button', { name: /login/i });
    
    fireEvent.change(emailInput, { target: { value: 'test@example.com' } });
    fireEvent.change(passwordInput, { target: { value: 'password123' } });
    fireEvent.click(loginButton);
    
    // Check that the submit button shows loading state
    const loadingButtons = screen.getAllByRole('button', { name: /logging in/i });
    expect(loadingButtons[0]).toBeInTheDocument();
    expect(loginButton).toBeDisabled();
  });

  it('should handle demo login button click', () => {
    render(<LoginForm />);
    
    const demoButton = screen.getByRole('button', { name: /try demo/i });
    fireEvent.click(demoButton);
    
    expect(signIn).toHaveBeenCalledWith('credentials', {
      email: 'demo@example.com',
      password: 'demo',
      redirect: true,
      callbackUrl: '/dashboard',
    });
  });

  it('should validate required fields', async () => {
    render(<LoginForm />);
    
    const loginButton = screen.getByRole('button', { name: /login/i });
    fireEvent.click(loginButton);
    
    // HTML5 validation should prevent form submission
    expect(mockLogin).not.toHaveBeenCalled();
  });
}); 