import { displayGold } from '@/game/constants'

interface Props {
  gold: number
  discoveredCount: number
  elapsedSeconds: number
  goldFloats?: { id: string; text: string }[]
  onBack: () => void
  onSettings: () => void
}

function formatTime(totalSeconds: number): string {
  const m = Math.floor(totalSeconds / 60)
  const s = totalSeconds % 60
  return `${String(m).padStart(2, '0')}:${String(s).padStart(2, '0')}`
}

export function StatusHUD({ gold, discoveredCount, elapsedSeconds, goldFloats, onBack, onSettings }: Props) {
  const pct = Math.min(100, (discoveredCount / 30) * 100)

  return (
    <div className="status-hud floating-panel">
      <button className="status-hud-btn status-hud-back" onClick={onBack}>
        ← Back
      </button>
      <span className="status-hud-divider" />
      <span className="status-hud-time">Time {formatTime(elapsedSeconds)}</span>
      <span className="status-hud-sep">·</span>
      <span className="status-hud-gold">
        Gold {displayGold(gold)}
        {goldFloats?.map(f => (
          <span key={f.id} className="gold-float-anim">{f.text}</span>
        ))}
      </span>
      <span className="status-hud-sep">·</span>
      <div className="status-hud-progress">
        <div className="status-hud-progress-fill" style={{ width: `${pct}%` }} />
        <span className="status-hud-progress-label">{discoveredCount}/30</span>
      </div>
      <span className="status-hud-divider" />
      <button className="status-hud-btn status-hud-settings" onClick={onSettings}>
        ⚙
      </button>
    </div>
  )
}
