import {
  HERO_NAMES,
  HERO_RECRUIT_COSTS,
  HERO_STATUS_EXPLORING,
  HERO_STATUS_RETURNING,
  displayGold,
  displayHp,
  heroAssetUrl,
} from '@/game/constants'

interface HeroData {
  hero_id: number
  hp: number
  max_hp: number
  status: number
  return_at: bigint | number
  pending_gold: number
}

interface Props {
  heroes: HeroData[]
  heroCount: number
  selectedHeroId: number
  gold: number
  isGameOver: boolean
  now: number
  onSelectHero: (heroId: number) => void
  onRecruit: () => void
}

export function MiniHeroRoster({
  heroes,
  heroCount,
  selectedHeroId,
  gold,
  isGameOver,
  now,
  onSelectHero,
  onRecruit,
}: Props) {
  return (
    <div className="mini-roster floating-panel">
      {[0, 1, 2].map((slot) => {
        const hero = heroes.find((h) => h.hero_id === slot)

        if (!hero) {
          if (slot < heroCount) return null
          if (slot === heroCount && heroCount < 3) {
            const cost = HERO_RECRUIT_COSTS[Math.min(heroCount, 2)]
            return (
              <div key={slot} className="mini-roster-locked">
                <div className="mini-roster-locked-icon">+</div>
                <div className="mini-roster-info">
                  <span className="mini-roster-name">{HERO_NAMES[slot]}</span>
                  <button
                    className="mini-roster-recruit-btn btn-primary"
                    onClick={onRecruit}
                    disabled={isGameOver || gold < cost}
                  >
                    Recruit ({displayGold(cost)}g)
                  </button>
                </div>
              </div>
            )
          }
          return null
        }

        const hpPct = hero.max_hp > 0 ? Math.min(100, (hero.hp / hero.max_hp) * 100) : 0
        const remaining = Math.max(0, Number(hero.return_at) - now)
        const isExploring = hero.status === HERO_STATUS_EXPLORING
        const isReturning = hero.status === HERO_STATUS_RETURNING
        const lootReady = isReturning && remaining === 0

        let statusText = 'Ready'
        let statusClass = ''
        if (lootReady) { statusText = 'Loot!'; statusClass = 'loot-ready' }
        else if (isExploring) { statusText = `Exploring ${remaining}s`; statusClass = 'exploring' }
        else if (isReturning) { statusText = `Returning ${remaining}s`; statusClass = 'returning' }

        const hpColor = hpPct > 50 ? 'var(--accent-green)' : hpPct > 25 ? '#ff9800' : 'var(--accent-red)'

        return (
          <div
            key={hero.hero_id}
            className={`mini-roster-hero${selectedHeroId === hero.hero_id ? ' selected' : ''}`}
            onClick={() => onSelectHero(hero.hero_id)}
          >
            <img
              className="mini-roster-portrait"
              src={heroAssetUrl(hero.hero_id)}
              alt={HERO_NAMES[hero.hero_id]}
            />
            <div className="mini-roster-info">
              <span className="mini-roster-name">
                {HERO_NAMES[hero.hero_id]} — {displayHp(hero.hp)}/{displayHp(hero.max_hp)}
              </span>
              <div className="mini-roster-hp">
                <div
                  className="mini-roster-hp-fill"
                  style={{ width: `${hpPct}%`, background: hpColor }}
                />
              </div>
              <span className={`mini-roster-status ${statusClass}`}>{statusText}</span>
            </div>
          </div>
        )
      })}
    </div>
  )
}
