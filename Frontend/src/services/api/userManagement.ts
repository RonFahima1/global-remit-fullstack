import { getSession } from 'next-auth/react';

const API_BASE_URL = process.env.NEXT_PUBLIC_API_URL || 'http://localhost:8080/api/v1';

export interface BackendUser {
  id: string;
  username: string;
  email: string;
  first_name: string;
  last_name: string;
  status: string;
  role: string;
  phone?: string;
  department?: string;
  position?: string;
  employee_id?: string;
  hire_date?: string;
  termination_date?: string;
  must_change_password: boolean;
  created_at: string;
  updated_at: string;
  last_login_at?: string;
  failed_login_attempts: number;
  locked_until?: string;
}

export interface CreateUserRequest {
  email: string;
  username: string;
  first_name: string;
  last_name: string;
  role: string;
  department?: string;
  position?: string;
  phone?: string;
  employee_id?: string;
  hire_date?: string;
  sendInvitation?: boolean;
}

export interface UpdateUserRequest {
  first_name?: string;
  last_name?: string;
  status?: string;
  role?: string;
  department?: string;
  position?: string;
  phone?: string;
  employee_id?: string;
  hire_date?: string;
  termination_date?: string;
}

export interface UserStatusUpdate {
  status: string;
  reason?: string;
}

class UserManagementAPI {
  private async getAuthHeaders() {
    const session = await getSession();
    return {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${session?.accessToken}`,
    };
  }

  // Get all users
  async getUsers(): Promise<BackendUser[]> {
    try {
      const response = await fetch(`${API_BASE_URL}/users`, {
        headers: await this.getAuthHeaders(),
      });

      if (!response.ok) {
        throw new Error(`Failed to fetch users: ${response.statusText}`);
      }

      const data = await response.json();
      return data.users || [];
    } catch (error) {
      console.error('Error fetching users:', error);
      throw error;
    }
  }

  // Get user by ID
  async getUserById(userId: string): Promise<BackendUser> {
    try {
      const response = await fetch(`${API_BASE_URL}/users/${userId}`, {
        headers: await this.getAuthHeaders(),
      });

      if (!response.ok) {
        throw new Error(`Failed to fetch user: ${response.statusText}`);
      }

      return await response.json();
    } catch (error) {
      console.error('Error fetching user:', error);
      throw error;
    }
  }

  // Create new user
  async createUser(userData: CreateUserRequest): Promise<BackendUser> {
    try {
      const response = await fetch(`${API_BASE_URL}/users`, {
        method: 'POST',
        headers: await this.getAuthHeaders(),
        body: JSON.stringify(userData),
      });

      if (!response.ok) {
        const errorData = await response.json();
        throw new Error(errorData.error || `Failed to create user: ${response.statusText}`);
      }

      return await response.json();
    } catch (error) {
      console.error('Error creating user:', error);
      throw error;
    }
  }

  // Update user
  async updateUser(userId: string, userData: UpdateUserRequest): Promise<BackendUser> {
    try {
      const response = await fetch(`${API_BASE_URL}/users/${userId}`, {
        method: 'PUT',
        headers: await this.getAuthHeaders(),
        body: JSON.stringify(userData),
      });

      if (!response.ok) {
        const errorData = await response.json();
        throw new Error(errorData.error || `Failed to update user: ${response.statusText}`);
      }

      return await response.json();
    } catch (error) {
      console.error('Error updating user:', error);
      throw error;
    }
  }

  // Update user status
  async updateUserStatus(userId: string, statusUpdate: UserStatusUpdate): Promise<void> {
    try {
      const response = await fetch(`${API_BASE_URL}/users/${userId}/status`, {
        method: 'PATCH',
        headers: await this.getAuthHeaders(),
        body: JSON.stringify(statusUpdate),
      });

      if (!response.ok) {
        const errorData = await response.json();
        throw new Error(errorData.error || `Failed to update user status: ${response.statusText}`);
      }
    } catch (error) {
      console.error('Error updating user status:', error);
      throw error;
    }
  }

  // Reset user password (admin function)
  async resetUserPassword(userId: string, newPassword: string): Promise<void> {
    try {
      const response = await fetch(`${API_BASE_URL}/users/${userId}/reset-password`, {
        method: 'POST',
        headers: await this.getAuthHeaders(),
        body: JSON.stringify({ newPassword }),
      });

      if (!response.ok) {
        const errorData = await response.json();
        throw new Error(errorData.error || `Failed to reset password: ${response.statusText}`);
      }
    } catch (error) {
      console.error('Error resetting password:', error);
      throw error;
    }
  }

  // Delete user (soft delete)
  async deleteUser(userId: string): Promise<void> {
    try {
      const response = await fetch(`${API_BASE_URL}/users/${userId}`, {
        method: 'DELETE',
        headers: await this.getAuthHeaders(),
      });

      if (!response.ok) {
        const errorData = await response.json();
        throw new Error(errorData.error || `Failed to delete user: ${response.statusText}`);
      }
    } catch (error) {
      console.error('Error deleting user:', error);
      throw error;
    }
  }

  // Get user roles
  async getRoles(): Promise<Array<{ id: number; name: string; description: string }>> {
    try {
      const response = await fetch(`${API_BASE_URL}/roles`, {
        headers: await this.getAuthHeaders(),
      });

      if (!response.ok) {
        throw new Error(`Failed to fetch roles: ${response.statusText}`);
      }

      const data = await response.json();
      return data.roles || [];
    } catch (error) {
      console.error('Error fetching roles:', error);
      throw error;
    }
  }

  // Get user permissions
  async getUserPermissions(userId: string): Promise<string[]> {
    try {
      const response = await fetch(`${API_BASE_URL}/users/${userId}/permissions`, {
        headers: await this.getAuthHeaders(),
      });

      if (!response.ok) {
        throw new Error(`Failed to fetch user permissions: ${response.statusText}`);
      }

      const data = await response.json();
      return data.permissions || [];
    } catch (error) {
      console.error('Error fetching user permissions:', error);
      throw error;
    }
  }

  // Search users
  async searchUsers(query: string): Promise<BackendUser[]> {
    try {
      const response = await fetch(`${API_BASE_URL}/users/search?q=${encodeURIComponent(query)}`, {
        headers: await this.getAuthHeaders(),
      });

      if (!response.ok) {
        throw new Error(`Failed to search users: ${response.statusText}`);
      }

      const data = await response.json();
      return data.users || [];
    } catch (error) {
      console.error('Error searching users:', error);
      throw error;
    }
  }
}

export const userManagementAPI = new UserManagementAPI(); 