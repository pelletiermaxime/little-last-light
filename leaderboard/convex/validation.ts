import { validateTurretLayout } from './runDetails'

export function validVersion(version: string) {
  return version === 'dev' || /^(0|[1-9]\d{0,5})\.(0|[1-9]\d{0,5})\.(0|[1-9]\d{0,5})$/.test(version)
}

export function validateScore(value: unknown) {
  if (!value || typeof value !== 'object') throw new Error('Invalid score.')
  const { version, token, username, durationMs, turretLayout, energyEarned, energyInvested, totalEnergy } = value as Record<string, unknown>
  if (typeof version !== 'string' || !validVersion(version)) throw new Error('Invalid game version.')
  if (typeof token !== 'string' || !/^[a-f0-9]{64}$/.test(token)) throw new Error('Invalid player identity.')
  if (typeof username !== 'string' || !/^[A-Za-z0-9_]{3,20}$/.test(username.trim())) {
    throw new Error('Use 3–20 letters, numbers, or underscores.')
  }
  if (typeof durationMs !== 'number' || !Number.isSafeInteger(durationMs) || durationMs < 1 || durationMs > 86_400_000) {
    throw new Error('Survival time must be between 1 millisecond and 24 hours.')
  }
  for (const energy of [energyEarned, energyInvested, totalEnergy]) {
    if (energy !== undefined && (typeof energy !== 'number' || !Number.isFinite(energy) || energy < 0 || energy > Number.MAX_SAFE_INTEGER)) {
      throw new Error('Energy must be a finite, non-negative number.')
    }
  }
  if (typeof energyEarned === 'number' && typeof totalEnergy === 'number' && totalEnergy < energyEarned) {
    throw new Error('Available energy cannot be less than run earnings.')
  }
  return {
    version, token, username: username.trim(), durationMs,
    ...(turretLayout === undefined ? {} : { turretLayout: validateTurretLayout(turretLayout) }),
    ...(energyEarned === undefined ? {} : { energyEarned: energyEarned as number }),
    ...(energyInvested === undefined ? {} : { energyInvested: energyInvested as number }),
    ...(totalEnergy === undefined ? {} : { totalEnergy: totalEnergy as number }),
  }
}
