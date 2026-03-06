import type { ReactNode } from 'react'
import { useNavigationStore, type PageId } from '@/stores/navigationStore'
import { HomePage } from '@/ui/pages/HomePage'
import { LeaderboardPage } from '@/ui/pages/LeaderboardPage'
import { MyGamesPage } from '@/ui/pages/MyGamesPage'
import { PlayScreen } from '@/ui/pages/PlayScreen'

const pageComponents: Record<PageId, ReactNode> = {
  home: <HomePage />,
  play: <PlayScreen />,
  mygames: <MyGamesPage />,
  leaderboard: <LeaderboardPage />,
}

export default function App() {
  const currentPage = useNavigationStore((state) => state.currentPage)

  return pageComponents[currentPage]
}
