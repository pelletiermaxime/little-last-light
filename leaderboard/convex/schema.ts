import { defineSchema, defineTable } from 'convex/server'
import { v } from 'convex/values'

export default defineSchema({
  scores: defineTable({
    version: v.string(), playerHash: v.string(), username: v.string(),
    durationMs: v.number(), achievedAt: v.number(),
  })
    .index('by_version_score', ['version', 'durationMs'])
    .index('by_player_version', ['playerHash', 'version'])
    .index('by_player_time', ['playerHash', 'achievedAt']),
})
