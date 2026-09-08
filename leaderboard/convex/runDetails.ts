import { v } from 'convex/values'

// A bounded snapshot fits on the score document; old clients can omit it.
export const MAX_TURRETS = 1024
export const MAX_SCORE_BODY_LENGTH = 128 * 1024
export const turretLayoutValidator = v.object({
  width: v.number(),
  height: v.number(),
  turrets: v.array(v.object({ x: v.number(), y: v.number(), type: v.optional(v.union(v.literal('damage'), v.literal('pulse'), v.literal('sniper'))) })),
  upgrades: v.optional(v.object({ damage: v.number(), fireRate: v.number(), health: v.number() })),
})

export interface TurretLayout {
  width: number
  height: number
  turrets: Array<{ x: number; y: number; type?: 'damage' | 'pulse' | 'sniper' }>
  upgrades?: { damage: number; fireRate: number; health: number }
}

export function validateTurretLayout(value: unknown): TurretLayout {
  if (!value || typeof value !== 'object') throw new Error('Invalid turret layout.')
  const { width, height, turrets, upgrades } = value as Record<string, unknown>
  for (const size of [width, height]) {
    if (typeof size !== 'number' || !Number.isFinite(size) || size < 1 || size > 16384) {
      throw new Error('Invalid arena dimensions.')
    }
  }
  if (!Array.isArray(turrets) || turrets.length > MAX_TURRETS) throw new Error('Invalid turret count.')
  const positions = turrets.map((point): TurretLayout['turrets'][number] => {
    if (!point || typeof point !== 'object') throw new Error('Invalid turret position.')
    const { x, y, type } = point as Record<string, unknown>
    if (typeof x !== 'number' || typeof y !== 'number' || !Number.isFinite(x) || !Number.isFinite(y) || x < 0 || x > 1 || y < 0 || y > 1) {
      throw new Error('Turret positions must be inside the arena.')
    }
    if (type !== undefined && type !== 'damage' && type !== 'pulse' && type !== 'sniper') throw new Error('Invalid turret type.')
    return { x, y, ...(type === undefined ? {} : { type }) }
  })
  let levels: TurretLayout['upgrades']
  if (upgrades !== undefined) {
    if (!upgrades || typeof upgrades !== 'object') throw new Error('Invalid upgrades.')
    const { damage, fireRate, health } = upgrades as Record<string, unknown>
    for (const level of [damage, fireRate, health]) {
      if (typeof level !== 'number' || !Number.isSafeInteger(level) || level < 0 || level > 100) throw new Error('Invalid upgrade level.')
    }
    levels = { damage: damage as number, fireRate: fireRate as number, health: health as number }
  }
  return { width: width as number, height: height as number, turrets: positions, ...(levels === undefined ? {} : { upgrades: levels }) }
}
