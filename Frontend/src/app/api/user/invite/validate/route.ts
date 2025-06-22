import { NextRequest, NextResponse } from 'next/server';

const BACKEND_URL = process.env.BACKEND_URL || 'http://localhost:8080';

export async function GET(req: NextRequest) {
  const { searchParams } = new URL(req.url);
  const token = searchParams.get('token');

  if (!token) {
    return NextResponse.json({ error: 'Token required' }, { status: 400 });
  }

  try {
    // Call backend API to validate invitation
    const response = await fetch(`${BACKEND_URL}/api/v1/invitations/validate?token=${token}`, {
      method: 'GET',
      headers: {
        'Content-Type': 'application/json',
      },
    });

    if (!response.ok) {
      const errorData = await response.json();
      return NextResponse.json({ error: errorData.error || 'Invalid invitation' }, { status: response.status });
    }

    const data = await response.json();
    
    // Map role ID back to role name for frontend compatibility
    const roleIdToNameMap: { [key: number]: string } = {
      5: 'ORG_ADMIN',
      6: 'AGENT_ADMIN',
      7: 'AGENT_USER',
      8: 'COMPLIANCE_USER',
      9: 'ORG_USER',
      10: 'GLOBAL_VIEWER',
    };

    return NextResponse.json({
      invite: {
        email: data.email,
        role: roleIdToNameMap[data.role_id] || 'UNKNOWN',
        expiresAt: data.expires_at,
        invitedBy: data.invited_by,
        valid: data.valid,
      },
    });
  } catch (error) {
    console.error('Invitation validation error:', error);
    return NextResponse.json({ error: 'Internal server error' }, { status: 500 });
  }
} 