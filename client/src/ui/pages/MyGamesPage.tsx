import { useMemo } from 'react'
import { useAccount } from '@starknet-react/core'
import { useGameTokens } from '@/hooks/useGameTokens'
import { useNavigationStore } from '@/stores/navigationStore'

export function MyGamesPage() {
  const { address } = useAccount()
  const games = useGameTokens(address)
  const { navigate } = useNavigationStore()

  const sortedGames = useMemo(
    () => [...games].sort((a, b) => b.started_at - a.started_at),
    [games],
  )

  return (
    <main style={{ padding: '2rem', maxWidth: 860, margin: '0 auto', display: 'grid', gap: '1rem' }}>
      <section style={{ background: '#1d1d1d', border: '1px solid #2f2f2f', borderRadius: 12, padding: '1rem' }}>
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', gap: '0.75rem' }}>
          <h1 style={{ margin: 0 }}>My Games</h1>
          <button onClick={() => navigate('home')}>Back</button>
        </div>
      </section>

      {sortedGames.length === 0 ? (
        <section style={{ background: '#1d1d1d', border: '1px solid #2f2f2f', borderRadius: 12, padding: '1rem' }}>
          <p style={{ margin: 0, color: 'rgba(255,255,255,0.72)' }}>No games yet</p>
        </section>
      ) : (
        <section style={{ display: 'grid', gap: '0.75rem' }}>
          {sortedGames.map((game) => (
            <button
              key={game.game_id}
              onClick={() => navigate('play', game.game_id)}
              style={{
                textAlign: 'left',
                background: '#1d1d1d',
                border: '1px solid #2f2f2f',
                borderRadius: 12,
                padding: '1rem',
              }}
            >
              <div style={{ display: 'grid', gap: '0.3rem' }}>
                <strong>Game #{game.game_id}</strong>
                <span style={{ color: 'rgba(255,255,255,0.84)' }}>{game.discovered_count}/10 recipes discovered</span>
                <span style={{ color: game.game_over ? '#7ed67e' : 'rgba(255,255,255,0.72)' }}>
                  {game.game_over ? 'Completed' : 'In Progress'}
                </span>
              </div>
            </button>
          ))}
        </section>
      )}
    </main>
  )
}
