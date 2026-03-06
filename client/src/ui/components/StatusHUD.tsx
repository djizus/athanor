import { displayGold } from '@/game/constants'

interface Props {
  gold: number
  discoveredCount: number
  seedLabel: string
  isGameOver: boolean
  onSurrender: () => void
  onBack: () => void
}

export function StatusHUD({ gold, discoveredCount, seedLabel, isGameOver, onSurrender, onBack }: Props) {
  return (
    <div className="status-hud floating-panel">
      <span className="status-hud-gold">Gold: {displayGold(gold)}</span>
      <span className="status-hud-recipes">{discoveredCount}/10</span>
      <span className="status-hud-seed">{seedLabel}</span>
      <div className="status-hud-actions">
        <button onClick={onBack}>Back</button>
        <button className="btn-danger" onClick={onSurrender} disabled={isGameOver}>
          Surrender
        </button>
      </div>
    </div>
  )
}
