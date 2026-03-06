import { useEffect, useRef, useState } from 'react'
import { useNavigationStore, type PageId } from '@/stores/navigationStore'
import { createPhaserGame, PhaserBridge } from '@/phaser'
import { LoadingScreen } from '@/ui/LoadingScreen'
import { Toaster } from '@/ui/components/Toaster'
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
  const [ready, setReady] = useState(false)

  useEffect(() => {
    console.info('[athanor:app] creating PhaserBridge + game')
    const bridge = new PhaserBridge()
    const game = createPhaserGame('game-container', bridge)
    bridgeRef.current = bridge
    gameRef.current = game

    const onBootComplete = () => {
      console.info('[athanor:app] bootComplete received — game engine ready')
      setReady(true)
    }
    bridge.on('bootComplete', onBootComplete)

    return () => {
      console.info('[athanor:app] cleanup — destroying game')
      bridge.off('bootComplete', onBootComplete)
      bridge.removeAllListeners()
      bridge.setGame(null)
      game.destroy(true)
      bridgeRef.current = null
      gameRef.current = null
      setReady(false)
    }
  }, [])

  const bridge = ready ? bridgeRef.current : null
  console.info('[athanor:render] App render — ready:', ready, 'bridge:', !!bridge)

  return (
    <>
      <div id="game-container" />
      {bridge ? (
        <div className="app">
          <PageRouter bridge={bridge} />
        </div>
      ) : (
        <LoadingScreen status="Loading game assets..." />
      )}
      <Toaster />
    </>
  )
}
