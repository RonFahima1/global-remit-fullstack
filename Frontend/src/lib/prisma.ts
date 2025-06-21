import { PrismaClient } from '@prisma/client';

console.log('DEBUG: DATABASE_URL:', process.env.DATABASE_URL);
console.log('DEBUG: Instantiating PrismaClient');

const globalForPrisma = globalThis as unknown as { prisma: PrismaClient };

export const prisma =
  globalForPrisma.prisma ||
  new PrismaClient({
    log: process.env.NODE_ENV === 'development' ? ['query', 'error', 'warn'] : ['error'],
  });

if (process.env.NODE_ENV !== 'production') globalForPrisma.prisma = prisma; 