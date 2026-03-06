import { useMemo } from 'react'
import { Has, getComponentValue } from '@dojoengine/recs'
import { useEntityQuery } from '@dojoengine/react'
import { useDojo } from '@/dojo/useDojo'
import { useNavigationStore } from '@/stores/navigationStore'

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
  const entities = useEntityQuery([Has(contractComponents.GameSession)])
  const { navigate } = useNavigationStore()

  const rows = useMemo(() => {
    const leaderboardRows: LeaderboardRow[] = []

    for (const entity of entities) {
      const session = getComponentValue(contractComponents.GameSession, entity)
      if (!session || !session.game_over) continue

      leaderboardRows.push({
        gameId: Number(session.game_id),
        player: BigInt(session.player),
        discoveredCount: session.discovered_count,
        startedAt: Number(session.started_at),
      })
    }

    return leaderboardRows.sort((a, b) => {
      if (b.discoveredCount !== a.discoveredCount) {
        return b.discoveredCount - a.discoveredCount
      }
      return a.startedAt - b.startedAt
    })
  }, [contractComponents.GameSession, entities])

  return (
    <main style={{ padding: '2rem', maxWidth: 980, margin: '0 auto', display: 'grid', gap: '1rem' }}>
      <section style={{ background: '#1d1d1d', border: '1px solid #2f2f2f', borderRadius: 12, padding: '1rem' }}>
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', gap: '0.75rem' }}>
          <h1 style={{ margin: 0 }}>Leaderboard</h1>
          <button onClick={() => navigate('home')}>Back</button>
        </div>
      </section>

      <section style={{ background: '#1d1d1d', border: '1px solid #2f2f2f', borderRadius: 12, padding: '1rem' }}>
        {rows.length === 0 ? (
          <p style={{ margin: 0, color: 'rgba(255,255,255,0.72)' }}>No completed games yet.</p>
        ) : (
          <div style={{ overflowX: 'auto' }}>
            <table style={{ width: '100%', borderCollapse: 'collapse' }}>
              <thead>
                <tr style={{ textAlign: 'left', borderBottom: '1px solid #333' }}>
                  <th style={{ padding: '0.5rem' }}>Rank</th>
                  <th style={{ padding: '0.5rem' }}>Player</th>
                  <th style={{ padding: '0.5rem' }}>Game</th>
                  <th style={{ padding: '0.5rem' }}>Recipes Discovered</th>
                  <th style={{ padding: '0.5rem' }}>Time</th>
                  <th style={{ padding: '0.5rem' }}>Started At</th>
                </tr>
              </thead>
              <tbody>
                {rows.map((row, index) => (
                  <tr key={row.gameId} style={{ borderBottom: '1px solid #2a2a2a' }}>
                    <td style={{ padding: '0.5rem' }}>{index + 1}</td>
                    <td style={{ padding: '0.5rem' }}>{truncateAddress(row.player)}</td>
                    <td style={{ padding: '0.5rem' }}>#{row.gameId}</td>
                    <td style={{ padding: '0.5rem' }}>{row.discoveredCount}/10</td>
                    <td style={{ padding: '0.5rem', color: 'rgba(255,255,255,0.7)' }}>N/A</td>
                    <td style={{ padding: '0.5rem' }}>{formatStartedAt(row.startedAt)}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </section>
    </main>
  )
}
