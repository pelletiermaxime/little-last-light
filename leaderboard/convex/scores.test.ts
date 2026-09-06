/// <reference types="vite/client" />
import { convexTest } from 'convex-test'
import { afterEach, describe, expect, it, vi } from 'vitest'
import schema from './schema'
import { validateScore } from './validation'
import { api } from './_generated/api'
import { MAX_SCORE_BODY_LENGTH, MAX_TURRETS } from './runDetails'

const modules = import.meta.glob('./**/*.{ts,js}')
const token = 'a'.repeat(64)
const payload = { token, version: '0.1.0', username: 'Keeper', durationMs: 65000 }
const turretLayout = { width: 960, height: 720, turrets: [{ x: 0.25, y: 0.4 }, { x: 0.75, y: 0.6 }], upgrades: { damage: 0, fireRate: 0, health: 0 } }
const detailedPayload = { ...payload, energyEarned: 125.75, energyInvested: 20, turretLayout }
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
    expect((await post(t, { ...payload, extra: 'x'.repeat(MAX_SCORE_BODY_LENGTH) })).status).toBe(413)
    expect((await t.fetch('/scores?version=invalid')).status).toBe(400)
    const preflight = await t.fetch('/scores', { method: 'OPTIONS' })
    expect(preflight.status).toBe(204)
    expect(preflight.headers.get('Access-Control-Allow-Origin')).toBe('*')
    expect(() => validateScore({ ...payload, durationMs: Infinity })).toThrow()
    await expect(t.query(api.scores.list, { version: 'latest' })).rejects.toThrow('Invalid game version')
  })

  it('keeps run details with the best score and removes stale details when an old client improves it', async () => {
    vi.useFakeTimers({ toFake: ['Date'] })
    const t = convexTest(schema, modules)
    expect((await post(t, detailedPayload)).status).toBe(200)
    expect((await board(t))[0]).toEqual({ rank: 1, username: 'Keeper', durationMs: 65000, achievedAt: Date.now(), energyEarned: 125.75, energyInvested: 20, turretLayout })
    expect((await t.query(api.scores.list, { version: '0.1.0' }))[0]?.turretLayout).toEqual(turretLayout)
    for (const durationMs of [65000, 1000]) {
      expect((await post(t, { ...detailedPayload, durationMs, energyEarned: 0, energyInvested: 0, turretLayout: { ...turretLayout, turrets: [] } })).status).toBe(200)
    }
    expect((await board(t))[0]).toMatchObject({ energyEarned: 125.75, energyInvested: 20, turretLayout })
    vi.setSystemTime(Date.now() + 6000)
    const improvedLayout = { ...turretLayout, turrets: [{ x: 0, y: 1 }] }
    expect((await post(t, { ...detailedPayload, durationMs: 70000, energyEarned: 200, energyInvested: 0, turretLayout: improvedLayout })).status).toBe(200)
    expect((await board(t))[0]).toMatchObject({ durationMs: 70000, energyEarned: 200, energyInvested: 0, turretLayout: improvedLayout })
    vi.setSystemTime(Date.now() + 6000)
    expect((await post(t, { ...payload, durationMs: 80000 })).status).toBe(200)
    expect(Object.keys((await board(t))[0]).sort()).toEqual(['achievedAt', 'durationMs', 'rank', 'username'])
  })

  it('validates energy and bounded layouts while accepting zero energy and old clients', async () => {
    const t = convexTest(schema, modules)
    const invalidDetails = [
      { energyEarned: -1 }, { energyInvested: -1 }, { energyInvested: '20' }, { energyInvested: null },
      { energyEarned: 10, totalEnergy: 9 },
      { turretLayout: null }, { turretLayout: {} },
      { turretLayout: { ...turretLayout, upgrades: null } },
      { turretLayout: { ...turretLayout, upgrades: { damage: -1, fireRate: 0, health: 0 } } },
      { turretLayout: { ...turretLayout, upgrades: { damage: 0, fireRate: 1.5, health: 0 } } },
      { turretLayout: { ...turretLayout, upgrades: { damage: 0, fireRate: 0 } } },
      { turretLayout: { ...turretLayout, width: 0 } },
      { turretLayout: { ...turretLayout, height: 16385 } },
      { turretLayout: { ...turretLayout, turrets: 'bad' } },
      { turretLayout: { ...turretLayout, turrets: [null] } },
      ...[{ x: -0.1, y: 0 }, { x: 0, y: 1.1 }, { x: '0', y: 0 }, { x: 0 }].map(point => ({ turretLayout: { ...turretLayout, turrets: [point] } })),
      { turretLayout: { ...turretLayout, turrets: Array.from({ length: MAX_TURRETS + 1 }, () => ({ x: 0.5, y: 0.5 })) } },
    ]
    for (const details of invalidDetails) expect((await post(t, { ...payload, ...details })).status).toBe(400)
    for (const energy of [NaN, Infinity, Number.MAX_SAFE_INTEGER + 1]) {
      expect(() => validateScore({ ...payload, energyInvested: energy })).toThrow()
    }
    expect(() => validateScore({ ...payload, turretLayout: { ...turretLayout, turrets: [{ x: NaN, y: 0 }] } })).toThrow()
    expect((await post(t, { ...payload, energyEarned: 0, energyInvested: 0, turretLayout: { ...turretLayout, turrets: [] } })).status).toBe(200)
    expect((await board(t))[0]).toMatchObject({ energyEarned: 0, energyInvested: 0, turretLayout: { ...turretLayout, turrets: [] } })
    // Larger than the previous 2KB request limit; all positions must survive.
    const manyTurrets = Array.from({ length: MAX_TURRETS }, (_, i) => ({ x: i / MAX_TURRETS, y: 0.5 }))
    expect((await post(t, { ...payload, token: 'c'.repeat(64), turretLayout: { ...turretLayout, turrets: manyTurrets } })).status).toBe(200)
    expect((await board(t)).find((row: { turretLayout: typeof turretLayout }) => row.turretLayout.turrets.length === MAX_TURRETS)?.turretLayout.turrets).toEqual(manyTurrets)
  })

  it('never presents an older available-energy balance as defense investment', async () => {
    const t = convexTest(schema, modules)
    expect((await post(t, { ...payload, energyEarned: 60, totalEnergy: 5000, turretLayout })).status).toBe(200)
    const rows = await board(t)
    expect(rows[0].energyEarned).toBe(60)
    expect(rows[0]).not.toHaveProperty('energyInvested')
    expect(rows[0]).not.toHaveProperty('totalEnergy')
    const liveRows = await t.query(api.scores.list, { version: '0.1.0' })
    expect(liveRows[0]).not.toHaveProperty('energyInvested')
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
