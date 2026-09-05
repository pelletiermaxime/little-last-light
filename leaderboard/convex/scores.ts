import { v } from 'convex/values'
import { internalMutation, query } from './_generated/server'
import { validVersion } from './validation'

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
    const rows = await ctx.db.query('scores').withIndex('by_version_score', q => q.eq('version', version)).order('desc').take(100)
    return rows.map((row, index) => ({ rank: index + 1, username: row.username, durationMs: row.durationMs, achievedAt: row.achievedAt }))
  },
})

export const submit = internalMutation({
  args: { version: v.string(), playerHash: v.string(), username: v.string(), durationMs: v.number() },
  handler: async (ctx, args) => {
    const previous = await ctx.db.query('scores').withIndex('by_player_version', q => q.eq('playerHash', args.playerHash).eq('version', args.version)).unique()
    if (previous && previous.durationMs >= args.durationMs) return { ok: true }
    const latest = await ctx.db.query('scores').withIndex('by_player_time', q => q.eq('playerHash', args.playerHash)).order('desc').first()
    if (latest && Date.now() - latest.achievedAt < 5000) return { ok: false, error: 'Please wait a few seconds before publishing again.' }
    const score = { ...args, achievedAt: Date.now() }
    if (previous) await ctx.db.patch(previous._id, score)
    else await ctx.db.insert('scores', score)
    return { ok: true }
  },
})
