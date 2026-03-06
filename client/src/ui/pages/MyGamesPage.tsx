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
    <div className="glass-page">
      <div className="glass-page-panel">
        <div className="glass-page-header">
          <h1 className="glass-page-title">My Games</h1>
          <button onClick={() => navigate('home')}>Back</button>
        </div>

        <div className="glass-page-body">
          {sortedGames.length === 0 ? (
            <p style={{ color: 'var(--text-secondary)' }}>No games yet</p>
          ) : (
            <div className="game-list">
              {sortedGames.map((game) => (
                <button
                  key={game.game_id}
                  className="game-card"
                  onClick={() => navigate('play', game.game_id)}
                >
                  <div className="game-card-info">
                    <strong>Game #{game.game_id}</strong>
                    <span style={{ color: 'var(--text-secondary)' }}>
                      {game.discovered_count}/10 recipes discovered
                    </span>
                    <span style={{ color: game.game_over ? 'var(--accent-green)' : 'var(--text-secondary)' }}>
                      {game.game_over ? 'Completed' : 'In Progress'}
                    </span>
                  </div>
                </button>
              ))}
            </div>
          )}
        </div>
      </div>
    </div>
  )
}
