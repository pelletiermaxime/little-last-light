import { httpRouter } from 'convex/server'
import { httpAction } from './_generated/server'
import { api, internal } from './_generated/api'
import { validateScore } from './validation'
import { validBoardVersion } from './versions'
import { MAX_SCORE_BODY_LENGTH } from './runDetails'
import { validateAchievements } from './achievementCatalog'

const http = httpRouter()
const headers = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type',
  'Content-Type': 'application/json',
}
const json = (body: unknown, status = 200) => new Response(JSON.stringify(body), { status, headers })

async function hashToken(token: string) {
  const digest = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(token))
  return Array.from(new Uint8Array(digest), b => b.toString(16).padStart(2, '0')).join('')
}

http.route({ path: '/achievements', method: 'GET', handler: httpAction(async ctx => {
  return json(await ctx.runQuery(api.achievements.stats, {}))
}) })
http.route({ path: '/achievements', method: 'OPTIONS', handler: httpAction(async () => new Response(null, { status: 204, headers })) })
http.route({ path: '/achievements', method: 'POST', handler: httpAction(async (ctx, request) => {
  if (!request.headers.get('content-type')?.startsWith('application/json')) return json({ error: 'Expected JSON.' }, 415)
  const body = await request.text()
  if (body.length > 4096) return json({ error: 'Request is too large.' }, 413)
  let data: ReturnType<typeof validateAchievements>
  try { data = validateAchievements(JSON.parse(body)) }
  catch (error) { return json({ error: error instanceof Error ? error.message : 'Invalid achievements.' }, 400) }
  const { token, ...progress } = data
  return json(await ctx.runMutation(internal.achievements.sync, { ...progress, playerHash: await hashToken(token) }))
}) })

http.route({ path: '/versions', method: 'GET', handler: httpAction(async ctx => {
  return json(await ctx.runQuery(api.scores.versions, {}))
}) })
http.route({ path: '/scores', method: 'GET', handler: httpAction(async (ctx, request) => {
  const version = new URL(request.url).searchParams.get('version') ?? ''
  if (!validBoardVersion(version)) return json({ error: 'Invalid game version.' }, 400)
  return json(await ctx.runQuery(api.scores.list, { version }))
}) })
http.route({ path: '/scores', method: 'OPTIONS', handler: httpAction(async () => new Response(null, { status: 204, headers })) })
http.route({ path: '/scores', method: 'POST', handler: httpAction(async (ctx, request) => {
  if (!request.headers.get('content-type')?.startsWith('application/json')) return json({ error: 'Expected JSON.' }, 415)
  const body = await request.text()
  if (body.length > MAX_SCORE_BODY_LENGTH) return json({ error: 'Request is too large.' }, 413)
  let score: ReturnType<typeof validateScore>
  try { score = validateScore(JSON.parse(body)) }
  catch (error) { return json({ error: error instanceof Error ? error.message : 'Invalid score.' }, 400) }
  const { token, ...publicScore } = score
  const playerHash = await hashToken(token)
  const result = await ctx.runMutation(internal.scores.submit, { ...publicScore, playerHash })
  return json(result, result.ok ? 200 : 409)
}) })
export default http
