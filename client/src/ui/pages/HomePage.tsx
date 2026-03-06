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
    <main style={{ padding: '2rem', maxWidth: 760, margin: '0 auto' }}>
      <h1 style={{ margin: 0 }}>Athanor</h1>
      <p style={{ color: 'rgba(255,255,255,0.72)', marginTop: '0.5rem' }}>Transmute, explore, survive.</p>

      {!address ? (
        <div
          style={{
            marginTop: '1.25rem',
            padding: '1rem',
            border: '1px solid #2f2f2f',
            borderRadius: 12,
            background: '#1d1d1d',
          }}
        >
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
        <div
          style={{
            display: 'grid',
            gap: '0.75rem',
            marginTop: '1.25rem',
            padding: '1rem',
            border: '1px solid #2f2f2f',
            borderRadius: 12,
            background: '#1d1d1d',
          }}
        >
          <p style={{ margin: 0, wordBreak: 'break-all' }}>Player: {address}</p>
          <p style={{ margin: 0, color: 'rgba(255,255,255,0.72)' }}>Total runs: {playerMeta?.total_games ?? 0}</p>
          <button onClick={handleCreateGame} disabled={isCreatingGame}>
            {isCreatingGame ? 'Creating Game...' : 'New Game'}
          </button>
          <button onClick={() => navigate('mygames')}>My Games</button>
          <button onClick={() => navigate('leaderboard')}>Leaderboard</button>
          {error ? <p style={{ margin: 0, color: '#f44336' }}>{error}</p> : null}
        </div>
      )}
    </main>
  )
}
