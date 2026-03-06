import { useNavigationStore } from '@/stores/navigationStore'

export function LeaderboardPage() {
  const { navigate } = useNavigationStore()

  return (
    <main style={{ padding: '2rem', maxWidth: 720, margin: '0 auto' }}>
      <h1>Leaderboard</h1>
      <p>TODO: query completed games sorted by completion_time.</p>
      <button onClick={() => navigate('home')}>Back</button>
    </main>
  )
}
