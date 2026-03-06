import { useEffect, useMemo, useState } from 'react'
import { useAccount, useConnect } from '@starknet-react/core'
import { RpcProvider } from 'starknet'
import { usePlayerMeta } from '@/hooks/usePlayerMeta'
import { usePlayerName } from '@/hooks/usePlayerName'
import { usePlayerRank } from '@/hooks/usePlayerRank'
import { useGameTokens } from '@/hooks/useGameTokens'
import { useDojo } from '@/dojo/useDojo'
import { extractGameId } from '@/dojo/systems'
import { useNavigationStore } from '@/stores/navigationStore'
import { SettingsOverlay } from '@/ui/components/SettingsOverlay'

function formatBestTime(bestTimeBigInt: bigint | undefined): string {
  if (!bestTimeBigInt || bestTimeBigInt <= 0n) return 'NA'
  const totalSeconds = Number(bestTimeBigInt)
  const minutes = Math.floor(totalSeconds / 60)
  const seconds = totalSeconds % 60
  return `${minutes}m ${seconds}s`
}

export function HomePage() {
  const { client, config } = useDojo()
  const { navigate } = useNavigationStore()
  const { address, account } = useAccount()
  const { connect, connectors } = useConnect()
  const playerMeta = usePlayerMeta(address)
  const games = useGameTokens(address)
  const { displayName, isUsername } = usePlayerName(address)
  const rank = usePlayerRank(address)
  const [isCreatingGame, setIsCreatingGame] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const [settingsOpen, setSettingsOpen] = useState(false)

  const primaryConnector = connectors[0]

  const activeGame = useMemo(
    () => games.find((g) => !g.game_over) ?? null,
    [games],
  )

  useEffect(() => {
    if (activeGame) {
      console.info('[HomePage] active game detected, resuming game #', activeGame.game_id)
      navigate('play', activeGame.game_id)
    }
  }, [activeGame, navigate])

  const handleCreateGame = async () => {
    if (!account) return

    setError(null)
    setIsCreatingGame(true)

    try {
      const provider = new RpcProvider({ nodeUrl: config.rpcUrl })
      const mintResult = await client.mintGame(account)
      const mintReceipt = await provider.waitForTransaction(mintResult.transaction_hash)
      const gameId = extractGameId(mintReceipt as { events?: { keys?: string[]; data?: string[] }[] })

      if (gameId <= 0) {
        throw new Error('Failed to extract game id from mint transaction receipt')
      }

      await client.create(account, gameId)
      navigate('play', gameId)
    } catch (creationError) {
      const message = creationError instanceof Error ? creationError.message : 'Game creation failed'
      setError(message)
    } finally {
      setIsCreatingGame(false)
    }
  }

  const truncatedAddress = address
    ? `${address.slice(0, 6)}...${address.slice(-4)}`
    : ''

  const bestTime = formatBestTime(playerMeta?.best_time as bigint | undefined)
  const totalGames = playerMeta?.total_games ?? 0

  return (
    <main className="home-menu">
      <section className="home-menu-shell panel">
        {!address ? (
          <>
            <img
              src="/assets/branding/logo-loading-gold-shadow.png"
              alt="Athanor"
              draggable={false}
              className="home-menu-logo"
            />
            <p className="home-menu-tagline">Transmute, explore, survive.</p>
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
          </>
        ) : (
          <>
            <div className="home-menu-topbar">
              <div className="home-menu-player-chip">
                <span className="home-menu-player-name">{displayName}</span>
                {isUsername && (
                  <span className="home-menu-player-address">{truncatedAddress}</span>
                )}
              </div>
              <button
                className="home-menu-gear"
                onClick={() => setSettingsOpen(true)}
                aria-label="Settings"
              >
                ⚙
              </button>
            </div>

            <img
              src="/assets/branding/logo-loading-gold-shadow.png"
              alt="Athanor"
              draggable={false}
              className="home-menu-logo"
            />
            <p className="home-menu-tagline">Transmute, explore, survive.</p>

            <div className="home-menu-stats">
              <span>🏆 Rank #{rank ?? '—'}</span>
              <span className="home-menu-stats-sep">·</span>
              <span>⏱ Best: {bestTime}</span>
              <span className="home-menu-stats-sep">·</span>
              <span>🎮 Runs: {totalGames}</span>
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

            <SettingsOverlay
              open={settingsOpen}
              onClose={() => setSettingsOpen(false)}
              address={address}
            />

            {error ? <p className="home-menu-error">{error}</p> : null}
          </>
        )}
      </section>
    </main>
  )
}
