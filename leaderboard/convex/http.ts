import { httpRouter } from 'convex/server'
import { httpAction } from './_generated/server'
import { api, internal } from './_generated/api'
import { validVersion, validateScore } from './validation'

const http = httpRouter()
const headers = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type',
  'Content-Type': 'application/json',
}
const json = (body: unknown, status = 200) => new Response(JSON.stringify(body), { status, headers })

http.route({ path: '/versions', method: 'GET', handler: httpAction(async ctx => {
  return json(await ctx.runQuery(api.scores.versions, {}))
}) })
http.route({ path: '/scores', method: 'GET', handler: httpAction(async (ctx, request) => {
  const version = new URL(request.url).searchParams.get('version') ?? ''
  if (!validVersion(version)) return json({ error: 'Invalid game version.' }, 400)
  return json(await ctx.runQuery(api.scores.list, { version }))
}) })
http.route({ path: '/scores', method: 'OPTIONS', handler: httpAction(async () => new Response(null, { status: 204, headers })) })
http.route({ path: '/scores', method: 'POST', handler: httpAction(async (ctx, request) => {
  if (!request.headers.get('content-type')?.startsWith('application/json')) return json({ error: 'Expected JSON.' }, 415)
  const body = await request.text()
  if (body.length > 2048) return json({ error: 'Request is too large.' }, 413)
  let score: ReturnType<typeof validateScore>
  try { score = validateScore(JSON.parse(body)) }
  catch (error) { return json({ error: error instanceof Error ? error.message : 'Invalid score.' }, 400) }
  const { token, ...publicScore } = score
  const digest = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(token))
  const playerHash = Array.from(new Uint8Array(digest), b => b.toString(16).padStart(2, '0')).join('')
  const result = await ctx.runMutation(internal.scores.submit, { ...publicScore, playerHash })
  return json(result, result.ok ? 200 : 409)
}) })
export default http
