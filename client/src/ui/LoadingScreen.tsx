export function LoadingScreen() {
  return (
    <div className="loading-screen">
      <div
        className="loading-bg"
        style={{ backgroundImage: `url('/assets/branding/loading-bg.png')` }}
      />
      <div className="loading-content">
        <img
          src="/assets/branding/logo.png"
          alt="Athanor"
          draggable={false}
          className="loading-logo"
        />
      </div>
    </div>
  )
}
