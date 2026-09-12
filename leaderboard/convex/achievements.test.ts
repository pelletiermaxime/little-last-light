/// <reference types="vite/client" />
import { convexTest } from 'convex-test'
import { expect, it } from 'vitest'
import schema from './schema'

const modules = import.meta.glob('./**/*.{ts,js}')
const token = 'a'.repeat(64)
const post = (t: ReturnType<typeof convexTest>, unlocked: string[] = [], identity = token) => t.fetch('/achievements', {
  method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ token: identity, unlocked }),
})
const stats = async (t: ReturnType<typeof convexTest>) => (await t.fetch('/achievements')).json()

it('counts zero-unlock players and deduplicates retries, batches and releases', async () => {
  const t = convexTest(schema, modules)
  expect(await stats(t)).toMatchObject({ totalPlayers: 0, achievements: [{ percentage: 0 }, { percentage: 0 }, { percentage: 0 }, { percentage: 0 }] })
  await post(t)
  await post(t, [], 'b'.repeat(64))
  await post(t, ['first_tower', 'first_tower'])
  await post(t, ['first_tower', 'defeat_drencher'])
  await post(t, ['first_tower'])
  const result = await stats(t)
  expect(result.totalPlayers).toBe(2)
  expect(result.achievements.map((a: { unlockedPlayers: number }) => a.unlockedPlayers)).toEqual([1, 1, 0, 0])
  expect(result.achievements.map((a: { percentage: number }) => a.percentage)).toEqual([50, 50, 0, 0])
  expect(JSON.stringify(result)).not.toContain('playerHash')
  expect(JSON.stringify(result)).not.toContain(token)
  const timestamps = await t.run(async ctx => (await ctx.db.query('playerAchievements').collect()).map(row => row.unlockedAt))
  await post(t, ['first_tower', 'defeat_drencher'])
  expect(await t.run(async ctx => (await ctx.db.query('playerAchievements').collect()).map(row => row.unlockedAt))).toEqual(timestamps)
})

it('shares the score hash without needing a username and keeps separate Convex databases independent', async () => {
  const t = convexTest(schema, modules)
  await t.fetch('/scores', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ token, username: 'Keeper', version: '0.1.0', durationMs: 1234 }) })
  await post(t, ['defeat_rainkeeper', 'defeat_snuffer'])
  const hashes = await t.run(async ctx => [(await ctx.db.query('scores').first())?.playerHash, (await ctx.db.query('achievementPlayers').first())?.playerHash])
  expect(hashes[0]).toBe(hashes[1])
  expect(hashes[0]).not.toBe(token)
  const dev = convexTest(schema, modules)
  await post(dev, ['first_tower'])
  expect((await stats(dev)).achievements.map((a: { unlockedPlayers: number }) => a.unlockedPlayers)).toEqual([1, 0, 0, 0])
  expect((await stats(t)).achievements.map((a: { unlockedPlayers: number }) => a.unlockedPlayers)).toEqual([0, 0, 1, 1])
})

it('rejects bad reports without registering players and supports browser preflight', async () => {
  const t = convexTest(schema, modules)
  expect((await post(t, ['invented'])).status).toBe(400)
  expect((await post(t, [], 'bad')).status).toBe(400)
  expect((await t.fetch('/achievements', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: '{' })).status).toBe(400)
  expect((await t.fetch('/achievements', { method: 'POST', body: '{}' })).status).toBe(415)
  expect((await t.fetch('/achievements', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: ' '.repeat(4097) })).status).toBe(413)
  expect((await stats(t)).totalPlayers).toBe(0)
  const cors = await t.fetch('/achievements', { method: 'OPTIONS' })
  expect(cors.status).toBe(204)
  expect(cors.headers.get('Access-Control-Allow-Origin')).toBe('*')
})
