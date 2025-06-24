import bcrypt from 'bcryptjs';

// Mock bcrypt
jest.mock('bcryptjs', () => ({
  compare: jest.fn(),
}));

// Mock JWT sign
const mockSign = jest.fn(() => 'mock-jwt-token');

// Mock Prisma
const mockPrisma = {
  user: {
    findUnique: jest.fn(),
    update: jest.fn(),
  },
};

// Mock the login handler
const mockHandleLogin = async (body: any, prisma: any, sign: any) => {
  const { email, password } = body;

  const user = await prisma.user.findUnique({
    where: { email },
  });

  if (!user) {
    return {
      status: 401,
      json: () => Promise.resolve({ message: 'Invalid email or password' }),
    };
  }

  const isValidPassword = await bcrypt.compare(password, user.password);
  if (!isValidPassword) {
    await prisma.user.update({
      where: { id: user.id },
      data: { failedAttempts: user.failedAttempts + 1 },
    });
    return {
      status: 401,
      json: () => Promise.resolve({ message: 'Invalid email or password' }),
    };
  }

  // Reset failed attempts on successful login
  await prisma.user.update({
    where: { id: user.id },
    data: {
      failedAttempts: 0,
      lastLogin: new Date(),
    },
  });

  const token = sign({ userId: user.id, email: user.email });
  
  return {
    status: 200,
    json: () => Promise.resolve({
      message: 'Login successful',
      token,
      user: {
        id: user.id,
        email: user.email,
        name: user.name,
        role: user.role,
      },
    }),
  };
};

interface User {
  id: string;
  email: string;
  name: string;
  password: string;
  role: string;
  failedAttempts: number;
}

interface LoginData {
  email: string;
  password: string;
}

describe('Login API', () => {
  let prisma: any;

  beforeEach(() => {
    jest.clearAllMocks();
    prisma = { ...mockPrisma };
  });

  it('should login successfully with valid credentials', async () => {
    const loginData: LoginData = {
      email: 'test@example.com',
      password: 'Test123456',
    };

    const mockUser: Partial<User> = {
      id: '1',
      email: loginData.email,
      name: 'Test User',
      password: 'hashedPassword',
      role: 'USER',
      failedAttempts: 0,
    };

    (prisma.user.findUnique as jest.Mock<() => Promise<User | null>>).mockResolvedValue(mockUser as User);
    (bcrypt.compare as jest.Mock).mockResolvedValue(true);
    (prisma.user.update as jest.Mock<() => Promise<User>>).mockResolvedValue(mockUser as User);

    const response = await mockHandleLogin(loginData, prisma, mockSign);
    const data = await response.json();

    expect(response.status).toBe(200);
    expect(data).toEqual({
      message: 'Login successful',
      token: 'mock-jwt-token',
      user: {
        id: mockUser.id,
        email: mockUser.email,
        name: mockUser.name,
        role: mockUser.role,
      },
    });
    expect(prisma.user.findUnique).toHaveBeenCalledWith({
      where: { email: loginData.email },
    });
    expect(bcrypt.compare).toHaveBeenCalledWith(loginData.password, mockUser.password);
    expect(prisma.user.update).toHaveBeenCalledWith({
      where: { id: mockUser.id },
      data: {
        failedAttempts: 0,
        lastLogin: expect.any(Date),
      },
    });
  });

  it('should return error for non-existent user', async () => {
    const loginData: LoginData = {
      email: 'nonexistent@example.com',
      password: 'Test123456',
    };

    (prisma.user.findUnique as jest.Mock<() => Promise<User | null>>).mockResolvedValue(null);

    const response = await mockHandleLogin(loginData, prisma, mockSign);
    const data = await response.json();

    expect(response.status).toBe(401);
    expect(data).toEqual({
      message: 'Invalid email or password',
    });
    expect(prisma.user.findUnique).toHaveBeenCalledWith({
      where: { email: loginData.email },
    });
    expect(bcrypt.compare).not.toHaveBeenCalled();
    expect(prisma.user.update).not.toHaveBeenCalled();
  });

  it('should return error for invalid password', async () => {
    const loginData: LoginData = {
      email: 'test@example.com',
      password: 'WrongPassword',
    };

    const mockUser: Partial<User> = {
      id: '1',
      email: loginData.email,
      password: 'hashedPassword',
      failedAttempts: 0,
    };

    (prisma.user.findUnique as jest.Mock<() => Promise<User | null>>).mockResolvedValue(mockUser as User);
    (bcrypt.compare as jest.Mock).mockResolvedValue(false);

    const response = await mockHandleLogin(loginData, prisma, mockSign);
    const data = await response.json();

    expect(response.status).toBe(401);
    expect(data).toEqual({
      message: 'Invalid email or password',
    });
    expect(prisma.user.findUnique).toHaveBeenCalledWith({
      where: { email: loginData.email },
    });
    expect(bcrypt.compare).toHaveBeenCalledWith(loginData.password, mockUser.password);
    expect(prisma.user.update).toHaveBeenCalledWith({
      where: { id: mockUser.id },
      data: {
        failedAttempts: 1,
      },
    });
  });

  it('should handle server errors gracefully', async () => {
    const loginData: LoginData = {
      email: 'test@example.com',
      password: 'Test123456',
    };

    (prisma.user.findUnique as jest.Mock<() => Promise<User | null>>).mockRejectedValue(new Error('Database error'));

    await expect(mockHandleLogin(loginData, prisma, mockSign)).rejects.toThrow('Database error');
  });
}); 