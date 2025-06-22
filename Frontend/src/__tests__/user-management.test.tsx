import React from 'react';
import { render, screen, fireEvent, waitFor } from '@testing-library/react';
import { rest } from 'msw';
import { setupServer } from 'msw/node';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { AuthProvider } from '../../context/AuthContext';
import UserManagement from '../../app/(app)/admin/users/page';
import { User } from '../../types/user';

// Mock Next.js router
jest.mock('next/navigation', () => ({
  useRouter: () => ({
    push: jest.fn(),
    replace: jest.fn(),
    prefetch: jest.fn(),
    back: jest.fn(),
  }),
  useSearchParams: () => new URLSearchParams(),
}));

// Mock Next.js auth
jest.mock('next-auth/react', () => ({
  useSession: () => ({
    data: {
      user: {
        id: 'admin-user-id',
        email: 'admin@example.com',
        role: 'ORG_ADMIN',
        permissions: ['users:create', 'users:read', 'users:update', 'users:delete'],
      },
      accessToken: 'mock-access-token',
    },
    status: 'authenticated',
  }),
  signOut: jest.fn(),
}));

// Mock API client
jest.mock('../../lib/api-client', () => ({
  apiClient: {
    get: jest.fn(),
    post: jest.fn(),
    put: jest.fn(),
    delete: jest.fn(),
  },
}));

// Sample test data
const mockUsers: User[] = [
  {
    id: 'user-1',
    username: 'testuser1',
    email: 'testuser1@example.com',
    email_verified: true,
    must_change_password: false,
    mfa_enabled: false,
    status: 'ACTIVE',
    role: 'ORG_USER',
    failed_login_attempts: 0,
    first_name: 'Test',
    last_name: 'User1',
    phone: '+1234567890',
    phone_verified: false,
    login_count: 5,
    created_at: '2025-06-22T00:00:00Z',
    updated_at: '2025-06-22T00:00:00Z',
    version: 1,
  },
  {
    id: 'user-2',
    username: 'testuser2',
    email: 'testuser2@example.com',
    email_verified: false,
    must_change_password: true,
    mfa_enabled: false,
    status: 'PENDING_VERIFICATION',
    role: 'AGENT_USER',
    failed_login_attempts: 2,
    first_name: 'Test',
    last_name: 'User2',
    phone: '',
    phone_verified: false,
    login_count: 0,
    created_at: '2025-06-22T00:00:00Z',
    updated_at: '2025-06-22T00:00:00Z',
    version: 1,
  },
];

// MSW server for API mocking
const server = setupServer(
  // GET /api/v1/users - List users
  rest.get('/api/v1/users', (req, res, ctx) => {
    return res(
      ctx.json({
        users: mockUsers,
        total: mockUsers.length,
        page: 1,
        limit: 50,
      })
    );
  }),

  // POST /api/v1/users - Create user
  rest.post('/api/v1/users', (req, res, ctx) => {
    const newUser = {
      id: 'new-user-id',
      username: 'newuser',
      email: 'newuser@example.com',
      email_verified: false,
      must_change_password: false,
      mfa_enabled: false,
      status: 'PENDING_VERIFICATION',
      role: 'ORG_USER',
      failed_login_attempts: 0,
      first_name: 'New',
      last_name: 'User',
      phone: '',
      phone_verified: false,
      login_count: 0,
      created_at: '2025-06-22T00:00:00Z',
      updated_at: '2025-06-22T00:00:00Z',
      version: 1,
    };
    return res(ctx.json({ user: newUser, tempPassword: 'TempPass123!' }));
  }),

  // PUT /api/v1/users/:id - Update user
  rest.put('/api/v1/users/:id', (req, res, ctx) => {
    const { id } = req.params;
    const updatedUser = { ...mockUsers[0], id, ...req.body };
    return res(ctx.json({ user: updatedUser }));
  }),

  // DELETE /api/v1/users/:id - Delete user
  rest.delete('/api/v1/users/:id', (req, res, ctx) => {
    return res(ctx.json({ success: true }));
  }),

  // POST /api/v1/auth/login - Login
  rest.post('/api/v1/auth/login', (req, res, ctx) => {
    return res(
      ctx.json({
        accessToken: 'mock-access-token',
        refreshToken: 'mock-refresh-token',
        user: {
          id: 'user-id',
          email: 'test@example.com',
          role: 'ORG_USER',
          permissions: ['users:read'],
        },
      })
    );
  })
);

