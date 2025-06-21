import { test, expect } from '@playwright/test';

const users = [
  { email: 'orgadmin@example.com', password: 'Password123!', role: 'ORG_ADMIN' },
  { email: 'agentadmin@example.com', password: 'Password123!', role: 'AGENT_ADMIN' },
  { email: 'agentuser@example.com', password: 'Password123!', role: 'AGENT_USER' },
  { email: 'complianceuser@example.com', password: 'Password123!', role: 'COMPLIANCE_USER' },
  { email: 'orguser@example.com', password: 'Password123!', role: 'ORG_USER' },
];

test.describe('Dashboard role and logout tests', () => {
  for (const user of users) {
    test(`Dashboard and logout for ${user.role}`, async ({ page }) => {
      // Go to login page
      await page.goto('/login');
      // Fill in credentials
      await page.fill('input[type="email"]', user.email);
      await page.fill('input[type="password"]', user.password);
      // Submit login form
      await page.click('button[type="submit"]');
      // Wait for dashboard
      await page.waitForURL('**/dashboard');
      // Check welcome message
      await expect(page.locator('h1')).toContainText(user.email);
      // Check role indicator
      await expect(page.locator('span')).toContainText(`Role: ${user.role}`);
      // Open user menu and click logout
      await page.click('button[aria-label="Open user menu"]');
      await page.click('text=Log out');
      // Should be redirected to login
      await page.waitForURL('**/login');
      // Optionally, check session is cleared
      await expect(page.locator('input[type="email"]')).toBeVisible();
    });
  }
}); 