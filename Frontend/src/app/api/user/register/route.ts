import { NextRequest, NextResponse } from 'next/server';

const BACKEND_URL = process.env.BACKEND_URL || 'http://localhost:8080';

export async function POST(req: NextRequest) {
  const { token, firstName, lastName, password, phone, department, position } = await req.json();
  if (!token || !firstName || !lastName || !password) {
    return NextResponse.json({ error: 'All required fields must be provided' }, { status: 400 });
  }

  try {
    // Call backend API to accept invitation and create user
    const response = await fetch(`${BACKEND_URL}/api/v1/invitations/accept`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        token,
        first_name: firstName,
        last_name: lastName,
        password,
        phone: phone || '',
        department: department || '',
        position: position || '',
      }),
    });

    if (!response.ok) {
      const errorData = await response.json();
      return NextResponse.json({ error: errorData.error || 'Failed to create user' }, { status: response.status });
    }

    const data = await response.json();
    
    return NextResponse.json({ 
      success: true, 
      user: { 
        id: data.user_id, 
        email: data.email, 
        role: data.role 
      } 
    });
  } catch (error) {
    console.error('Error creating user:', error);
    return NextResponse.json({ error: 'Internal server error' }, { status: 500 });
  }
} 