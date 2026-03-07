import { Component, useEffect } from 'react'
import type { ErrorInfo, ReactNode } from 'react'
import { useNavigationStore, type PageId } from '@/stores/navigationStore'
import { soundManager } from '@/sound/SoundManager'
import { Toaster } from '@/ui/components/Toaster'
import { HomePage } from '@/ui/pages/HomePage'
import { HowToPlayPage } from '@/ui/pages/HowToPlayPage'
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

function PageRouter() {
  const currentPage = useNavigationStore((state) => state.currentPage)

  const pages: Record<PageId, React.ReactNode> = {
    home: <HomePage />,
    play: <PlayScreen />,
    mygames: <MyGamesPage />,
    leaderboard: <LeaderboardPage />,
    howtoplay: <HowToPlayPage />,
  }

  return <>{pages[currentPage]}</>
}

export default function App() {
  useEffect(() => {
    soundManager.init()
    soundManager.startMusic()
    soundManager.startAmbient()
    return () => {
      soundManager.destroy()
    }
  }, [])

  return (
    <ErrorBoundary>
      <div className="app">
        <PageRouter />
      </div>
      <Toaster />
    </ErrorBoundary>
  )
}
