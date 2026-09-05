import { expect, test } from '@playwright/test'
import { mockConvex } from './convex-fixture'

const keeper = { rank: 1, username: 'EmberKeeper', durationMs: 65125, achievedAt: 1 }

test('receives new records and discovers releases without refresh', async ({ page }) => {
  const server = await mockConvex(page)
  await page.goto('/')
  await expect(page.getByText('No lights recorded yet.', { exact: false })).toBeVisible()
  server.publish({ '0.1.0': [keeper] })
  await expect(page.getByLabel('Game version')).toHaveValue('0.1.0')
  await expect(page.getByRole('cell', { name: '01:05.125' })).toBeVisible()
  server.publish({ '0.1.0': [{ ...keeper, durationMs: 85001 }], '0.2.0': [{ ...keeper, username: 'NewRelease' }] })
  await expect(page.getByRole('cell', { name: '01:25.001' })).toBeVisible()
  await expect(page.getByLabel('Game version').locator('option')).toHaveText(['v0.1.0', 'v0.2.0'])
  await expect(page.getByLabel('Game version')).toHaveValue('0.1.0')
  await expect(page.getByRole('button', { name: 'Refresh' })).toHaveCount(0)
})

test('deep links to empty releases and switches the active subscription', async ({ page }, testInfo) => {
  const errors: string[] = []
  page.on('pageerror', error => errors.push(error.message))
  const server = await mockConvex(page, { '0.1.0': [keeper] })
  await page.goto('/?version=0.3.0')
  await expect(page.getByText('No lights recorded for v0.3.0 yet.', { exact: false })).toBeVisible()
  await page.getByLabel('Game version').selectOption('0.1.0')
  await expect(page.getByRole('cell', { name: 'EmberKeeper' })).toBeVisible()
  expect(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth)).toBe(true)
  await page.screenshot({ path: testInfo.outputPath('leaderboard.png'), fullPage: true })
  await expect.poll(() => server.subscriptions().filter(query => query.udfPath.endsWith(':list')).map(query => query.args[0]?.version)).toEqual(['0.1.0'])
  server.publish({ '0.1.0': [keeper], '0.3.0': [{ ...keeper, username: 'OtherVersion' }] })
  await expect(page.getByRole('cell', { name: 'OtherVersion' })).toHaveCount(0)
  expect(errors).toEqual([])
})

test('recovers after a subscription error', async ({ page }) => {
  const server = await mockConvex(page, { '0.1.0': [keeper] })
  server.fail(true)
  await page.goto('/?version=0.1.0')
  await expect.poll(() => server.subscriptions().length).toBe(2)
  await expect(page.getByText('We couldn’t reach the leaderboard.', { exact: false })).toBeVisible()
  server.fail(false)
  await expect(page.getByRole('cell', { name: 'EmberKeeper' })).toBeVisible()
})
