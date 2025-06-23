import { NextResponse } from 'next/server';
import type { NextRequest } from 'next/server';

// Re-export the config to ensure this route is not cached
export const dynamic = 'force-dynamic';
export const revalidate = 0;

export async function GET(request: NextRequest) {
  const backendUrl = process.env.NEXT_PUBLIC_API_URL || 'http://localhost:8080';
  const healthCheckUrl = `${backendUrl}/api/v1/health`;

  try {
    const response = await fetch(healthCheckUrl, {
      method: 'GET',
      headers: {
        'Content-Type': 'application/json',
      },
      // Don't cache this request
      cache: 'no-store',
    });

    if (!response.ok) {
      throw new Error(`Backend returned ${response.status}: ${response.statusText}`);
    }

    const data = await response.json();
    
    // Add frontend status and timestamp
    const healthData = {
      ...data,
      frontend: {
        status: 'ok',
        timestamp: new Date().toISOString(),
        environment: process.env.NODE_ENV,
        version: process.env.NEXT_PUBLIC_APP_VERSION || '1.0.0',
      },
    };

    return NextResponse.json(healthData);
  } catch (error) {
    console.error('Health check failed:', error);
    
    return NextResponse.json(
      {
        status: 'error',
        message: error instanceof Error ? error.message : 'Unknown error',
        timestamp: new Date().toISOString(),
        frontend: {
          status: 'ok',
          timestamp: new Date().toISOString(),
          environment: process.env.NODE_ENV,
          version: process.env.NEXT_PUBLIC_APP_VERSION || '1.0.0',
        },
      },
      { status: 503 }
    );
  }
}
