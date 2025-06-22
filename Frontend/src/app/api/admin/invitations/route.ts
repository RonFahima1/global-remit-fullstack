import { NextRequest, NextResponse } from 'next/server';
import { getServerSession } from 'next-auth';
import { authOptions } from '@/lib/authOptions';

const BACKEND_URL = process.env.BACKEND_URL || 'http://localhost:8080';

export async function GET(req: NextRequest) {
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

    // Get access token from session
    const accessToken = (session as any).accessToken;
    if (!accessToken) {
      return NextResponse.json({ error: 'No access token available' }, { status: 401 });
    }

    // Get query parameters
    const { searchParams } = new URL(req.url);
    const status = searchParams.get('status');
    const email = searchParams.get('email');

    // Build query string
    const queryParams = new URLSearchParams();
    if (status) queryParams.append('status', status);
    if (email) queryParams.append('email', email);

    // Call backend API to list invitations
    const response = await fetch(`${BACKEND_URL}/api/v1/invitations/?${queryParams.toString()}`, {
      method: 'GET',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${accessToken}`,
      },
    });

    if (!response.ok) {
      const errorData = await response.json();
      return NextResponse.json({ error: errorData.error || 'Failed to fetch invitations' }, { status: response.status });
    }

    const data = await response.json();
    
    // Transform the data to match frontend expectations
    const invitations = data.invitations.map((inv: any) => ({
      id: inv.id,
      email: inv.email,
      role: inv.role_name,
      token: inv.token,
      expiresAt: inv.expires_at,
      usedAt: inv.accepted_at,
      invitedByUser: {
        name: inv.invited_by,
      },
      status: inv.status,
      createdAt: inv.created_at,
    }));

    return NextResponse.json({ invitations });
  } catch (error) {
    console.error('Error fetching invitations:', error);
    return NextResponse.json({ error: 'Internal server error' }, { status: 500 });
  }
} 