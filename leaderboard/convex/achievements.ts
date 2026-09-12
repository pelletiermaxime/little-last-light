import { v } from 'convex/values'
import { internalMutation, query } from './_generated/server'
import type { MutationCtx } from './_generated/server'
import { achievementId, catalog } from './achievementCatalog'

async function increment(ctx: MutationCtx, key: string) {
  const counter = await ctx.db.query('achievementCounts').withIndex('by_key', q => q.eq('key', key)).unique()
  if (counter) await ctx.db.patch(counter._id, { count: counter.count + 1 })
  else await ctx.db.insert('achievementCounts', { key, count: 1 })
}

export const sync = internalMutation({
  args: { playerHash: v.string(), unlocked: v.array(achievementId) },
  handler: async (ctx, { playerHash, unlocked }) => {
    const player = await ctx.db.query('achievementPlayers').withIndex('by_playerHash', q => q.eq('playerHash', playerHash)).unique()
    if (!player) {
      await ctx.db.insert('achievementPlayers', { playerHash, joinedAt: Date.now() })
      await increment(ctx, 'players')
    }
    for (const id of new Set(unlocked)) {
      const previous = await ctx.db.query('playerAchievements').withIndex('by_playerHash_achievementId', q => q.eq('playerHash', playerHash).eq('achievementId', id)).unique()
      if (previous) continue
      await ctx.db.insert('playerAchievements', { playerHash, achievementId: id, unlockedAt: Date.now() })
      await increment(ctx, id)
    }
    // Registration, unlocks and counters commit together; retries cannot double-count.
    return { ok: true }
  },
})

export const stats = query({
  args: {},
  handler: async ctx => {
    const total = await ctx.db.query('achievementCounts').withIndex('by_key', q => q.eq('key', 'players')).unique()
    const totalPlayers = total?.count ?? 0
    const achievements = await Promise.all(catalog.map(async entry => {
      const counter = await ctx.db.query('achievementCounts').withIndex('by_key', q => q.eq('key', entry.id)).unique()
      const unlockedPlayers = counter?.count ?? 0
      return { ...entry, unlockedPlayers, percentage: totalPlayers ? unlockedPlayers / totalPlayers * 100 : 0 }
    }))
    return { totalPlayers, achievements }
  },
})
