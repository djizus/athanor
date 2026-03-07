import { useMemo } from 'react'
import { Has, getComponentValue } from '@dojoengine/recs'
import { useEntityQuery } from '@dojoengine/react'
import { useDojo } from '@/dojo/useDojo'
import { useNavigationStore } from '@/stores/navigationStore'
import { bitmapPopcount } from '@/game/packer'

type LeaderboardRow = {
  gameId: number
  discoveredCount: number
  startedAt: number
  duration: number
}

function formatDuration(seconds: number): string {
  if (seconds <= 0) return '-'
  const m = Math.floor(seconds / 60)
  const s = seconds % 60
  return `${m}m ${s}s`
}

export function LeaderboardPage() {
  const { contractComponents } = useDojo()
  const gameEntities = useEntityQuery([Has(contractComponents.Game)])
  const { navigate } = useNavigationStore()

  const rows = useMemo(() => {
    const leaderboardRows: LeaderboardRow[] = []

    for (const entity of gameEntities) {
      const game = getComponentValue(contractComponents.Game, entity)
      if (!game) continue
      if (game.ended_at <= 0) continue

      leaderboardRows.push({
        gameId: game.id,
        discoveredCount: bitmapPopcount(game.grimoire),
        startedAt: game.started_at,
        duration: game.ended_at - game.started_at,
      })
    }

    return leaderboardRows.sort((a, b) => {
      if (b.discoveredCount !== a.discoveredCount) {
        return b.discoveredCount - a.discoveredCount
      }
      return a.duration - b.duration
    })
  }, [contractComponents.Game, gameEntities])

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
                    <th>Game</th>
                    <th>Recipes</th>
                    <th>Time</th>
                  </tr>
                </thead>
                <tbody>
                  {rows.map((row, index) => (
                    <tr key={row.gameId}>
                      <td>{index + 1}</td>
                      <td>#{row.gameId}</td>
                      <td>{row.discoveredCount}/30</td>
                      <td>{formatDuration(row.duration)}</td>
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
