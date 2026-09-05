export function validVersion(version: string) {
  return /^(0|[1-9]\d{0,5})\.(0|[1-9]\d{0,5})\.(0|[1-9]\d{0,5})$/.test(version)
}

export function validateScore(value: unknown) {
  if (!value || typeof value !== 'object') throw new Error('Invalid score.')
  const { version, token, username, durationMs } = value as Record<string, unknown>
  if (typeof version !== 'string' || !validVersion(version)) throw new Error('Invalid game version.')
  if (typeof token !== 'string' || !/^[a-f0-9]{64}$/.test(token)) throw new Error('Invalid player identity.')
  if (typeof username !== 'string' || !/^[A-Za-z0-9_]{3,20}$/.test(username.trim())) {
    throw new Error('Use 3–20 letters, numbers, or underscores.')
  }
  if (typeof durationMs !== 'number' || !Number.isSafeInteger(durationMs) || durationMs < 1 || durationMs > 86_400_000) {
    throw new Error('Survival time must be between 1 millisecond and 24 hours.')
  }
  return { version, token, username: username.trim(), durationMs }
}
