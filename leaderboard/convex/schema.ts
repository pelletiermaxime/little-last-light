import { defineSchema, defineTable } from 'convex/server'
import { v } from 'convex/values'
import { turretLayoutValidator } from './runDetails'
import { achievementId } from './achievementCatalog'

export default defineSchema({
  achievementPlayers: defineTable({ playerHash: v.string(), joinedAt: v.number() })
    .index('by_playerHash', ['playerHash']),
  playerAchievements: defineTable({ playerHash: v.string(), achievementId, unlockedAt: v.number() })
    .index('by_playerHash_achievementId', ['playerHash', 'achievementId']),
  achievementCounts: defineTable({ key: v.string(), count: v.number() })
    .index('by_key', ['key']),
  scores: defineTable({
    version: v.string(), playerHash: v.string(), username: v.string(),
    durationMs: v.number(), achievedAt: v.number(),
    // M16: total time through the killing blow; durationMs is 900000 for clears.
    // Missing means a survival-only record, including all historical clients.
    clearTimeMs: v.optional(v.number()),
    turretLayout: v.optional(turretLayoutValidator),
    energyEarned: v.optional(v.number()), energyInvested: v.optional(v.number()),
    // Older preview clients reported unspent energy; never reinterpret it as investment.
    totalEnergy: v.optional(v.number()),
  })
    .index('by_version_score', ['version', 'durationMs'])
    .index('by_version_clearTimeMs_durationMs', ['version', 'clearTimeMs', 'durationMs'])
    .index('by_player_version', ['playerHash', 'version'])
    .index('by_player_time', ['playerHash', 'achievedAt']),
})
