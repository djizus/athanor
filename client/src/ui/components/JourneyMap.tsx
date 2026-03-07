import { motion, AnimatePresence, LayoutGroup } from 'framer-motion'
import { ZONE_NAMES, ZONE_COLORS, ZONE_BG_KEYS, roleAssetUrl, ROLE_NAMES } from '@/game/constants'
import type { HeroPosition } from '@/hooks/useExpeditionTracker'
import './JourneyMap.css'

interface HeroData {
  hero_id: number
  role: number
  health: number
  max_health: number
}

export interface FloatingTextAnim {
  id: string
  heroId: number
  text: string
  color: string
  zoneId?: number
}

interface JourneyMapProps {
  heroes: HeroData[]
  heroPositions: Map<number, HeroPosition>
  floatingTexts: FloatingTextAnim[]
  onFloatingTextComplete: (id: string) => void
}

function HeroToken({ hero }: { hero: HeroData }) {
  const roleIdx = hero.role > 0 ? hero.role - 1 : hero.hero_id
  const hpPct = hero.max_health > 0 ? Math.min(100, (hero.health / hero.max_health) * 100) : 0
  const hpColor = hpPct > 50 ? 'var(--accent-green)' : hpPct > 25 ? '#ff9800' : 'var(--accent-red)'

  return (
    <motion.div
      className="hero-token"
      layoutId={`journey-hero-${hero.hero_id}`}
      transition={{ type: 'spring', stiffness: 200, damping: 25 }}
    >
      <img
        className="hero-token-portrait"
        src={roleAssetUrl(roleIdx)}
        alt={ROLE_NAMES[roleIdx] ?? 'Hero'}
      />
      <div className="hero-token-hp">
        <div className="hero-token-hp-fill" style={{ width: `${hpPct}%`, background: hpColor }} />
      </div>
    </motion.div>
  )
}

function FloatingText({ text, color, onComplete }: { text: string; color: string; onComplete: () => void }) {
  return (
    <motion.div
      className="journey-floating-text"
      style={{ color }}
      initial={{ opacity: 1, y: 0, scale: 1 }}
      animate={{ opacity: 0, y: -44, scale: 1.15 }}
      exit={{ opacity: 0 }}
      transition={{ duration: 0.85, ease: 'easeOut' }}
      onAnimationComplete={onComplete}
    >
      {text}
    </motion.div>
  )
}

function ZoneBand({
  zoneId,
  heroes,
  isActive,
  floatingTexts,
  onFloatingTextComplete,
}: {
  zoneId: number
  heroes: HeroData[]
  isActive: boolean
  floatingTexts: FloatingTextAnim[]
  onFloatingTextComplete: (id: string) => void
}) {
  const bgKey = ZONE_BG_KEYS[zoneId]
  const color = ZONE_COLORS[zoneId]
  const name = ZONE_NAMES[zoneId]

  return (
    <div
      className={`jm-zone-band${isActive ? ' jm-zone-active' : ''}`}
      style={{ backgroundImage: `url(/assets/backgrounds/${bgKey}.webp)` }}
    >
      <div className="jm-zone-overlay" />
      <div className="jm-zone-label">
        <span className="jm-zone-name" style={{ color }}>{name}</span>
        <span className="jm-zone-depth">Zone {zoneId + 1}</span>
      </div>
      <div className="jm-zone-heroes">
        {heroes.map(hero => (
          <HeroToken key={hero.hero_id} hero={hero} />
        ))}
      </div>
      <AnimatePresence>
        {floatingTexts.map(ft => (
          <FloatingText key={ft.id} text={ft.text} color={ft.color} onComplete={() => onFloatingTextComplete(ft.id)} />
        ))}
      </AnimatePresence>
      {isActive && (
        <div className="jm-zone-glow" style={{ background: `radial-gradient(ellipse at center, ${color}22 0%, transparent 70%)` }} />
      )}
    </div>
  )
}

function HomeBand({
  heroes,
  floatingTexts,
  onFloatingTextComplete,
}: {
  heroes: HeroData[]
  floatingTexts: FloatingTextAnim[]
  onFloatingTextComplete: (id: string) => void
}) {
  return (
    <div className="jm-home-band">
      <div className="jm-home-bg" />
      <div className="jm-cauldron">
        <div className="jm-cauldron-glow" />
        <div className="jm-cauldron-body">
          <span className="jm-cauldron-label">Athanor</span>
        </div>
      </div>
      <div className="jm-zone-heroes">
        {heroes.map(hero => (
          <HeroToken key={hero.hero_id} hero={hero} />
        ))}
      </div>
      <AnimatePresence>
        {floatingTexts.map(ft => (
          <FloatingText key={ft.id} text={ft.text} color={ft.color} onComplete={() => onFloatingTextComplete(ft.id)} />
        ))}
      </AnimatePresence>
    </div>
  )
}

export function JourneyMap({ heroes, heroPositions, floatingTexts, onFloatingTextComplete }: JourneyMapProps) {
  const heroesByZone = new Map<number, HeroData[]>()
  for (let i = -1; i < 5; i++) heroesByZone.set(i, [])

  for (const hero of heroes) {
    const pos = heroPositions.get(hero.hero_id)
    const zone = pos ? (pos.returning ? -1 : pos.zoneIndex) : -1
    heroesByZone.get(zone >= 0 ? zone : -1)!.push(hero)
  }

  const textsByZone = new Map<number, FloatingTextAnim[]>()
  for (let i = -1; i < 5; i++) textsByZone.set(i, [])
  for (const ft of floatingTexts) {
    const zone = ft.zoneId != null ? ft.zoneId : (() => {
      const pos = heroPositions.get(ft.heroId)
      return pos ? pos.zoneIndex : -1
    })()
    textsByZone.get(zone >= 0 && zone < 5 ? zone : -1)!.push(ft)
  }

  const activeZones = new Set<number>()
  for (const [, pos] of heroPositions) {
    if (!pos.returning && pos.zoneIndex >= 0) {
      activeZones.add(pos.zoneIndex)
    }
  }

  return (
    <div className="journey-map">
      <LayoutGroup>
        {[4, 3, 2, 1, 0].map(zoneId => (
          <ZoneBand
            key={zoneId}
            zoneId={zoneId}
            heroes={heroesByZone.get(zoneId) ?? []}
            isActive={activeZones.has(zoneId)}
            floatingTexts={textsByZone.get(zoneId) ?? []}
            onFloatingTextComplete={onFloatingTextComplete}
          />
        ))}
        <HomeBand
          heroes={heroesByZone.get(-1) ?? []}
          floatingTexts={textsByZone.get(-1) ?? []}
          onFloatingTextComplete={onFloatingTextComplete}
        />
      </LayoutGroup>
    </div>
  )
}
