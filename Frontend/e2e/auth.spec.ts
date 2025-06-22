import { test, expect } from '@playwright/test';

const UI_URL = process.env.NEXT_PUBLIC_UI_URL || 'http://localhost:3000'; // 3000 here is a port. Never change port numbers in code. Use canonical port from env/config only.
const API_URL = 'http://localhost:8080/api/v1';

const seededUser = {
  email: 'testuser@example.com',
  password: 'Password123',
};

const lockedUser = {
  email: 'lockeduser@example.com',
  password: 'Password123',
};

test.describe.serial('Comprehensive Authentication Flow', () => {

  // Before all tests, seed the necessary users in the backend.
  test.beforeAll(async ({ request }) => {
    // Seed an active user
    const activeResponse = await request.post(`${API_URL}/test/seed-user`, {
      data: { ...seededUser, status: 'ACTIVE' },
    });
    expect(activeResponse.ok()).toBeTruthy();

    // Seed a locked user
    const lockedResponse = await request.post(`${API_URL}/test/seed-user`, {
      data: { ...lockedUser, status: 'LOCKED' },
    });
    expect(lockedResponse.ok()).toBeTruthy();
  });

  test('Scenario 1: Should prevent access to protected routes', async ({ page }) => {
    await page.goto(`${UI_URL}/dashboard`);
    await page.waitForURL(`${UI_URL}/login`);
    expect(page.url()).toBe(`${UI_URL}/login`);
  });

  test('Scenario 2: Should show an error for invalid credentials', async ({ page }) => {
    await page.goto(`${UI_URL}/login`);
    await page.fill('input[name="email"]', seededUser.email);
    await page.fill('input[name="password"]', 'wrongpassword');
    await page.click('button[type="submit"]');
    const error = await page.waitForSelector('text=invalid credentials');
    expect(error).not.toBeNull();
  });

  test('Scenario 3: Should show an error for a locked account', async ({ page }) => {
    await page.goto(`${UI_URL}/login`);
    await page.fill('input[name="email"]', lockedUser.email);
    await page.fill('input[name="password"]', lockedUser.password);
    await page.click('button[type="submit"]');
    const error = await page.waitForSelector('text=Account is locked');
    expect(error).not.toBeNull();
  });

  test('Scenario 4: Should allow a new user to register successfully', async ({ page }) => {
    const newUserEmail = `new_user_${Date.now()}@example.com`;
    await page.goto(`${UI_URL}/register`);
    await page.fill('input[name="name"]', 'New User');
    await page.fill('input[name="email"]', newUserEmail);
    await page.fill('input[name="password"]', 'Password123');
    await page.click('button[type="submit"]');
    
    const toast = await page.waitForSelector('text=Registration successful');
    expect(toast).not.toBeNull();
    await page.waitForURL(`${UI_URL}/login`);
    expect(page.url()).toBe(`${UI_URL}/login`);
  });

  test('Scenario 5: Should perform a full login and logout cycle', async ({ page }) => {
    // Login
    await page.goto(`${UI_URL}/login`);
    await page.fill('input[name="email"]', seededUser.email);
    await page.fill('input[name="password"]', seededUser.password);
    await page.click('button[type="submit"]');
    
    // Verify redirection and dashboard content
    await page.waitForURL(`${UI_URL}/dashboard`);
    expect(page.url()).toContain('/dashboard');
    const welcomeMessage = await page.waitForSelector('text=Welcome back');
    expect(welcomeMessage).not.toBeNull();

    // Logout
    await page.click('button[aria-label="Open user menu"]');
    await page.click('text=Log out');
    
    // Verify redirection to login
    await page.waitForURL(`${UI_URL}/login`);
    expect(page.url()).toBe(`${UI_URL}/login`);
  });
}); 