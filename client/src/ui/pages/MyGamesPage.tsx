import { useMemo, useState } from 'react'
import { useAccount, useConnect } from '@starknet-react/core'
import type ControllerConnector from '@cartridge/connector/controller'
import { useGameTokens } from '@/hooks/useGameTokens'
import { useLeaderboard } from '@/hooks/useLeaderboard'
import { usePlayerName } from '@/hooks/usePlayerName'
import { useNavigationStore } from '@/stores/navigationStore'
import { SettingsOverlay } from '@/ui/components/SettingsOverlay'

function formatElapsed(startedAt: number, endedAt: number): string {
  if (startedAt <= 0) return '-'
  const end = endedAt > 0 ? endedAt : Math.floor(Date.now() / 1000)
  const s = Math.max(0, end - startedAt)
  const h = Math.floor(s / 3600)
  const m = Math.floor((s % 3600) / 60)
  if (h > 0) return `${h}h ${m}m`
  return `${m}m`
}

export function MyGamesPage() {
  const { address } = useAccount()
  const { connectors } = useConnect()
  const { games } = useGameTokens(address)
  const { displayName } = usePlayerName(address)
  const { navigate } = useNavigationStore()
  const [settingsOpen, setSettingsOpen] = useState(false)
  const { rankByGameId } = useLeaderboard()

  const { active, finished } = useMemo(() => {
    const sorted = [...games].sort((a, b) => b.game_id - a.game_id)
    return {
      active: sorted.filter((g) => !g.game_over),
      finished: sorted.filter((g) => g.game_over),
    }
  }, [games])

  return (
    <div className="glass-page">
      <div className="glass-page-topbar">
        <button
          className="home-menu-player-chip"
          type="button"
          onClick={() => {
            const ctrl = connectors[0] as ControllerConnector | undefined
            if (ctrl?.controller) void ctrl.controller.openProfile()
          }}
        >
          <span className="home-menu-player-name">{displayName}</span>
        </button>
        <div className="glass-page-header-actions">
          <button className="home-menu-gear" onClick={() => setSettingsOpen(true)} aria-label="Settings">
            <span aria-hidden>&#x2699;</span>
          </button>
          <button onClick={() => navigate('home')}>Back</button>
        </div>
      </div>

      <div className="glass-page-panel">
        <div className="glass-page-header">
          <h1 className="glass-page-title">My Games</h1>
        </div>

        <div className="glass-page-body">
          {games.length === 0 ? (
            <p style={{ color: 'var(--text-secondary)' }}>No games yet</p>
          ) : (
            <>
              {active.length > 0 && (
                <>
                  <div className="games-section-label">Active</div>
                  <GamesTable games={active} rankByGameId={rankByGameId} onSelect={(id) => navigate('play', id)} rowClass="row-active" />
                </>
              )}
              {finished.length > 0 && (
                <>
                  <div className="games-section-label">Finished</div>
                  <GamesTable games={finished} rankByGameId={rankByGameId} onSelect={(id) => navigate('play', id)} rowClass="row-finished" />
                </>
              )}
            </>
          )}
        </div>
      </div>

      <SettingsOverlay open={settingsOpen} onClose={() => setSettingsOpen(false)} />
    </div>
  )
}

function GamesTable({
  games,
  rankByGameId,
  onSelect,
  rowClass,
}: {
  games: { game_id: number; started_at: number; ended_at: number; discovered_count: number; gold: number; hero_count: number }[]
  rankByGameId: Map<number, number>
  onSelect: (gameId: number) => void
  rowClass: string
}) {
  return (
    <div className="table-scroll">
      <table className="games-table">
        <thead>
          <tr>
            <th>Rank</th>
            <th>Time</th>
            <th>Recipes</th>
            <th>Game</th>
          </tr>
        </thead>
        <tbody>
          {games.map((g) => {
            const rank = rankByGameId.get(g.game_id)
            return (
              <tr key={g.game_id} className={rowClass} onClick={() => onSelect(g.game_id)}>
                <td>{rank != null ? `#${rank}` : '-'}</td>
                <td>{formatElapsed(g.started_at, g.ended_at)}</td>
                <td>{g.discovered_count}/30</td>
                <td>#{g.game_id}</td>
              </tr>
            )
          })}
        </tbody>
      </table>
    </div>
  )
}
