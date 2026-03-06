import { useEffect, useRef } from 'react'
import { useNavigationStore, type PageId } from '@/stores/navigationStore'
import { createPhaserGame, PhaserBridge } from '@/phaser'
import { HomePage } from '@/ui/pages/HomePage'
import { LeaderboardPage } from '@/ui/pages/LeaderboardPage'
import { MyGamesPage } from '@/ui/pages/MyGamesPage'
import { PlayScreen } from '@/ui/pages/PlayScreen'

function PageRouter({ bridge }: { bridge: PhaserBridge }) {
  const currentPage = useNavigationStore((state) => state.currentPage)

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

  useEffect(() => {
    const bridge = new PhaserBridge()
    const game = createPhaserGame('game-container', bridge)
    bridgeRef.current = bridge
    gameRef.current = game

    return () => {
      bridge.removeAllListeners()
      bridge.setGame(null)
      game.destroy(true)
      bridgeRef.current = null
      gameRef.current = null
    }
  }, [])

  const bridge = bridgeRef.current

  return (
    <>
      <div id="game-container" />
      <div className="app">
        {bridge && <PageRouter bridge={bridge} />}
      </div>
    </>
  )
}
