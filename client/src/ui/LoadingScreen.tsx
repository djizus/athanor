type LoadingScreenProps = {
  status?: string
  error?: string | null
}

export function LoadingScreen({ status, error }: LoadingScreenProps) {
  return (
    <div className="loading-screen">
      <div
        className="loading-bg"
        style={{ backgroundImage: `url('/assets/branding/loading-bg.png')` }}
      />
      <div className="loading-content">
        <img
          src="/assets/branding/logo-loading-black.png"
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
