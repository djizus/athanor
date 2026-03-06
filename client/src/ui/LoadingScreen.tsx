type LoadingScreenProps = {
  status?: string
  error?: string | null
}

export function LoadingScreen({ status, error }: LoadingScreenProps) {
  const particles = Array.from({ length: 12 }, (_, idx) => idx)

  return (
    <div className="loading-screen">
      <div
        className="loading-bg"
        style={{ backgroundImage: `url('/assets/branding/loading-bg.png')` }}
      />
      <div className="ambient-particles" aria-hidden>
        {particles.map((idx) => (
          <span key={`loading-particle-${idx}`} className="ambient-particle" />
        ))}
      </div>
      <div className="loading-content">
        <img
          src="/assets/branding/logo-loading-gold-shadow.png"
          alt="Athanor"
          draggable={false}
          className="loading-logo"
        />
        <p className="loading-status">{status ?? 'Initializing client...'}</p>
        {error ? <p className="loading-error">{error}</p> : null}
      </div>
    </div>
  )
}
