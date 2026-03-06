import { useNavigationStore } from '@/stores/navigationStore'

export function MyGamesPage() {
  const { navigate } = useNavigationStore()

  return (
    <main style={{ padding: '2rem', maxWidth: 720, margin: '0 auto' }}>
      <h1>My Games</h1>
      <p>TODO: list owned game NFTs.</p>
      <button onClick={() => navigate('home')}>Back</button>
    </main>
  )
}
