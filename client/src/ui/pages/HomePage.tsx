import { useEffect, useMemo, useState } from 'react'
import { useAccount, useConnect } from '@starknet-react/core'
import type ControllerConnector from '@cartridge/connector/controller'
import { RpcProvider } from 'starknet'
import { usePlayerName } from '@/hooks/usePlayerName'
import { usePlayerRank } from '@/hooks/usePlayerRank'
import { useGameTokens } from '@/hooks/useGameTokens'
import { useDojo } from '@/dojo/useDojo'
import { extractGameId } from '@/dojo/systems'
import { useNavigationStore } from '@/stores/navigationStore'
import { txToast } from '@/stores/toastStore'
import { SettingsOverlay } from '@/ui/components/SettingsOverlay'

export function HomePage() {
  const { client, config } = useDojo()
  const { navigate } = useNavigationStore()
  const { address, account } = useAccount()
  const { connect, connectors } = useConnect()
  const { games } = useGameTokens(address)
  const { displayName } = usePlayerName(address)
  const rank = usePlayerRank(address)
  const [isCreatingGame, setIsCreatingGame] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const [settingsOpen, setSettingsOpen] = useState(false)

  const primaryConnector = connectors[0]

  const activeGame = useMemo(
    () => games.find((g) => !g.game_over) ?? null,
    [games],
  )

  // TODO: re-enable auto-nav to ongoing game
  // useEffect(() => {
  //   if (activeGame) {
  //     console.info('[HomePage] active game detected, resuming game #', activeGame.game_id)
  //     navigate('play', activeGame.game_id)
  //   }
  // }, [activeGame, navigate])

  const handleCreateGame = async () => {
    if (!account) return

    setError(null)
    setIsCreatingGame(true)

    const t = txToast('Creating game')
    try {
      const provider = new RpcProvider({ nodeUrl: config.rpcUrl })
      const mintResult = await client.mintGame(account)
      const mintReceipt = await provider.waitForTransaction(mintResult.transaction_hash)
      const gameId = extractGameId(mintReceipt as { events?: { keys?: string[]; data?: string[] }[] })

      if (gameId <= 0) {
        throw new Error('Failed to extract game id from mint transaction receipt')
      }

      await client.create(account, gameId)
      t.success('Game created')
      navigate('play', gameId)
    } catch (creationError) {
      const message = creationError instanceof Error ? creationError.message : 'Game creation failed'
      t.error(message)
      setError(message)
    } finally {
      setIsCreatingGame(false)
    }
  }

  const bestTime = 'NA'
  const totalGames = games.length
  const particles = Array.from({ length: 12 }, (_, idx) => idx)

  function getRankIcon(r: number | null): string {
    if (r === null) return '🔮'
    if (r === 1) return '👑'
    if (r === 2) return '🥈'
    if (r === 3) return '🥉'
    if (r <= 10) return '⚔️'
    return '🔮'
  }
  const rankIcon = getRankIcon(rank)

  if (!address) {
    return (
      <div className="glass-page home-menu-page">
        <section className="home-menu-shell">
          <div className="ambient-particles" aria-hidden>
            {particles.map((idx) => (
              <span key={`menu-disconnected-particle-${idx}`} className="ambient-particle" />
            ))}
          </div>
          <div className="home-menu-center">
            <img
              src="/assets/branding/logo-loading-gold-shadow.png"
              alt="Athanor"
              draggable={false}
              className="home-menu-logo"
            />
            <div className="home-menu-actions">
              <button
                className="home-menu-button home-menu-button-primary"
                disabled={!primaryConnector}
                onClick={() => {
                  if (primaryConnector) {
                    connect({ connector: primaryConnector })
                  }
                }}
              >
                Connect Wallet
              </button>
            </div>
          </div>
        </section>
      </div>
    )
  }

  return (
    <div className="glass-page home-menu-page">
      <section className="home-menu-shell">
        <div className="ambient-particles" aria-hidden>
          {particles.map((idx) => (
            <span key={`menu-connected-particle-${idx}`} className="ambient-particle" />
          ))}
        </div>
        <div className="home-menu-topbar">
          <button
            className="home-menu-player-chip"
            type="button"
            onClick={() => {
              const ctrl = connectors[0] as ControllerConnector | undefined
              if (ctrl?.controller) void ctrl.controller.openProfile()
            }}
          >
            <span className="home-menu-player-name">👤 {displayName}</span>
          </button>
          <button
            className="home-menu-gear"
            onClick={() => setSettingsOpen(true)}
            aria-label="Settings"
          >
            <span aria-hidden>⚙</span>
            <span>Settings</span>
          </button>
        </div>

        <div className="home-menu-center">
          <img
            src="/assets/branding/logo-loading-gold-shadow.png"
            alt="Athanor"
            draggable={false}
            className="home-menu-logo"
          />
          <div className="home-menu-rank-panel">
            <span className="home-menu-rank-icon">{rankIcon}</span>
            <span className="home-menu-rank-text">Rank #{rank ?? '—'} · Best: {bestTime} · Runs: {totalGames}</span>
          </div>
          <div className="home-menu-actions">
            {activeGame ? (
              <button
                className="home-menu-button home-menu-button-primary"
                onClick={() => navigate('play', activeGame.game_id)}
              >
                Continue Game #{activeGame.game_id}
              </button>
            ) : (
              <button
                className="home-menu-button home-menu-button-primary"
                onClick={handleCreateGame}
                disabled={isCreatingGame}
              >
                {isCreatingGame ? 'Forging Run...' : 'New Game'}
              </button>
            )}
            <button className="home-menu-button" onClick={() => navigate('mygames')}>
              My Games{games.length > 0 ? ` (${games.length})` : ''}
            </button>
            <button className="home-menu-button" onClick={() => navigate('leaderboard')}>
              Leaderboard
            </button>
          </div>

          {error ? <p className="home-menu-error">{error}</p> : null}
        </div>

        <SettingsOverlay
          open={settingsOpen}
          onClose={() => setSettingsOpen(false)}
        />
      </section>
    </div>
  )
}
