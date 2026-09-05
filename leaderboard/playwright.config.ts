import { defineConfig, devices } from '@playwright/test'

export default defineConfig({
  testDir: './tests/browser',
  fullyParallel: true,
  forbidOnly: Boolean(process.env.CI),
  use: { baseURL: 'http://127.0.0.1:3187', trace: 'retain-on-failure' },
  projects: [
    { name: 'desktop', use: { ...devices['Desktop Chrome'] } },
    { name: 'mobile', use: { ...devices['iPhone 13'], defaultBrowserType: 'chromium' } },
  ],
  webServer: {
    command: 'node .output/server/index.mjs',
    url: 'http://127.0.0.1:3187',
    env: { HOST: '127.0.0.1', PORT: '3187', NUXT_PUBLIC_CONVEX_URL: 'https://leaderboard-test.convex.cloud' },
    reuseExistingServer: false,
  },
})
