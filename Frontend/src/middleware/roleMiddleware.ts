import { NextRequest, NextResponse } from 'next/server';
import { getToken } from 'next-auth/jwt';

type UserRole = 'ORG_ADMIN' | 'AGENT_ADMIN' | 'AGENT_USER' | 'COMPLIANCE_USER' | 'ORG_USER';

// Define role hierarchy and permissions
const ROLE_HIERARCHY: Record<UserRole, UserRole[]> = {
  ORG_ADMIN: ['ORG_ADMIN', 'AGENT_ADMIN', 'AGENT_USER', 'COMPLIANCE_USER', 'ORG_USER'],
  AGENT_ADMIN: ['AGENT_ADMIN', 'AGENT_USER'],
  AGENT_USER: ['AGENT_USER'],
  COMPLIANCE_USER: ['COMPLIANCE_USER'],
  ORG_USER: ['ORG_USER'],
};

// Define route permissions
const ROUTE_PERMISSIONS: Record<string, UserRole[]> = {
  '/dashboard': ['ORG_ADMIN', 'AGENT_ADMIN', 'AGENT_USER', 'COMPLIANCE_USER', 'ORG_USER'],
  '/admin': ['ORG_ADMIN'],
  '/users': ['ORG_ADMIN', 'AGENT_ADMIN'],
  '/clients': ['ORG_ADMIN', 'AGENT_ADMIN', 'AGENT_USER'],
  '/compliance': ['ORG_ADMIN', 'COMPLIANCE_USER'],
  // Add more routes as needed
};

export async function roleMiddleware(request: NextRequest) {
  const pathname = request.nextUrl.pathname;
  
  // Skip middleware for public routes
  if (pathname.startsWith('/api/auth') || 
      pathname.startsWith('/login') || 
      pathname.startsWith('/register') ||
      pathname.startsWith('/_next') ||
      pathname.startsWith('/favicon')) {
    return NextResponse.next();
  }

  try {
    const token = await getToken({ 
      req: request, 
      secret: 'b1e93eda591ada953b034a7c28eaba0e' 
    });

    // If no token, redirect to login
    if (!token) {
      const loginUrl = new URL('http://localhost:3000/login');
      loginUrl.searchParams.set('callbackUrl', pathname);
      return NextResponse.redirect(loginUrl);
    }

    const userRole = token.role as UserRole;
    
    // Check if user has permission for the current route
    const hasPermission = checkRoutePermission(pathname, userRole);
    
    if (!hasPermission) {
      // Redirect to appropriate dashboard based on role
      const dashboardUrl = getDashboardUrl(userRole);
      return NextResponse.redirect(new URL(dashboardUrl, request.url));
    }

    return NextResponse.next();
  } catch (error) {
    console.error('Role middleware error:', error);
    return NextResponse.redirect('http://localhost:3000/login');
  }
}

function checkRoutePermission(pathname: string, userRole: UserRole): boolean {
  // Check exact route match first
  if (ROUTE_PERMISSIONS[pathname]) {
    return ROUTE_PERMISSIONS[pathname].includes(userRole);
  }

  // Check prefix matches
  for (const [route, allowedRoles] of Object.entries(ROUTE_PERMISSIONS)) {
    if (pathname.startsWith(route)) {
      return allowedRoles.includes(userRole);
    }
  }

  // Default to allowing access if no specific permission is defined
  return true;
}

function getDashboardUrl(userRole: UserRole): string {
  switch (userRole) {
    case 'ORG_ADMIN':
      return '/admin';
    case 'AGENT_ADMIN':
      return '/manager';
    case 'AGENT_USER':
      return '/teller';
    case 'COMPLIANCE_USER':
      return '/compliance';
    case 'ORG_USER':
    default:
      return '/dashboard';
  }
}

export function hasRole(userRole: UserRole, requiredRole: UserRole): boolean {
  return ROLE_HIERARCHY[userRole]?.includes(requiredRole) || false;
}

export function canManageRole(userRole: UserRole, targetRole: UserRole): boolean {
  const userHierarchy = ROLE_HIERARCHY[userRole] || [];
  return userHierarchy.includes(targetRole) && userRole !== targetRole;
} 