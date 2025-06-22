import { NextRequest, NextResponse } from 'next/server';
import { getServerSession } from 'next-auth';
import { authOptions } from '@/lib/authOptions';

const BACKEND_URL = process.env.BACKEND_URL || 'http://localhost:8080';

// Map role names to role IDs from our backend
const roleToIdMap: { [key: string]: number } = {
  'ORG_ADMIN': 5,
  'AGENT_ADMIN': 6,
  'AGENT_USER': 7,
  'COMPLIANCE_USER': 8,
  'ORG_USER': 9,
  'GLOBAL_VIEWER': 10,
};

export async function POST(req: NextRequest) {
  try {
    const session = await getServerSession(authOptions);
    
    if (!session?.user) {
      return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
    }

    // Check if user has admin privileges
    const userRole = (session.user as any).role;
    if (!['ORG_ADMIN', 'AGENT_ADMIN'].includes(userRole)) {
      return NextResponse.json({ error: 'Forbidden' }, { status: 403 });
    }

    const { email, role } = await req.json();
    if (!email || !role) {
      return NextResponse.json({ error: 'Email and role required' }, { status: 400 });
    }

    // Map role name to role ID
    const roleId = roleToIdMap[role];
    if (!roleId) {
      return NextResponse.json({ error: 'Invalid role' }, { status: 400 });
    }

    // Get access token from session
    const accessToken = (session as any).accessToken;
    if (!accessToken) {
      return NextResponse.json({ error: 'No access token available' }, { status: 401 });
    }

    // Call backend API to create invitation
    const response = await fetch(`${BACKEND_URL}/api/v1/invitations/`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${accessToken}`,
      },
      body: JSON.stringify({
        email,
        role_id: roleId,
        expires_in_hours: 72, // 3 days
      }),
    });

    if (!response.ok) {
      const errorData = await response.json();
      return NextResponse.json({ error: errorData.error || 'Failed to create invitation' }, { status: response.status });
    }

    const data = await response.json();
    
    return NextResponse.json({ 
      inviteLink: data.invite_url, 
      expiresAt: data.expires_at,
      token: data.token 
    });
  } catch (error) {
    console.error('Error creating invitation:', error);
    return NextResponse.json({ error: 'Internal server error' }, { status: 500 });
  }
} 