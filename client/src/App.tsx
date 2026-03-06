import { useEffect, useRef, useState } from 'react'
import { useNavigationStore, type PageId } from '@/stores/navigationStore'
import { createPhaserGame, PhaserBridge } from '@/phaser'
import { HomePage } from '@/ui/pages/HomePage'
import { LeaderboardPage } from '@/ui/pages/LeaderboardPage'
import { MyGamesPage } from '@/ui/pages/MyGamesPage'
import { PlayScreen } from '@/ui/pages/PlayScreen'

function PageRouter({ bridge }: { bridge: PhaserBridge }) {
  const currentPage = useNavigationStore((state) => state.currentPage)
  console.info('[athanor:render] PageRouter — page:', currentPage)

  const pages: Record<PageId, React.ReactNode> = {
    home: <HomePage />,
    play: <PlayScreen bridge={bridge} />,
    mygames: <MyGamesPage />,
    leaderboard: <LeaderboardPage />,
  }

  return <>{pages[currentPage]}</>
}

export default function App() {
  const bridgeRef = useRef<PhaserBridge | null>(null)
  const gameRef = useRef<Phaser.Game | null>(null)
  const [bridgeReady, setBridgeReady] = useState(false)

  useEffect(() => {
    console.info('[athanor:app] creating PhaserBridge + game')
    const bridge = new PhaserBridge()
    const game = createPhaserGame('game-container', bridge)
    bridgeRef.current = bridge
    gameRef.current = game
    setBridgeReady(true)
    console.info('[athanor:app] bridge ready, game created')

    return () => {
      console.info('[athanor:app] cleanup — destroying game')
      bridge.removeAllListeners()
      bridge.setGame(null)
      game.destroy(true)
      bridgeRef.current = null
      gameRef.current = null
      setBridgeReady(false)
    }
  }, [])

  const bridge = bridgeReady ? bridgeRef.current : null
  console.info('[athanor:render] App render — bridgeReady:', bridgeReady, 'bridge:', !!bridge)

  return (
    <>
      <div id="game-container" />
      <div className="app">
        {bridge ? <PageRouter bridge={bridge} /> : <p style={{ color: '#888', textAlign: 'center', marginTop: '2rem' }}>Waiting for game engine...</p>}
      </div>
    </>
  )
}
