/// <reference types="vite/client" />
import { convexTest } from 'convex-test'
import { afterEach, describe, expect, it, vi } from 'vitest'
import schema from './schema'
import { validateScore } from './validation'
import { api } from './_generated/api'

const modules = import.meta.glob('./**/*.{ts,js}')
const token = 'a'.repeat(64)
const payload = { token, version: '0.1.0', username: 'Keeper', durationMs: 65000 }
const post = (t: ReturnType<typeof convexTest>, data: unknown) => t.fetch('/scores', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(data) })
const board = async (t: ReturnType<typeof convexTest>, version = '0.1.0') => (await t.fetch(`/scores?version=${version}`)).json()
afterEach(() => { vi.useRealTimers(); vi.unstubAllGlobals() })

describe('HTTP leaderboard contract', () => {
  it('isolates releases, orders scores, updates one record and keeps identity private', async () => {
    vi.useFakeTimers({ toFake: ['Date'] })
    const t = convexTest(schema, modules)
    expect(await (await t.fetch('/versions')).json()).toEqual([])
    expect((await post(t, payload)).status).toBe(200)
    expect(await (await t.fetch('/versions')).json()).toEqual(['0.1.0'])
    expect((await post(t, payload)).status).toBe(200)
    expect((await post(t, { ...payload, durationMs: 1000 })).status).toBe(200)
    expect(await board(t, '0.2.0')).toEqual([])
    expect((await post(t, { ...payload, durationMs: 70000 })).status).toBe(409)
    vi.setSystemTime(Date.now() + 6000)
    expect((await post(t, { ...payload, durationMs: 70000, username: 'NewName' })).status).toBe(200)
    await post(t, { ...payload, token: 'b'.repeat(64), durationMs: 75000 })
    const rows = await board(t)
    expect(rows).toHaveLength(2)
    expect(rows.map((r: { durationMs: number }) => r.durationMs)).toEqual([75000, 70000])
    expect(rows[1].username).toBe('NewName')
    expect(Object.keys(rows[0]).sort()).toEqual(['achievedAt', 'durationMs', 'rank', 'username'])
    vi.setSystemTime(Date.now() + 6000)
    await post(t, { ...payload, version: '0.2.0', durationMs: 5000 })
    expect(await board(t, '0.2.0')).toHaveLength(1)
    expect(await board(t)).toHaveLength(2)
    expect(await (await t.fetch('/versions')).json()).toEqual(['0.2.0', '0.1.0'])
  })

  it('accepts new releases without registration, rejects invalid requests and supports browser CORS', async () => {
    const t = convexTest(schema, modules)
    expect((await post(t, payload)).status).toBe(200)
    for (const value of [null, {}, { ...payload, username: '<script>' }, { ...payload, durationMs: -1 }, { ...payload, durationMs: 1.1 }, { ...payload, version: 'latest' }, { ...payload, token: '' }]) {
      expect((await post(t, value)).status).toBe(400)
    }
    expect((await post(t, { ...payload, extra: 'x'.repeat(2100) })).status).toBe(413)
    expect((await t.fetch('/scores?version=invalid')).status).toBe(400)
    const preflight = await t.fetch('/scores', { method: 'OPTIONS' })
    expect(preflight.status).toBe(204)
    expect(preflight.headers.get('Access-Control-Allow-Origin')).toBe('*')
    expect(() => validateScore({ ...payload, durationMs: Infinity })).toThrow()
    await expect(t.query(api.scores.list, { version: 'latest' })).rejects.toThrow('Invalid game version')
  })

  it('caps the public board at 100 and discovers distinct versions in numeric order', async () => {
    const t = convexTest(schema, modules)
    await t.run(async ctx => {
      for (const version of ['0.1.9', '0.1.10', '0.2.0']) await ctx.db.insert('scores', { version, playerHash: version, username: 'Keeper', durationMs: 1000, achievedAt: 1 })
      for (let i = 1; i <= 105; i++) await ctx.db.insert('scores', { version: '0.1.0', playerHash: String(i), username: 'Keeper', durationMs: i * 1000, achievedAt: i })
    })
    expect(await (await t.fetch('/versions')).json()).toEqual(['0.2.0', '0.1.10', '0.1.9', '0.1.0'])
    const rows = await board(t)
    expect(rows).toHaveLength(100)
    expect(rows[0].durationMs).toBe(105000)
    expect(rows[99].rank).toBe(100)
  })
})
