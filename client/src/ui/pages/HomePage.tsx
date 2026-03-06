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
    <main className="page-center">
      <h1 className="page-title">Athanor</h1>
      <p style={{ color: 'var(--text-secondary)' }}>Transmute, explore, survive.</p>

      {!address ? (
        <div className="panel">
          <button
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
      ) : (
        <div className="panel">
          <p style={{ margin: 0, wordBreak: 'break-all' }}>Player: {address}</p>
          <p style={{ margin: 0, color: 'var(--text-secondary)' }}>Total runs: {playerMeta?.total_games ?? 0}</p>
          <button className="btn-primary" onClick={handleCreateGame} disabled={isCreatingGame}>
            {isCreatingGame ? 'Creating Game...' : 'New Game'}
          </button>
          <div className="game-list">
            <button onClick={() => navigate('mygames')}>My Games</button>
            <button onClick={() => navigate('leaderboard')}>Leaderboard</button>
          </div>
          {error ? <p style={{ margin: 0, color: 'var(--accent-red)' }}>{error}</p> : null}
        </div>
      )}
    </main>
  )
}
