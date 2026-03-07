import {
  ROLE_NAMES,
} from '@/game/constants'

interface HeroData {
  id: number
  role: number
  available_at: bigint | number
}

interface Props {
  heroes: HeroData[]
  selectedHeroId: number
  isGameOver: boolean
  now: number
  onExplore: (characterId: number) => void
  onClaim: (characterId: number) => void
}

export function ActionBar({
  heroes,
  selectedHeroId,
  isGameOver,
  now,
  onExplore,
  onClaim,
}: Props) {
  if (selectedHeroId < 0) return null

  const hero = heroes.find((h) => h.id === selectedHeroId)
  if (!hero) return null

  const remaining = Math.max(0, Number(hero.available_at) - now)
  const isIdle = remaining === 0
  const isExploring = remaining > 0
  const roleIdx = hero.role > 0 ? hero.role - 1 : hero.id
  const name = ROLE_NAMES[roleIdx] ?? `Hero ${hero.id}`

  return (
    <div className="action-bar floating-panel">
      <span className="action-bar-label">{name}</span>

      {isIdle && (
        <button
          className="btn-primary"
          onClick={() => onExplore(hero.id)}
          disabled={isGameOver}
        >
          Send Expedition
        </button>
      )}

      {isExploring && (
        <span className="action-bar-timer">Exploring... {remaining}s</span>
      )}
    </div>
  )
}
