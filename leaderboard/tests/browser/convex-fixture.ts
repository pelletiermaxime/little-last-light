import type { Page, WebSocketRoute } from '@playwright/test'
import type { TurretLayout } from '../../convex/runDetails'

export interface Score { rank: number; username: string; durationMs: number; achievedAt: number; energyEarned?: number; energyInvested?: number; totalEnergy?: number; turretLayout?: TurretLayout }
interface Query { queryId: number; udfPath: string; args: [{ version?: string }] }

export async function mockConvex(page: Page, initial: Record<string, Score[]> = {}) {
  let boards = initial
  let failed = false
  const connections: Array<{ socket: WebSocketRoute; queries: Map<number, Query>; version: { querySet: number; ts: string; identity: number } }> = []
  let tick = 0n
  const timestamp = () => { const bytes = Buffer.alloc(8); bytes.writeBigUInt64LE(++tick); return bytes.toString('base64') }
  const value = (query: Query) => query.udfPath.endsWith(':versions')
    ? Object.keys(boards).filter(version => boards[version]!.length).sort((a, b) => b.localeCompare(a, undefined, { numeric: true }))
    : boards[query.args[0]?.version ?? ''] ?? []
  const update = (connection: typeof connections[number], querySet = connection.version.querySet) => {
    const next = { querySet, ts: timestamp(), identity: 0 }
    connection.socket.send(JSON.stringify({
      type: 'Transition', startVersion: connection.version, endVersion: next,
      modifications: [...connection.queries.values()].map(query => failed
        ? { type: 'QueryFailed', queryId: query.queryId, errorMessage: 'Unavailable', logLines: [], journal: null }
        : { type: 'QueryUpdated', queryId: query.queryId, value: value(query), logLines: [], journal: null }),
    }))
    connection.version = next
  }
  await page.route('https://leaderboard-test.convex.cloud/api/query', route => {
    const request = route.request().postDataJSON()
    return route.fulfill({ json: failed
      ? { status: 'error', errorMessage: 'Unavailable', logLines: [] }
      : { status: 'success', value: value({ queryId: 0, udfPath: request.path, args: [request.args] }), logLines: [] } })
  })
  await page.routeWebSocket(/wss:\/\/leaderboard-test\.convex\.cloud\//, socket => {
    const connection = { socket, queries: new Map<number, Query>(), version: { querySet: 0, ts: Buffer.alloc(8).toString('base64'), identity: 0 } }
    connections.push(connection)
    socket.onMessage(raw => {
      const message = JSON.parse(raw.toString())
      if (message.type !== 'ModifyQuerySet') return
      for (const modification of message.modifications) {
        if (modification.type === 'Add') connection.queries.set(modification.queryId, modification)
        else connection.queries.delete(modification.queryId)
      }
      update(connection, message.newVersion)
    })
    socket.onClose(() => connections.splice(connections.indexOf(connection), 1))
  })
  return {
    publish(next: Record<string, Score[]>) { boards = next; connections.forEach(connection => update(connection)) },
    fail(value: boolean) { failed = value; connections.forEach(connection => update(connection)) },
    subscriptions() { return connections.flatMap(connection => [...connection.queries.values()]) },
  }
}
