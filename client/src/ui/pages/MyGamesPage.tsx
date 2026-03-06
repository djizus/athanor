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
    <div className="page">
      <section className="status-bar">
        <h1 className="status-bar-title">My Games</h1>
        <div className="status-bar-actions">
          <button onClick={() => navigate('home')}>Back</button>
        </div>
      </section>

      {sortedGames.length === 0 ? (
        <section className="page-scroll">
          <div className="panel">
            <p>No games yet</p>
          </div>
        </section>
      ) : (
        <section className="page-scroll">
          <div className="game-list">
            {sortedGames.map((game) => (
              <button
                key={game.game_id}
                className="game-card"
                onClick={() => navigate('play', game.game_id)}
              >
                <div className="game-card-info">
                  <strong>Game #{game.game_id}</strong>
                  <span style={{ color: 'var(--text-secondary)' }}>{game.discovered_count}/10 recipes discovered</span>
                  <span style={{ color: game.game_over ? 'var(--accent-green)' : 'var(--text-secondary)' }}>
                    {game.game_over ? 'Completed' : 'In Progress'}
                  </span>
                </div>
              </button>
            ))}
          </div>
        </section>
      )}
    </div>
  )
}
