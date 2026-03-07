import {
  HERO_RECRUIT_COSTS,
  ROLE_NAMES,
  displayGold,
  displayHp,
  roleAssetUrl,
} from '@/game/constants'

interface HeroData {
  id: number
  role: number
  health: number
  max_health: number
  available_at: bigint | number
  gold: number
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
        const hero = heroes.find((h) => h.id === slot)

        if (!hero) {
          if (slot < heroCount) return null
          if (slot === heroCount && heroCount < 3) {
            const cost = HERO_RECRUIT_COSTS[Math.min(heroCount, 2)]
            return (
              <div key={slot} className="mini-roster-locked">
                <div className="mini-roster-locked-icon">+</div>
                <div className="mini-roster-info">
                  <span className="mini-roster-name">Recruit</span>
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

        const roleIdx = hero.role > 0 ? hero.role - 1 : slot
        const roleName = ROLE_NAMES[roleIdx] ?? `Hero ${slot}`
        const hpPct = hero.max_health > 0 ? Math.min(100, (hero.health / hero.max_health) * 100) : 0
        const remaining = Math.max(0, Number(hero.available_at) - now)
        const isExploring = remaining > 0

        let statusText = 'Ready'
        let statusClass = ''
        if (isExploring) { statusText = `Exploring ${remaining}s`; statusClass = 'exploring' }

        const hpColor = hpPct > 50 ? 'var(--accent-green)' : hpPct > 25 ? '#ff9800' : 'var(--accent-red)'

        return (
          <div
            key={hero.id}
            className={`mini-roster-hero${selectedHeroId === hero.id ? ' selected' : ''}`}
            onClick={() => onSelectHero(hero.id)}
          >
            <img
              className="mini-roster-portrait"
              src={roleAssetUrl(roleIdx)}
              alt={roleName}
            />
            <div className="mini-roster-info">
              <span className="mini-roster-name">
                {roleName} — {displayHp(hero.health)}/{displayHp(hero.max_health)}
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
