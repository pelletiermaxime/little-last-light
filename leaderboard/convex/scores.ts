import { v } from 'convex/values'
import { internalMutation, query } from './_generated/server'
import type { QueryCtx } from './_generated/server'
import type { Doc } from './_generated/dataModel'
import { minorVersion, validBoardVersion } from './versions'
import { turretLayoutValidator } from './runDetails'

async function storedVersions(ctx: QueryCtx, minor?: string) {
  const versions: string[] = []
  let after = minor && minor !== 'dev' ? `${minor}.` : ''
  // Jump over each patch's rows using the existing index, including old scores.
  while (true) {
    const row = await ctx.db.query('scores').withIndex('by_version_score', q => q.gt('version', after)).first()
    if (!row || (minor && minorVersion(row.version) !== minor)) break
    versions.push(row.version)
    after = row.version
  }
  return versions
}

function compareScores(a: Doc<'scores'>, b: Doc<'scores'>) {
  if (a.clearTimeMs !== undefined || b.clearTimeMs !== undefined) {
    if (a.clearTimeMs === undefined) return 1
    if (b.clearTimeMs === undefined) return -1
    if (a.clearTimeMs !== b.clearTimeMs) return a.clearTimeMs - b.clearTimeMs
  } else if (a.durationMs !== b.durationMs) return b.durationMs - a.durationMs
  return a.achievedAt - b.achievedAt || a._id.localeCompare(b._id)
}

export const versions = query({
  args: {},
  handler: async ctx => {
    const versions = [...new Set((await storedVersions(ctx)).map(minorVersion))]
    return versions.sort((a, b) => b.localeCompare(a, undefined, { numeric: true }))
  },
})

export const list = query({
  args: { version: v.string() },
  handler: async (ctx, { version }) => {
    if (!validBoardVersion(version)) throw new Error('Invalid game version.')
    const minor = minorVersion(version)
    const patches = minor === 'dev' ? ['dev'] : await storedVersions(ctx, minor)
    const bestByPlayer = new Map<string, Doc<'scores'>>()
    for (const patch of patches) {
      // Optional clear time keeps legacy rows in the survival section without migration.
      const clears = await ctx.db.query('scores').withIndex('by_version_clearTimeMs_durationMs', q => q.eq('version', patch).gt('clearTimeMs', 0)).order('asc').take(100)
      const survival = clears.length < 100
        ? await ctx.db.query('scores').withIndex('by_version_clearTimeMs_durationMs', q => q.eq('version', patch).eq('clearTimeMs', undefined)).order('desc').take(100 - clears.length)
        : []
      // Each patch has one row per device. Its top 100 suffice for a global top 100.
      for (const row of [...clears, ...survival]) {
        const previous = bestByPlayer.get(row.playerHash)
        if (!previous || compareScores(row, previous) < 0) bestByPlayer.set(row.playerHash, row)
      }
    }
    const rows = [...bestByPlayer.values()].sort(compareScores).slice(0, 100)
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
