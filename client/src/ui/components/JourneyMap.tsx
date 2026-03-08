import { useMemo, useState } from 'react'
import { motion, AnimatePresence, LayoutGroup } from 'framer-motion'
import { ZONE_NAMES, ZONE_COLORS, roleAssetUrl, ROLE_NAMES } from '@/game/constants'
import type { HeroPosition } from '@/hooks/useExpeditionTracker'
import type { HeroOverride } from '@/hooks/useExplorationLog'
import './JourneyMap.css'

const ZONE_DRAIN = [1, 2, 3, 4, 5]
const ZONE_PORTAL_KEYS = [
  'portal-hollows', 'portal-cavern', 'portal-spire', 'portal-abyss', 'portal-crystalveil',
] as const

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
  icon?: string
}

interface JourneyMapProps {
  heroes: HeroData[]
  heroPositions: Map<number, HeroPosition>
  heroOverrides?: Map<number, HeroOverride>
  floatingTexts: FloatingTextAnim[]
  onFloatingTextComplete: (id: string) => void
  selectedHeroId: number
  isGameOver: boolean
  onExplore: (heroId: number, zoneId: number) => void
}

function HeroToken({ hero, small }: { hero: HeroData; small?: boolean }) {
  const roleIdx = hero.role > 0 ? hero.role - 1 : hero.hero_id
  const hpPct = hero.max_health > 0 ? Math.min(100, (hero.health / hero.max_health) * 100) : 0
  const hpColor = hpPct > 50 ? 'var(--accent-green)' : hpPct > 25 ? '#ff9800' : 'var(--accent-red)'

  return (
    <motion.div
      className={`hero-token${small ? ' hero-token-sm' : ''}`}
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

function FloatingText({ text, color, icon, onComplete }: { text: string; color: string; icon?: string; onComplete: () => void }) {
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
      {icon && <img className="journey-floating-icon" src={icon} alt="" />}
    </motion.div>
  )
}

const NODE_POSITIONS = {
  athanor: { x: 50, y: 80 },
  zones: [
    { x: 30, y: 55 },
    { x: 35, y: 30 },
    { x: 55, y: 18 },
    { x: 68, y: 35 },
    { x: 65, y: 58 },
  ],
} as const

function ConstellationLine({ x1, y1, x2, y2, color, active }: {
  x1: number; y1: number; x2: number; y2: number; color: string; active: boolean
}) {
  return (
    <line
      x1={`${x1}%`} y1={`${y1}%`}
      x2={`${x2}%`} y2={`${y2}%`}
      stroke={active ? color : '#a0802040'}
      strokeWidth={active ? 2 : 1}
      strokeDasharray={active ? 'none' : '6 4'}
      className={active ? 'constellation-line-active' : 'constellation-line'}
    />
  )
}

function ZoneTooltip({ zoneId, canSend }: { zoneId: number; canSend: boolean }) {
  const name = ZONE_NAMES[zoneId]
  const drain = ZONE_DRAIN[zoneId]

  return (
    <div className="zone-tooltip">
      <span className="zone-tooltip-name" style={{ color: ZONE_COLORS[zoneId] }}>{name}</span>
      <span className="zone-tooltip-stat zone-tooltip-stat-drain">HP Drain: {drain}/tick</span>
      <span className="zone-tooltip-stat">Zone {zoneId + 1} of 5</span>
      {canSend && <span className="zone-tooltip-stat" style={{ color: 'var(--accent-gold)' }}>Click to explore</span>}
    </div>
  )
}

function ZoneNode({
  zoneId,
  x, y,
  heroes,
  isActive,
  canSendHero,
  floatingTexts,
  onFloatingTextComplete,
  onHover,
  onLeave,
  onClick,
  isHovered,
}: {
  zoneId: number
  x: number
  y: number
  heroes: HeroData[]
  isActive: boolean
  canSendHero: boolean
  floatingTexts: FloatingTextAnim[]
  onFloatingTextComplete: (id: string) => void
  onHover: () => void
  onLeave: () => void
  onClick: () => void
  isHovered: boolean
}) {
  const color = ZONE_COLORS[zoneId]
  const portalKey = ZONE_PORTAL_KEYS[zoneId]

  return (
    <div
      className={`zone-node${isActive ? ' zone-node-active' : ''}${canSendHero ? ' zone-node-clickable' : ''}${isHovered ? ' zone-node-hovered' : ''}`}
      style={{
        left: `${x}%`,
        top: `${y}%`,
        ['--zone-color' as string]: color,
      }}
      onMouseEnter={onHover}
      onMouseLeave={onLeave}
      onClick={canSendHero ? onClick : undefined}
    >
      <div className="zone-node-glow" />
      {canSendHero && <div className="zone-node-ring" />}
      <img
        className="zone-node-icon"
        src={`/assets/zones/${portalKey}.webp`}
        alt={ZONE_NAMES[zoneId]}
      />
      <span className="zone-node-label">{ZONE_NAMES[zoneId]}</span>

      {heroes.length > 0 && (
        <div className="zone-node-heroes">
          {heroes.map(hero => (
            <HeroToken key={hero.hero_id} hero={hero} small />
          ))}
        </div>
      )}

      <AnimatePresence>
        {floatingTexts.map(ft => (
          <FloatingText key={ft.id} text={ft.text} color={ft.color} icon={ft.icon} onComplete={() => onFloatingTextComplete(ft.id)} />
        ))}
      </AnimatePresence>

      {isHovered && <ZoneTooltip zoneId={zoneId} canSend={canSendHero} />}
    </div>
  )
}

function AthanorNode({
  heroes,
  floatingTexts,
  onFloatingTextComplete,
}: {
  heroes: HeroData[]
  floatingTexts: FloatingTextAnim[]
  onFloatingTextComplete: (id: string) => void
}) {
  return (
    <div
      className="zone-node zone-node-athanor"
      style={{
        left: `${NODE_POSITIONS.athanor.x}%`,
        top: `${NODE_POSITIONS.athanor.y}%`,
      }}
    >
      <div className="zone-node-glow athanor-glow" />
      <img
        className="zone-node-icon athanor-icon"
        src="/assets/zones/portal-athanor.webp"
        alt="Athanor"
      />
      <span className="zone-node-label athanor-label">Athanor</span>

      {heroes.length > 0 && (
        <div className="zone-node-heroes">
          {heroes.map(hero => (
            <HeroToken key={hero.hero_id} hero={hero} />
          ))}
        </div>
      )}

      <AnimatePresence>
        {floatingTexts.map(ft => (
          <FloatingText key={ft.id} text={ft.text} color={ft.color} icon={ft.icon} onComplete={() => onFloatingTextComplete(ft.id)} />
        ))}
      </AnimatePresence>
    </div>
  )
}

export function JourneyMap({
  heroes,
  heroPositions,
  heroOverrides,
  floatingTexts,
  onFloatingTextComplete,
  selectedHeroId,
  isGameOver,
  onExplore,
}: JourneyMapProps) {
  const [hoveredZone, setHoveredZone] = useState<number | null>(null)

  const heroesByZone = useMemo(() => {
    const map = new Map<number, HeroData[]>()
    for (let i = -1; i < 5; i++) map.set(i, [])

    for (const hero of heroes) {
      const override = heroOverrides?.get(hero.hero_id)
      const playbackZone = override?.zoneIndex
      const pos = heroPositions.get(hero.hero_id)
      const trackerZone = pos ? (pos.returning ? -1 : pos.zoneIndex) : -1
      const zone = playbackZone != null ? playbackZone : trackerZone
      map.get(zone >= 0 && zone < 5 ? zone : -1)!.push(hero)
    }
    return map
  }, [heroes, heroPositions, heroOverrides])

  const textsByZone = useMemo(() => {
    const map = new Map<number, FloatingTextAnim[]>()
    for (let i = -1; i < 5; i++) map.set(i, [])

    for (const ft of floatingTexts) {
      const zone = ft.zoneId != null ? ft.zoneId : (() => {
        const pos = heroPositions.get(ft.heroId)
        return pos ? pos.zoneIndex : -1
      })()
      map.get(zone >= 0 && zone < 5 ? zone : -1)!.push(ft)
    }
    return map
  }, [floatingTexts, heroPositions])

  const activeZones = useMemo(() => {
    const set = new Set<number>()
    for (const [, pos] of heroPositions) {
      if (!pos.returning && pos.zoneIndex >= 0) {
        set.add(pos.zoneIndex)
      }
    }
    return set
  }, [heroPositions])

  const selectedHero = heroes.find(h => h.hero_id === selectedHeroId)
  const canSendSelected = selectedHero != null
    && !isGameOver
    && selectedHero.health > 0
    && !heroPositions.get(selectedHeroId)?.returning
    && (() => {
      const pos = heroPositions.get(selectedHeroId)
      return !pos || pos.zoneIndex === -1
    })()

  return (
    <div className="journey-map">
      <img
        className="constellation-bg"
        src="/assets/zones/constellation-bg.webp"
        alt=""
      />
      <div className="constellation-overlay" />

      <svg className="constellation-lines" viewBox="0 0 100 100" preserveAspectRatio="none">
        {NODE_POSITIONS.zones.map((pos, i) => (
          <ConstellationLine
            key={i}
            x1={NODE_POSITIONS.athanor.x}
            y1={NODE_POSITIONS.athanor.y}
            x2={pos.x}
            y2={pos.y}
            color={ZONE_COLORS[i]}
            active={activeZones.has(i)}
          />
        ))}
      </svg>

      <LayoutGroup>
        {NODE_POSITIONS.zones.map((pos, zoneId) => (
          <ZoneNode
            key={zoneId}
            zoneId={zoneId}
            x={pos.x}
            y={pos.y}
            heroes={heroesByZone.get(zoneId) ?? []}
            isActive={activeZones.has(zoneId)}
            canSendHero={canSendSelected}
            floatingTexts={textsByZone.get(zoneId) ?? []}
            onFloatingTextComplete={onFloatingTextComplete}
            onHover={() => setHoveredZone(zoneId)}
            onLeave={() => setHoveredZone(null)}
            onClick={() => {
              if (canSendSelected) onExplore(selectedHeroId, zoneId)
            }}
            isHovered={hoveredZone === zoneId}
          />
        ))}

        <AthanorNode
          heroes={heroesByZone.get(-1) ?? []}
          floatingTexts={textsByZone.get(-1) ?? []}
          onFloatingTextComplete={onFloatingTextComplete}
        />
      </LayoutGroup>

      {canSendSelected && (
        <div className="constellation-hint">
          Select a zone to send {ROLE_NAMES[selectedHero!.role > 0 ? selectedHero!.role - 1 : selectedHeroId] ?? 'hero'}
        </div>
      )}
    </div>
  )
}
