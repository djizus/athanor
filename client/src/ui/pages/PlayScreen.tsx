import { useNavigationStore } from '@/stores/navigationStore'

export function PlayScreen() {
  const { gameId, navigate } = useNavigationStore()

  return (
    <main style={{ padding: '2rem', maxWidth: 960, margin: '0 auto', display: 'grid', gap: '1rem' }}>
      <h1>Play</h1>
      <p>game_id: {gameId ?? 'N/A'}</p>
      <section>
        <h2>Heroes Panel</h2>
      </section>
      <section>
        <h2>Exploration Feed</h2>
      </section>
      <section>
        <h2>Craft Panel</h2>
      </section>
      <section>
        <h2>Grimoire</h2>
      </section>
      <section>
        <h2>Inventory</h2>
      </section>
      <button onClick={() => navigate('home')}>Back</button>
    </main>
  )
}
