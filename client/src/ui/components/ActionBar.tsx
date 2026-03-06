import {
  HERO_NAMES,
  HERO_STATUS_EXPLORING,
  HERO_STATUS_IDLE,
  HERO_STATUS_RETURNING,
} from '@/game/constants'

interface HeroData {
  hero_id: number
  status: number
  return_at: bigint | number
}

interface Props {
  heroes: HeroData[]
  selectedHeroId: number
  isGameOver: boolean
  now: number
  onSendExpedition: (heroId: number) => void
  onClaimLoot: (heroId: number) => void
}

export function ActionBar({
  heroes,
  selectedHeroId,
  isGameOver,
  now,
  onSendExpedition,
  onClaimLoot,
}: Props) {
  if (selectedHeroId < 0) return null

  const hero = heroes.find((h) => h.hero_id === selectedHeroId)
  if (!hero) return null

  const remaining = Math.max(0, Number(hero.return_at) - now)
  const isIdle = hero.status === HERO_STATUS_IDLE
  const isExploring = hero.status === HERO_STATUS_EXPLORING
  const isReturning = hero.status === HERO_STATUS_RETURNING
  const lootReady = isReturning && remaining === 0
  const name = HERO_NAMES[hero.hero_id] ?? `Hero ${hero.hero_id}`

  return (
    <div className="action-bar floating-panel">
      <span className="action-bar-label">{name}</span>

      {isIdle && (
        <button
          className="btn-primary"
          onClick={() => onSendExpedition(hero.hero_id)}
          disabled={isGameOver}
        >
          Send Expedition
        </button>
      )}

      {isExploring && (
        <span className="action-bar-timer">Exploring... {remaining}s</span>
      )}

      {isReturning && !lootReady && (
        <span className="action-bar-timer">Returning... {remaining}s</span>
      )}

      {lootReady && (
        <button
          className="btn-primary btn-loot"
          onClick={() => onClaimLoot(hero.hero_id)}
          disabled={isGameOver}
        >
          Claim Loot
        </button>
      )}
    </div>
  )
}
