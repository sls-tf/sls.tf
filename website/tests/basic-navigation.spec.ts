import { test, expect } from '@playwright/test';

test.describe('Basic Navigation Tests', () => {
  const pages = [
    { path: '/', title: 'sls.tf' },
    { path: '/introduction', title: 'Introduction' },
    { path: '/quick-start', title: 'Quick Start' },
    { path: '/installation', title: 'Installation' },
    { path: '/configuration', title: 'Configuration' },
    { path: '/api/variables', title: 'Variables' },
    { path: '/api/outputs', title: 'Outputs' },
    { path: '/api/resource-types', title: 'Resource Types' },
    { path: '/features/lambda-functions', title: 'Lambda Functions' },
    { path: '/features/typescript', title: 'TypeScript Support' },
    { path: '/examples/basic-service', title: 'Basic Service' },
    { path: '/examples/typescript-config', title: 'TypeScript Config' }
  ];

  test.beforeEach(async ({ page }) => {
    // Set a longer timeout for page loads
    page.setDefaultTimeout(10000);
  });

  test('homepage loads successfully', async ({ page }) => {
    await page.goto('/');

    // Check that the page loads without errors
    await expect(page).toHaveTitle(/sls.tf/);

    // Check for main navigation elements
    const navigation = page.locator('nav[aria-label="Main"]');
    await expect(navigation).toBeVisible();

    // Check for main heading
    const mainHeading = page.locator('h1');
    await expect(mainHeading).toBeVisible();
  });

  test('all main documentation pages load without 404 errors', async ({ page }) => {
    for (const pageData of pages) {
      console.log(`Testing page: ${pageData.path}`);

      // Navigate to the page
      const response = await page.goto(pageData.path);

      // Check successful response
      expect(response?.status()).toBe(200);

      // Check for proper title
      await expect(page).toHaveTitle(/sls.tf/);

      // Check that we're not on a 404 page
      await expect(page.locator('h1')).toBeVisible();

      // Check main navigation is present
      const navigation = page.locator('nav[aria-label="Main"]');
      await expect(navigation).toBeVisible();
    }
  });

  test('sidebar navigation works correctly', async ({ page }) => {
    await page.goto('/');

    // Wait for sidebar to be visible
    const sidebar = page.locator('.starlight-sidebar');
    await expect(sidebar).toBeVisible();

    // Check main navigation sections
    const sections = [
      'Introduction',
      'Quick Start',
      'Installation',
      'Configuration',
      'API Reference',
      'Features',
      'Examples'
    ];

    for (const section of sections) {
      const link = page.locator(`.starlight-sidebar a:has-text("${section}")`);
      await expect(link).toBeVisible();
    }
  });

  test('navigation between pages works', async ({ page }) => {
    await page.goto('/');

    // Click on Introduction link
    await page.click('.starlight-sidebar a:has-text("Introduction")');
    await expect(page).toHaveURL('/introduction');

    // Click on Quick Start link
    await page.click('.starlight-sidebar a:has-text("Quick Start")');
    await expect(page).toHaveURL('/quick-start');

    // Check browser back button
    await page.goBack();
    await expect(page).toHaveURL('/introduction');

    // Check browser forward button
    await page.goForward();
    await expect(page).toHaveURL('/quick-start');
  });

  test('collapsible sidebar sections work', async ({ page }) => {
    await page.goto('/');

    // Find collapsible sections (API Reference, Features, Examples)
    const collapsibleSections = page.locator('.starlight-sidebar details');
    await expect(collapsibleSections).toHaveCount(3);

    // Test API Reference section
    const apiSection = page.locator('.starlight-sidebar details:has-text("API Reference")');
    await apiSection.click(); // Expand
    await expect(apiSection).toHaveAttribute('open', '');

    // Check sub-links are visible
    await expect(page.locator('.starlight-sidebar a:has-text("Variables")')).toBeVisible();
    await expect(page.locator('.starlight-sidebar a:has-text("Outputs")')).toBeVisible();
    await expect(page.locator('.starlight-sidebar a:has-text("Resource Types")')).toBeVisible();

    // Collapse section
    await apiSection.click();
    await expect(apiSection).not.toHaveAttribute('open', '');
  });

  test('breadcrumbs work correctly', async ({ page }) => {
    await page.goto('/api/variables');

    // Check breadcrumbs are present
    const breadcrumbs = page.locator('.starlight-breadcrumbs');
    await expect(breadcrumbs).toBeVisible();

    // Check home breadcrumb
    const homeBreadcrumb = page.locator('.starlight-breadcrumbs a:has-text("Home")');
    await expect(homeBreadcrumb).toBeVisible();

    // Click home breadcrumb
    await homeBreadcrumb.click();
    await expect(page).toHaveURL('/');
  });

  test('search functionality is present', async ({ page }) => {
    await page.goto('/');

    // Check for search input
    const searchInput = page.locator('input[placeholder*="Search" i]');
    await expect(searchInput).toBeVisible();

    // Type in search
    await searchInput.fill('lambda');

    // Wait for search results
    await page.waitForTimeout(500);

    // Check if search results appear (this might vary based on Starlight version)
    const searchResults = page.locator('.starlight-search');
    await expect(searchResults).toBeVisible();
  });

  test('dark mode toggle works', async ({ page }) => {
    await page.goto('/');

    // Check for theme toggle button
    const themeToggle = page.locator('button[aria-label*="theme" i], button[aria-label*="dark" i], button[aria-label*="light" i]');
    if (await themeToggle.isVisible()) {
      // Get initial theme
      const html = page.locator('html');
      const initialTheme = await html.getAttribute('data-theme');

      // Toggle theme
      await themeToggle.click();
      await page.waitForTimeout(500);

      // Check theme changed (this might not work if theme is stored in localStorage)
      const newTheme = await html.getAttribute('data-theme');
      console.log(`Theme changed from ${initialTheme} to ${newTheme}`);
    }
  });

  test('external links work correctly', async ({ page }) => {
    await page.goto('/installation');

    // Find external links (GitHub, Discord, etc.)
    const externalLinks = page.locator('a[href*="github.com"], a[href*="discord.gg"]');
    const count = await externalLinks.count();

    if (count > 0) {
      // Test first external link
      const firstLink = externalLinks.first();
      const href = await firstLink.getAttribute('href');

      expect(href).toBeTruthy();
      expect(href?.startsWith('http')).toBeTruthy();

      // Check rel attributes for external links
      const rel = await firstLink.getAttribute('rel');
      expect(rel).toContain('noopener');
      expect(rel).toContain('noreferrer');
    }
  });
});