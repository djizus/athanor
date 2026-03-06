import { displayGold } from '@/game/constants'

interface Props {
  gold: number
  discoveredCount: number
  elapsedSeconds: number
}

function formatTime(totalSeconds: number): string {
  const m = Math.floor(totalSeconds / 60)
  const s = totalSeconds % 60
  return `${String(m).padStart(2, '0')}:${String(s).padStart(2, '0')}`
}

export function StatusHUD({ gold, discoveredCount, elapsedSeconds }: Props) {
  return (
    <div className="status-hud floating-panel">
      <span className="status-hud-gold">Gold {displayGold(gold)}</span>
      <span className="status-hud-sep">-</span>
      <span className="status-hud-recipes">Potions {discoveredCount}/10</span>
      <span className="status-hud-sep">-</span>
      <span className="status-hud-time">Time {formatTime(elapsedSeconds)}</span>
    </div>
  )
}