// Setup and teardown
beforeAll(() => server.listen());
afterEach(() => server.resetHandlers());
afterAll(() => server.close());

// Test wrapper component
const TestWrapper: React.FC<{ children: React.ReactNode }> = ({ children }) => {
  const queryClient = new QueryClient({
    defaultOptions: {
      queries: {
        retry: false,
      },
    },
  });

  return (
    <QueryClientProvider client={queryClient}>
      <AuthProvider>{children}</AuthProvider>
    </QueryClientProvider>
  );
};

describe('User Management', () => {
  describe('User List', () => {
    it('should display users list correctly', async () => {
      render(
        <TestWrapper>
          <UserManagement />
        </TestWrapper>
      );

      // Wait for users to load
      await waitFor(() => {
        expect(screen.getByText('testuser1@example.com')).toBeInTheDocument();
        expect(screen.getByText('testuser2@example.com')).toBeInTheDocument();
      });

      // Check user details
      expect(screen.getByText('Test User1')).toBeInTheDocument();
      expect(screen.getByText('Test User2')).toBeInTheDocument();
      expect(screen.getByText('ACTIVE')).toBeInTheDocument();
      expect(screen.getByText('PENDING_VERIFICATION')).toBeInTheDocument();
    });

    it('should handle empty users list', async () => {
      server.use(
        rest.get('/api/v1/users', (req, res, ctx) => {
          return res(ctx.json({ users: [], total: 0, page: 1, limit: 50 }));
        })
      );

      render(
        <TestWrapper>
          <UserManagement />
        </TestWrapper>
      );

      await waitFor(() => {
        expect(screen.getByText(/no users found/i)).toBeInTheDocument();
      });
    });

    it('should handle API error when loading users', async () => {
      server.use(
        rest.get('/api/v1/users', (req, res, ctx) => {
          return res(ctx.status(500), ctx.json({ error: 'Internal server error' }));
        })
      );

      render(
        <TestWrapper>
          <UserManagement />
        </TestWrapper>
      );

      await waitFor(() => {
        expect(screen.getByText(/error loading users/i)).toBeInTheDocument();
      });
    });
  });

  describe('User Creation', () => {
    it('should open create user modal', async () => {
      render(
        <TestWrapper>
          <UserManagement />
        </TestWrapper>
      );

      const createButton = screen.getByRole('button', { name: /create user/i });
      fireEvent.click(createButton);

      await waitFor(() => {
        expect(screen.getByText(/create new user/i)).toBeInTheDocument();
      });
    });

    it('should create user successfully', async () => {
      render(
        <TestWrapper>
          <UserManagement />
        </TestWrapper>
      );

      // Open create modal
      const createButton = screen.getByRole('button', { name: /create user/i });
      fireEvent.click(createButton);

      await waitFor(() => {
        expect(screen.getByText(/create new user/i)).toBeInTheDocument();
      });

      // Fill form
      fireEvent.change(screen.getByLabelText(/username/i), {
        target: { value: 'newuser' },
      });
      fireEvent.change(screen.getByLabelText(/email/i), {
        target: { value: 'newuser@example.com' },
      });
      fireEvent.change(screen.getByLabelText(/first name/i), {
        target: { value: 'New' },
      });
      fireEvent.change(screen.getByLabelText(/last name/i), {
        target: { value: 'User' },
      });
      fireEvent.change(screen.getByLabelText(/role/i), {
        target: { value: 'ORG_USER' },
      });

      // Submit form
      const submitButton = screen.getByRole('button', { name: /create/i });
      fireEvent.click(submitButton);

      await waitFor(() => {
        expect(screen.getByText(/user created successfully/i)).toBeInTheDocument();
      });
    });

    it('should validate required fields', async () => {
      render(
        <TestWrapper>
          <UserManagement />
        </TestWrapper>
      );

      // Open create modal
      const createButton = screen.getByRole('button', { name: /create user/i });
      fireEvent.click(createButton);

      await waitFor(() => {
        expect(screen.getByText(/create new user/i)).toBeInTheDocument();
      });

      // Try to submit without filling required fields
      const submitButton = screen.getByRole('button', { name: /create/i });
      fireEvent.click(submitButton);

      await waitFor(() => {
        expect(screen.getByText(/username is required/i)).toBeInTheDocument();
        expect(screen.getByText(/email is required/i)).toBeInTheDocument();
      });
    });

    it('should validate email format', async () => {
      render(
        <TestWrapper>
          <UserManagement />
        </TestWrapper>
      );

      // Open create modal
      const createButton = screen.getByRole('button', { name: /create user/i });
      fireEvent.click(createButton);

      await waitFor(() => {
        expect(screen.getByText(/create new user/i)).toBeInTheDocument();
      });

      // Enter invalid email
      fireEvent.change(screen.getByLabelText(/email/i), {
        target: { value: 'invalid-email' },
      });

      const submitButton = screen.getByRole('button', { name: /create/i });
      fireEvent.click(submitButton);

      await waitFor(() => {
        expect(screen.getByText(/invalid email format/i)).toBeInTheDocument();
      });
    });
  });

  describe('User Updates', () => {
    it('should open edit user modal', async () => {
      render(
        <TestWrapper>
          <UserManagement />
        </TestWrapper>
      );

      await waitFor(() => {
        expect(screen.getByText('testuser1@example.com')).toBeInTheDocument();
      });

      // Click edit button for first user
      const editButtons = screen.getAllByRole('button', { name: /edit/i });
      fireEvent.click(editButtons[0]);

      await waitFor(() => {
        expect(screen.getByText(/edit user/i)).toBeInTheDocument();
      });
    });

    it('should update user successfully', async () => {
      render(
        <TestWrapper>
          <UserManagement />
        </TestWrapper>
      );

      await waitFor(() => {
        expect(screen.getByText('testuser1@example.com')).toBeInTheDocument();
      });

      // Open edit modal
      const editButtons = screen.getAllByRole('button', { name: /edit/i });
      fireEvent.click(editButtons[0]);

      await waitFor(() => {
        expect(screen.getByText(/edit user/i)).toBeInTheDocument();
      });

      // Update user details
      fireEvent.change(screen.getByLabelText(/first name/i), {
        target: { value: 'Updated' },
      });
      fireEvent.change(screen.getByLabelText(/last name/i), {
        target: { value: 'Name' },
      });

      // Submit form
      const submitButton = screen.getByRole('button', { name: /update/i });
      fireEvent.click(submitButton);

      await waitFor(() => {
        expect(screen.getByText(/user updated successfully/i)).toBeInTheDocument();
      });
    });

    it('should change user status', async () => {
      render(
        <TestWrapper>
          <UserManagement />
        </TestWrapper>
      );

      await waitFor(() => {
        expect(screen.getByText('testuser1@example.com')).toBeInTheDocument();
      });

      // Open edit modal
      const editButtons = screen.getAllByRole('button', { name: /edit/i });
      fireEvent.click(editButtons[0]);

      await waitFor(() => {
        expect(screen.getByText(/edit user/i)).toBeInTheDocument();
      });

      // Change status to DISABLED
      fireEvent.change(screen.getByLabelText(/status/i), {
        target: { value: 'DISABLED' },
      });

      const submitButton = screen.getByRole('button', { name: /update/i });
      fireEvent.click(submitButton);

      await waitFor(() => {
        expect(screen.getByText(/user updated successfully/i)).toBeInTheDocument();
      });
    });
  });

  describe('User Deletion', () => {
    it('should show delete confirmation dialog', async () => {
      render(
        <TestWrapper>
          <UserManagement />
        </TestWrapper>
      );

      await waitFor(() => {
        expect(screen.getByText('testuser1@example.com')).toBeInTheDocument();
      });

      // Click delete button
      const deleteButtons = screen.getAllByRole('button', { name: /delete/i });
      fireEvent.click(deleteButtons[0]);

      await waitFor(() => {
        expect(screen.getByText(/confirm deletion/i)).toBeInTheDocument();
        expect(screen.getByText(/are you sure you want to delete this user/i)).toBeInTheDocument();
      });
    });

    it('should delete user successfully', async () => {
      render(
        <TestWrapper>
          <UserManagement />
        </TestWrapper>
      );

      await waitFor(() => {
        expect(screen.getByText('testuser1@example.com')).toBeInTheDocument();
      });

      // Click delete button
      const deleteButtons = screen.getAllByRole('button', { name: /delete/i });
      fireEvent.click(deleteButtons[0]);

      await waitFor(() => {
        expect(screen.getByText(/confirm deletion/i)).toBeInTheDocument();
      });

      // Confirm deletion
      const confirmButton = screen.getByRole('button', { name: /delete/i });
      fireEvent.click(confirmButton);

      await waitFor(() => {
        expect(screen.getByText(/user deleted successfully/i)).toBeInTheDocument();
      });
    });

    it('should cancel deletion', async () => {
      render(
        <TestWrapper>
          <UserManagement />
        </TestWrapper>
      );

      await waitFor(() => {
        expect(screen.getByText('testuser1@example.com')).toBeInTheDocument();
      });

      // Click delete button
      const deleteButtons = screen.getAllByRole('button', { name: /delete/i });
      fireEvent.click(deleteButtons[0]);

      await waitFor(() => {
        expect(screen.getByText(/confirm deletion/i)).toBeInTheDocument();
      });

      // Cancel deletion
      const cancelButton = screen.getByRole('button', { name: /cancel/i });
      fireEvent.click(cancelButton);

      await waitFor(() => {
        expect(screen.queryByText(/confirm deletion/i)).not.toBeInTheDocument();
      });
    });
  });

  describe('User Status Management', () => {
    it('should show status badges correctly', async () => {
      render(
        <TestWrapper>
          <UserManagement />
        </TestWrapper>
      );

      await waitFor(() => {
        expect(screen.getByText('ACTIVE')).toBeInTheDocument();
        expect(screen.getByText('PENDING_VERIFICATION')).toBeInTheDocument();
      });
    });

    it('should allow status changes', async () => {
      render(
        <TestWrapper>
          <UserManagement />
        </TestWrapper>
      );

      await waitFor(() => {
        expect(screen.getByText('testuser1@example.com')).toBeInTheDocument();
      });

      // Open edit modal
      const editButtons = screen.getAllByRole('button', { name: /edit/i });
      fireEvent.click(editButtons[0]);

      await waitFor(() => {
        expect(screen.getByText(/edit user/i)).toBeInTheDocument();
      });

      // Test different status options
      const statusSelect = screen.getByLabelText(/status/i);
      const statusOptions = ['ACTIVE', 'PENDING', 'SUSPENDED', 'DISABLED'];

      statusOptions.forEach((status) => {
        fireEvent.change(statusSelect, { target: { value: status } });
        expect(statusSelect).toHaveValue(status);
      });
    });
  });

  describe('User Search and Filtering', () => {
    it('should filter users by search term', async () => {
      render(
        <TestWrapper>
          <UserManagement />
        </TestWrapper>
      );

      await waitFor(() => {
        expect(screen.getByText('testuser1@example.com')).toBeInTheDocument();
        expect(screen.getByText('testuser2@example.com')).toBeInTheDocument();
      });

      // Search for specific user
      const searchInput = screen.getByPlaceholderText(/search users/i);
      fireEvent.change(searchInput, { target: { value: 'testuser1' } });

      await waitFor(() => {
        expect(screen.getByText('testuser1@example.com')).toBeInTheDocument();
        expect(screen.queryByText('testuser2@example.com')).not.toBeInTheDocument();
      });
    });

    it('should filter users by status', async () => {
      render(
        <TestWrapper>
          <UserManagement />
        </TestWrapper>
      );

      await waitFor(() => {
        expect(screen.getByText('ACTIVE')).toBeInTheDocument();
        expect(screen.getByText('PENDING_VERIFICATION')).toBeInTheDocument();
      });

      // Filter by ACTIVE status
      const statusFilter = screen.getByLabelText(/filter by status/i);
      fireEvent.change(statusFilter, { target: { value: 'ACTIVE' } });

      await waitFor(() => {
        expect(screen.getByText('ACTIVE')).toBeInTheDocument();
        expect(screen.queryByText('PENDING_VERIFICATION')).not.toBeInTheDocument();
      });
    });

    it('should filter users by role', async () => {
      render(
        <TestWrapper>
          <UserManagement />
        </TestWrapper>
      );

      await waitFor(() => {
        expect(screen.getByText('testuser1@example.com')).toBeInTheDocument();
        expect(screen.getByText('testuser2@example.com')).toBeInTheDocument();
      });

      // Filter by ORG_USER role
      const roleFilter = screen.getByLabelText(/filter by role/i);
      fireEvent.change(roleFilter, { target: { value: 'ORG_USER' } });

      await waitFor(() => {
        expect(screen.getByText('testuser1@example.com')).toBeInTheDocument();
        expect(screen.queryByText('testuser2@example.com')).not.toBeInTheDocument();
      });
    });
  });

  describe('Pagination', () => {
    it('should handle pagination correctly', async () => {
      // Mock paginated response
      server.use(
        rest.get('/api/v1/users', (req, res, ctx) => {
          const page = req.url.searchParams.get('page') || '1';
          const limit = req.url.searchParams.get('limit') || '10';
          
          return res(
            ctx.json({
              users: mockUsers,
              total: 25,
              page: parseInt(page),
              limit: parseInt(limit),
            })
          );
        })
      );

      render(
        <TestWrapper>
          <UserManagement />
        </TestWrapper>
      );

      await waitFor(() => {
        expect(screen.getByText(/showing 1-10 of 25 users/i)).toBeInTheDocument();
      });

      // Navigate to next page
      const nextButton = screen.getByRole('button', { name: /next/i });
      fireEvent.click(nextButton);

      await waitFor(() => {
        expect(screen.getByText(/showing 11-20 of 25 users/i)).toBeInTheDocument();
      });
    });
  });

  describe('Error Handling', () => {
    it('should handle network errors gracefully', async () => {
      server.use(
        rest.get('/api/v1/users', (req, res, ctx) => {
          return res.networkError('Failed to connect');
        })
      );

      render(
        <TestWrapper>
          <UserManagement />
        </TestWrapper>
      );

      await waitFor(() => {
        expect(screen.getByText(/network error/i)).toBeInTheDocument();
      });
    });

    it('should handle unauthorized access', async () => {
      server.use(
        rest.get('/api/v1/users', (req, res, ctx) => {
          return res(ctx.status(401), ctx.json({ error: 'Unauthorized' }));
        })
      );

      render(
        <TestWrapper>
          <UserManagement />
        </TestWrapper>
      );

      await waitFor(() => {
        expect(screen.getByText(/unauthorized/i)).toBeInTheDocument();
      });
    });

    it('should handle server errors', async () => {
      server.use(
        rest.get('/api/v1/users', (req, res, ctx) => {
          return res(ctx.status(500), ctx.json({ error: 'Internal server error' }));
        })
      );

      render(
        <TestWrapper>
          <UserManagement />
        </TestWrapper>
      );

      await waitFor(() => {
        expect(screen.getByText(/server error/i)).toBeInTheDocument();
      });
    });
  });

  describe('Accessibility', () => {
    it('should have proper ARIA labels', async () => {
      render(
        <TestWrapper>
          <UserManagement />
        </TestWrapper>
      );

      await waitFor(() => {
        expect(screen.getByLabelText(/search users/i)).toBeInTheDocument();
        expect(screen.getByLabelText(/filter by status/i)).toBeInTheDocument();
        expect(screen.getByLabelText(/filter by role/i)).toBeInTheDocument();
      });
    });

    it('should be keyboard navigable', async () => {
      render(
        <TestWrapper>
          <UserManagement />
        </TestWrapper>
      );

      await waitFor(() => {
        expect(screen.getByText('testuser1@example.com')).toBeInTheDocument();
      });

      // Test tab navigation
      const createButton = screen.getByRole('button', { name: /create user/i });
      createButton.focus();
      expect(createButton).toHaveFocus();

      // Test keyboard interaction
      fireEvent.keyDown(createButton, { key: 'Enter' });
      await waitFor(() => {
        expect(screen.getByText(/create new user/i)).toBeInTheDocument();
      });
    });
  });
}); 