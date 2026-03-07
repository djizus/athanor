import { Component, useEffect, useRef, useState } from 'react'
import type { ErrorInfo, ReactNode } from 'react'
import { useNavigationStore, type PageId } from '@/stores/navigationStore'
import { createPhaserGame, PhaserBridge } from '@/phaser'
import { LoadingScreen } from '@/ui/LoadingScreen'
import { Toaster } from '@/ui/components/Toaster'
import { HomePage } from '@/ui/pages/HomePage'
import { LeaderboardPage } from '@/ui/pages/LeaderboardPage'
import { MyGamesPage } from '@/ui/pages/MyGamesPage'
import { PlayScreen } from '@/ui/pages/PlayScreen'

class ErrorBoundary extends Component<
  { children: ReactNode },
  { error: Error | null }
> {
  constructor(props: { children: ReactNode }) {
    super(props)
    this.state = { error: null }
  }

  static getDerivedStateFromError(error: Error) {
    return { error }
  }

  componentDidCatch(error: Error, info: ErrorInfo) {
    console.error('[athanor:error-boundary] UI crashed:', error, info.componentStack)
  }

  render() {
    if (this.state.error) {
      return (
        <div style={{
          position: 'fixed', inset: 0, zIndex: 9999,
          display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center',
          background: '#080810', color: '#e0d0c0', fontFamily: 'monospace', padding: '2rem',
        }}>
          <h2 style={{ color: '#ff6b6b', marginBottom: '1rem' }}>Something went wrong</h2>
          <p style={{ marginBottom: '1rem', maxWidth: '600px', textAlign: 'center', opacity: 0.8 }}>
            {this.state.error.message}
          </p>
          <button
            onClick={() => window.location.reload()}
            style={{
              padding: '0.75rem 2rem', background: '#c8a96e', color: '#080810',
              border: 'none', borderRadius: '4px', cursor: 'pointer', fontSize: '1rem',
            }}
          >
            Reload
          </button>
        </div>
      )
    }
    return this.props.children
  }
}

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
    <ErrorBoundary>
      <div id="game-container" />
      {bridge ? (
        <div className="app">
          <PageRouter bridge={bridge} />
        </div>
      ) : (
        <LoadingScreen status="Loading game assets" />
      )}
      <Toaster />
    </ErrorBoundary>
  )
}
