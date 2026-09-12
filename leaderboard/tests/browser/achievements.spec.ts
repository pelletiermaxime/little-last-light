import { expect, test } from '@playwright/test'
import { mockConvex } from './convex-fixture'

test('shows empty populations and live percentages', async ({ page }, testInfo) => {
  const errors: string[] = []
  page.on('pageerror', error => errors.push(error.message))
  const server = await mockConvex(page)
  await page.goto('/')
  const section = page.getByRole('region', { name: 'Small victories against the dark' })
  await expect(section.getByText('0 tracked players', { exact: false })).toBeVisible()
  await expect(section.getByText('—', { exact: true })).toHaveCount(4)
  server.achievements(20, [15, 10, 3, 1])
  await expect(section.getByText('20 tracked players', { exact: false })).toBeVisible()
  await expect(section.getByText('75%', { exact: true })).toBeVisible()
  await expect(section.getByText('5%', { exact: true })).toBeVisible()
  expect(await section.evaluate(element => element.scrollWidth <= element.clientWidth)).toBe(true)
  await section.screenshot({ path: testInfo.outputPath('achievements.png') })
  expect(errors).toEqual([])
})

test('recovers when achievements initially fail to load', async ({ page }) => {
  const server = await mockConvex(page)
  server.fail(true)
  await page.goto('/')
  const section = page.getByRole('region', { name: 'Small victories against the dark' })
  await expect(section.getByRole('button', { name: 'Retry achievements' })).toBeVisible()
  server.fail(false)
  await expect(section.getByText('0 tracked players', { exact: false })).toBeVisible()
})
