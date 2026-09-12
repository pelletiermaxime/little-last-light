import { v } from 'convex/values'

export const achievementId = v.union(v.literal('first_tower'), v.literal('defeat_drencher'), v.literal('defeat_rainkeeper'), v.literal('defeat_snuffer'))
export const catalog = [
  { id: 'first_tower', name: 'Growing the Light', description: 'Buy your first tower.' },
  { id: 'defeat_drencher', name: 'Out of the Water', description: 'Defeat the Drencher.' },
  { id: 'defeat_rainkeeper', name: 'After the Rain', description: 'Defeat the Rainkeeper.' },
  { id: 'defeat_snuffer', name: 'Last Light Standing', description: 'Defeat the Snuffer.' },
] as const
export type AchievementId = typeof catalog[number]['id']

export function validateAchievements(value: unknown) {
  if (!value || typeof value !== 'object') throw new Error('Invalid achievements.')
  const { token, unlocked } = value as Record<string, unknown>
  if (typeof token !== 'string' || !/^[a-f0-9]{64}$/.test(token)) throw new Error('Invalid player identity.')
  if (!Array.isArray(unlocked) || unlocked.length > catalog.length || unlocked.some(id => !catalog.some(entry => entry.id === id))) {
    throw new Error('Unknown achievement or too many achievements.')
  }
  return { token, unlocked: [...new Set(unlocked)] as AchievementId[] }
}
