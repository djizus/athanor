import { useMemo } from 'react'
import { useAccount, useConnect } from '@starknet-react/core'
import { useNavigationStore } from '@/stores/navigationStore'

export function HomePage() {
  const { navigate } = useNavigationStore()
  const { address } = useAccount()
  const { connect, connectors } = useConnect()

  const connector = useMemo(() => connectors[0], [connectors])

  return (
    <main style={{ padding: '2rem', maxWidth: 720, margin: '0 auto' }}>
      <h1>Athanor</h1>

      {!address ? (
        <button disabled={!connector} onClick={() => connector && connect({ connector })}>
          Connect Wallet
        </button>
      ) : (
        <div style={{ display: 'grid', gap: '0.75rem' }}>
          <p>Player: {address}</p>
          <button onClick={() => navigate('play')}>New Game</button>
          <button onClick={() => navigate('mygames')}>My Games</button>
          <button onClick={() => navigate('leaderboard')}>Leaderboard</button>
        </div>
      )}
    </main>
  )
}
