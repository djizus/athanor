import { useMemo } from 'react'
import { Has, getComponentValue } from '@dojoengine/recs'
import { useEntityQuery } from '@dojoengine/react'
import { useDojo } from '@/dojo/useDojo'
import { useNavigationStore } from '@/stores/navigationStore'
import { bitmapPopcount } from '@/game/packer'

type LeaderboardRow = {
  gameId: number
  player: bigint
  discoveredCount: number
  startedAt: number
}

function truncateAddress(value: bigint): string {
  const hex = `0x${value.toString(16)}`
  if (hex.length <= 12) return hex
  return `${hex.slice(0, 6)}...${hex.slice(-4)}`
}

function formatStartedAt(unixSeconds: number): string {
  if (unixSeconds <= 0) return '-'
  return new Date(unixSeconds * 1000).toLocaleString()
}

export function LeaderboardPage() {
  const { contractComponents } = useDojo()
  const sessionEntities = useEntityQuery([Has(contractComponents.GameSession)])
  const gameEntities = useEntityQuery([Has(contractComponents.Game)])
  const { navigate } = useNavigationStore()

  const rows = useMemo(() => {
    const leaderboardRows: LeaderboardRow[] = []

    for (const entity of sessionEntities) {
      const session = getComponentValue(contractComponents.GameSession, entity)
      if (!session) continue

      const gameId = Number(session.game_id)
      const game = gameEntities
        .map((e) => getComponentValue(contractComponents.Game, e))
        .find((g) => g && Number(g.id) === gameId)

      const isOver = game ? Number(game.ended_at) > 0 : session.game_over
      if (!isOver) continue

      leaderboardRows.push({
        gameId,
        player: BigInt(session.player),
        discoveredCount: game ? bitmapPopcount(game.grimoire) : session.discovered_count,
        startedAt: game ? Number(game.started_at) : Number(session.started_at),
      })
    }

    return leaderboardRows.sort((a, b) => {
      if (b.discoveredCount !== a.discoveredCount) {
        return b.discoveredCount - a.discoveredCount
      }
      return a.startedAt - b.startedAt
    })
  }, [contractComponents.GameSession, contractComponents.Game, sessionEntities, gameEntities])

  return (
    <div className="glass-page">
      <div className="glass-page-panel">
        <div className="glass-page-header">
          <h1 className="glass-page-title">Leaderboard</h1>
          <button onClick={() => navigate('home')}>Back</button>
        </div>

        <div className="glass-page-body">
          {rows.length === 0 ? (
            <p style={{ color: 'var(--text-secondary)' }}>No completed games yet.</p>
          ) : (
            <div className="table-scroll">
              <table className="leaderboard-table">
                <thead>
                  <tr>
                    <th>Rank</th>
                    <th>Player</th>
                    <th>Game</th>
                    <th>Recipes Discovered</th>
                    <th>Started At</th>
                  </tr>
                </thead>
                <tbody>
                  {rows.map((row, index) => (
                    <tr key={row.gameId}>
                      <td>{index + 1}</td>
                      <td>{truncateAddress(row.player)}</td>
                      <td>#{row.gameId}</td>
                      <td>{row.discoveredCount}/30</td>
                      <td>{formatStartedAt(row.startedAt)}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}
        </div>
      </div>
    </div>
  )
}
