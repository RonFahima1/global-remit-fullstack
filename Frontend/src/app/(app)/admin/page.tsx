"use client";
import Link from "next/link";
import { Card, CardHeader, CardTitle, CardContent, CardDescription } from "@/components/ui/card";
import { 
  Users, 
  Shield,
  Building2,
  UserPlus
} from 'lucide-react';

export default function AdminDashboard() {
  return (
    <div className="container mx-auto p-6 space-y-6">
      <div className="flex justify-between items-center">
        <div>
          <h1 className="text-3xl font-bold">Admin Dashboard</h1>
          <p className="text-muted-foreground">
            Welcome back, Administrator. Select an area to manage.
          </p>
        </div>
      </div>

      {/* Quick Actions */}
      <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
        <Card>
          <CardHeader>
            <CardTitle>User Management</CardTitle>
            <CardDescription>
              Manage users, roles, and permissions
            </CardDescription>
          </CardHeader>
          <CardContent className="space-y-2">
            <Link href="/admin/users" className="flex items-center p-3 bg-gray-50 hover:bg-gray-100 rounded-md transition-colors">
              <Users className="w-5 h-5 mr-3" />
              <span>View All Users</span>
            </Link>
            <Link href="/admin/users/create" className="flex items-center p-3 bg-gray-50 hover:bg-gray-100 rounded-md transition-colors">
              <UserPlus className="w-5 h-5 mr-3" />
              <span>Create New User</span>
            </Link>
            <Link href="/admin/roles" className="flex items-center p-3 bg-gray-50 hover:bg-gray-100 rounded-md transition-colors">
              <Shield className="w-5 h-5 mr-3" />
              <span>Manage Roles</span>
            </Link>
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle>Organization Management</CardTitle>
            <CardDescription>
              Organization settings and configurations
            </CardDescription>
          </CardHeader>
          <CardContent className="space-y-2">
             <Link href="/admin/organization-settings" className="flex items-center p-3 bg-gray-50 hover:bg-gray-100 rounded-md transition-colors">
              <Building2 className="w-5 h-5 mr-3" />
              <span>Organization Settings</span>
            </Link>
          </CardContent>
        </Card>
      </div>
    </div>
  );
} 