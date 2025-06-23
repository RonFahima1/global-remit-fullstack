/** @type {import('next').NextConfig} */
const nextConfig = {
  // Enable React's strict mode in production only to prevent double-renders in development
  // which can cause issues with NextAuth
  reactStrictMode: process.env.NODE_ENV === 'production',
  
  // Enable source maps in development
  productionBrowserSourceMaps: process.env.NODE_ENV !== 'production',
  
  // Configure images
  images: {
    remotePatterns: [
      {
        protocol: 'https',
        hostname: 'picsum.photos',
        port: '',
        pathname: '/**',
      },
    ],
    formats: ['image/avif', 'image/webp'],
    deviceSizes: [640, 750, 828, 1080, 1200, 1920, 2048, 3840],
    imageSizes: [16, 32, 48, 64, 96, 128, 256, 384],
    minimumCacheTTL: 60,
    domains: ['picsum.photos', 'localhost', 'global-remit.com', 'frontend'],
    loader: 'default',
    unoptimized: false,
  },
  
  // Security headers
  poweredByHeader: false,
  
  // Enable compression in production
  compress: process.env.NODE_ENV === 'production',
  
  // Environment variables exposed to the browser
  env: {
    NEXT_PUBLIC_APP_ENV: process.env.NODE_ENV || 'development',
    NEXT_PUBLIC_API_BASE_URL: process.env.NEXT_PUBLIC_API_URL || 'http://localhost:8080',
    NEXTAUTH_URL: process.env.NEXTAUTH_URL || 'http://localhost:3000',
  },
  
  // API route configuration
  async rewrites() {
    return [
      {
        source: '/api/v1/:path*',
        destination: `${process.env.NEXT_PUBLIC_API_BASE_URL || 'http://localhost:8080'}/api/v1/:path*`,
      },
    ];
  },
  
  // Webpack configuration
  webpack: (config, { isServer }) => {
    // Fixes npm packages that depend on `node:` protocol
    config.resolve.fallback = {
      ...config.resolve.fallback,
      fs: false,
      net: false,
      tls: false,
      dns: false,
      child_process: false,
      dgram: false,
    };
    
    return config;
  },
  
  // Development server configuration
  experimental: process.env.NODE_ENV === 'development' ? {
    // Enable React Refresh in development
    reactRefresh: true,
    // Enable CSS optimizations
    optimizeCss: true,
  } : {},
};

module.exports = nextConfig;