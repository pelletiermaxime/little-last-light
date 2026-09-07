import { v } from 'convex/values'
import { internalMutation, query } from './_generated/server'
import { validVersion } from './validation'
import { turretLayoutValidator } from './runDetails'

export const versions = query({
  args: {},
  handler: async ctx => {
    const versions: string[] = []
    let after = ''
    // Jump past each version's scores rather than scanning every player's row.
    while (true) {
      const row = await ctx.db.query('scores').withIndex('by_version_score', q => q.gt('version', after)).first()
      if (!row) break
      versions.push(row.version)
      after = row.version
    }
    return versions.sort((a, b) => b.localeCompare(a, undefined, { numeric: true }))
  },
})

export const list = query({
  args: { version: v.string() },
  handler: async (ctx, { version }) => {
    if (!validVersion(version)) throw new Error('Invalid game version.')
    // Optional clear time keeps legacy rows in the survival section without migration.
    const clears = await ctx.db.query('scores').withIndex('by_version_clearTimeMs_durationMs', q => q.eq('version', version).gt('clearTimeMs', 0)).order('asc').take(100)
    const survival = clears.length < 100
      ? await ctx.db.query('scores').withIndex('by_version_clearTimeMs_durationMs', q => q.eq('version', version).eq('clearTimeMs', undefined)).order('desc').take(100 - clears.length)
      : []
    const rows = [...clears, ...survival]
    return rows.map((row, index) => ({
      rank: index + 1, username: row.username, durationMs: row.durationMs, achievedAt: row.achievedAt,
      ...(row.clearTimeMs === undefined ? {} : { clearTimeMs: row.clearTimeMs }),
      ...(row.turretLayout === undefined ? {} : { turretLayout: row.turretLayout }),
      ...(row.energyEarned === undefined ? {} : { energyEarned: row.energyEarned }),
      ...(row.energyInvested === undefined ? {} : { energyInvested: row.energyInvested }),
    }))
  },
})

export const submit = internalMutation({
  args: {
    version: v.string(), playerHash: v.string(), username: v.string(), durationMs: v.number(),
    clearTimeMs: v.optional(v.number()),
    turretLayout: v.optional(turretLayoutValidator),
    energyEarned: v.optional(v.number()), energyInvested: v.optional(v.number()), totalEnergy: v.optional(v.number()),
  },
  handler: async (ctx, args) => {
    const previous = await ctx.db.query('scores').withIndex('by_player_version', q => q.eq('playerHash', args.playerHash).eq('version', args.version)).unique()
    if (previous) {
      const improves = args.clearTimeMs !== undefined
        ? previous.clearTimeMs === undefined || args.clearTimeMs < previous.clearTimeMs
        : previous.clearTimeMs === undefined && args.durationMs > previous.durationMs
      if (!improves) return { ok: true }
    }
    const latest = await ctx.db.query('scores').withIndex('by_player_time', q => q.eq('playerHash', args.playerHash)).order('desc').first()
    if (latest && Date.now() - latest.achievedAt < 5000) return { ok: false, error: 'Please wait a few seconds before publishing again.' }
    const score = { ...args, achievedAt: Date.now() }
    // Replace so a better run from an older client cannot retain another run's layout.
    if (previous) await ctx.db.replace(previous._id, score)
    else await ctx.db.insert('scores', score)
    return { ok: true }
  },
})
