import { useState } from 'react'
import { useAccount, useConnect } from '@starknet-react/core'
import { RpcProvider } from 'starknet'
import { usePlayerMeta } from '@/hooks/usePlayerMeta'
import { useDojo } from '@/dojo/useDojo'
import { extractGameId } from '@/dojo/systems'
import { useNavigationStore } from '@/stores/navigationStore'

export function HomePage() {
  const { client, config } = useDojo()
  const { navigate } = useNavigationStore()
  const { address, account } = useAccount()
  const { connect, connectors } = useConnect()
  const playerMeta = usePlayerMeta(address)
  const [isCreatingGame, setIsCreatingGame] = useState(false)
  const [error, setError] = useState<string | null>(null)

  const primaryConnector = connectors[0]

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

  return (
    <main className="home-menu">
      <section className="home-menu-shell panel">
        <img
          src="/assets/branding/logo-loading-gold-shadow.png"
          alt="Athanor"
          draggable={false}
          className="home-menu-logo"
        />
        <p className="home-menu-tagline">Transmute, explore, survive.</p>

        {!address ? (
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
        ) : (
          <>
            <div className="home-menu-meta">
              <p className="home-menu-address" title={address}>Player: {address}</p>
              <p className="home-menu-runs">Total runs: {playerMeta?.total_games ?? 0}</p>
            </div>

            <div className="home-menu-actions">
              <button
                className="home-menu-button home-menu-button-primary"
                onClick={handleCreateGame}
                disabled={isCreatingGame}
              >
                {isCreatingGame ? 'Forging Run...' : 'New Game'}
              </button>
              <button className="home-menu-button" onClick={() => navigate('mygames')}>
                My Games
              </button>
              <button className="home-menu-button" onClick={() => navigate('leaderboard')}>
                Leaderboard
              </button>
            </div>

            {error ? <p className="home-menu-error">{error}</p> : null}
          </>
        )}
      </section>
    </main>
  )
}
