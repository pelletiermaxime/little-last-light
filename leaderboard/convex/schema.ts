import { defineSchema, defineTable } from 'convex/server'
import { v } from 'convex/values'
import { turretLayoutValidator } from './runDetails'

export default defineSchema({
  scores: defineTable({
    version: v.string(), playerHash: v.string(), username: v.string(),
    durationMs: v.number(), achievedAt: v.number(),
    turretLayout: v.optional(turretLayoutValidator),
    energyEarned: v.optional(v.number()), energyInvested: v.optional(v.number()),
    // Older preview clients reported unspent energy; never reinterpret it as investment.
    totalEnergy: v.optional(v.number()),
  })
    .index('by_version_score', ['version', 'durationMs'])
    .index('by_player_version', ['playerHash', 'version'])
    .index('by_player_time', ['playerHash', 'achievedAt']),
})
