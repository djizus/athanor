import { useCallback, useMemo, useRef, useState } from 'react'
import { motion, AnimatePresence, LayoutGroup } from 'framer-motion'
import {
  ZONE_NAMES,
  ZONE_COLORS,
  INGREDIENT_NAMES,
  DEFAULT_INGREDIENTS_PER_ZONE,
  roleAssetUrl,
  ROLE_NAMES,
  ingredientAssetUrl,
  displayGold,
} from '@/game/constants'
import type { HeroPosition } from '@/hooks/useExpeditionTracker'
import type { HeroOverride } from '@/hooks/useExplorationLog'
import './JourneyMap.css'

const ZONE_DRAIN = [1, 2, 3, 4, 5]
const ZONE_GOLD_RANGE: [number, number][] = [
  [200, 500],
  [300, 600],
  [400, 900],
  [500, 1200],
  [600, 1500],
]
const ZONE_RISK_LABEL = ['Low', 'Moderate', 'High', 'Extreme', 'Deadly'] as const
const ZONE_RISK_COLOR = ['#40c060', '#a0c040', '#f0c040', '#e07030', '#d04050'] as const

const ZONE_PORTAL_KEYS = [
  'portal-hollows', 'portal-cavern', 'portal-spire', 'portal-abyss', 'portal-crystalveil',
] as const

interface HeroData {
  hero_id: number
  role: number
  health: number
  max_health: number
  gold: number
  ingredients: number[] | null
  lootReady: boolean
  isClaimPending: boolean
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
  onSelectHero: (heroId: number) => void
  onClaim: (heroId: number) => void
}

const RING_NORMAL = { size: 90, radius: 40, stroke: 4 }
const RING_SMALL = { size: 66, radius: 28, stroke: 3.5 }

function spawnClaimParticles(
  sourceEl: HTMLElement,
  hero: HeroData,
) {
  const sourceRect = sourceEl.getBoundingClientRect()
  const sx = sourceRect.left + sourceRect.width / 2
  const sy = sourceRect.top + sourceRect.height / 2

  const goldTarget = document.querySelector('[data-claim-target="gold"]')
  const invTarget = document.querySelector('[data-claim-target="ingredients"]')

  if (hero.gold > 0 && goldTarget) {
    const tr = goldTarget.getBoundingClientRect()
    spawnFlyingOrb(sx, sy, tr.left + tr.width / 2, tr.top + tr.height / 2, '/assets/ui/gold-coin.webp')
  }

  if (hero.ingredients && invTarget) {
    const tr = invTarget.getBoundingClientRect()
    hero.ingredients.forEach((qty, idx) => {
      if (qty > 0) {
        setTimeout(() => {
          spawnFlyingOrb(
            sx + (Math.random() - 0.5) * 20,
            sy + (Math.random() - 0.5) * 10,
            tr.left + 40,
            tr.top + tr.height / 2,
            ingredientAssetUrl(idx),
          )
        }, idx * 80)
      }
    })
  }
}

export function spawnFlyingOrb(
  fromX: number, fromY: number,
  toX: number, toY: number,
  iconSrc: string,
) {
  const el = document.createElement('div')
  el.className = 'claim-fly-particle'
  const img = document.createElement('img')
  img.src = iconSrc
  img.className = 'claim-fly-particle-icon'
  el.appendChild(img)
  el.style.left = `${fromX}px`
  el.style.top = `${fromY}px`
  el.style.setProperty('--fly-dx', `${toX - fromX}px`)
  el.style.setProperty('--fly-dy', `${toY - fromY}px`)
  document.body.appendChild(el)
  el.addEventListener('animationend', () => el.remove())
}

function HpRing({ pct, color, cfg, selected }: { pct: number; color: string; cfg: typeof RING_NORMAL; selected?: boolean }) {
  const circ = 2 * Math.PI * cfg.radius
  const offset = circ * (1 - pct / 100)

  return (
    <svg
      className={`hero-token-ring${selected ? ' hero-token-ring-selected' : ''}`}
      width={cfg.size}
      height={cfg.size}
      viewBox={`0 0 ${cfg.size} ${cfg.size}`}
    >
      <circle
        cx={cfg.size / 2}
        cy={cfg.size / 2}
        r={cfg.radius}
        fill="none"
        stroke="rgba(255,255,255,0.08)"
        strokeWidth={cfg.stroke}
      />
      <circle
        className="hero-token-ring-fill"
        cx={cfg.size / 2}
        cy={cfg.size / 2}
        r={cfg.radius}
        fill="none"
        stroke={color}
        strokeWidth={cfg.stroke}
        strokeLinecap="round"
        strokeDasharray={circ}
        strokeDashoffset={offset}
        transform={`rotate(-90 ${cfg.size / 2} ${cfg.size / 2})`}
      />
    </svg>
  )
}

function HeroToken({ hero, small, selected, onClick, onClaim }: {
  hero: HeroData; small?: boolean; selected?: boolean
  onClick?: () => void; onClaim?: () => void
}) {
  const [claimBurst, setClaimBurst] = useState(false)
  const satchelRef = useRef<HTMLDivElement>(null)
  const roleIdx = hero.role > 0 ? hero.role - 1 : hero.hero_id
  const hpPct = hero.max_health > 0 ? Math.min(100, (hero.health / hero.max_health) * 100) : 0
  const hpColor = hpPct > 50 ? 'var(--accent-green)' : hpPct > 25 ? '#ff9800' : 'var(--accent-red)'
  const hasLoot = hero.gold > 0 || (hero.ingredients && hero.ingredients.some(q => q > 0))
  const ringCfg = small ? RING_SMALL : RING_NORMAL

  const handleClaim = useCallback((e: React.MouseEvent) => {
    e.stopPropagation()
    if (!hero.lootReady || hero.isClaimPending) return
    setClaimBurst(true)
    setTimeout(() => setClaimBurst(false), 600)
    if (satchelRef.current) {
      spawnClaimParticles(satchelRef.current, hero)
    }
    onClaim?.()
  }, [hero, onClaim])

  return (
    <motion.div
      className={`hero-token${small ? ' hero-token-sm' : ''}${selected ? ' hero-token-selected' : ''}`}
      layoutId={`journey-hero-${hero.hero_id}`}
      data-hero-id={hero.hero_id}
      transition={{ type: 'spring', stiffness: 200, damping: 25 }}
      onClick={(e) => { e.stopPropagation(); onClick?.() }}
    >
      <div className="hero-token-frame-wrap">
        <HpRing pct={hpPct} color={hpColor} cfg={ringCfg} selected={selected} />
        <img
          className="hero-token-frame"
          src="/assets/ui/hero-frame.webp"
          alt=""
          draggable={false}
        />
        <img
          className="hero-token-portrait"
          src={roleAssetUrl(roleIdx)}
          alt={ROLE_NAMES[roleIdx] ?? 'Hero'}
        />
        {claimBurst && <div className="hero-token-claim-burst" />}
      </div>

      {hasLoot && (
        <div
          ref={satchelRef}
          className={`hero-token-loot${hero.lootReady ? ' hero-token-loot-ready' : ''}${hero.isClaimPending ? ' hero-token-loot-pending' : ''}`}
          onClick={hero.lootReady ? handleClaim : undefined}
          role={hero.lootReady ? 'button' : undefined}
        >
          <div className="hero-token-loot-items">
            {hero.gold > 0 && (
              <span className="hero-token-loot-ing-wrap">
                <img className="hero-token-loot-ing hero-token-loot-coin" src="/assets/ui/gold-coin.webp" alt="Gold" />
                <span className="hero-token-loot-ing-qty">{displayGold(hero.gold)}</span>
              </span>
            )}
            {hero.ingredients && hero.ingredients.map((qty, idx) =>
              qty > 0 ? (
                <span key={idx} className="hero-token-loot-ing-wrap">
                  <img className="hero-token-loot-ing" src={ingredientAssetUrl(idx)} alt={INGREDIENT_NAMES[idx]} title={`${INGREDIENT_NAMES[idx]} x${qty}`} />
                  {qty > 1 && <span className="hero-token-loot-ing-qty">{qty}</span>}
                </span>
              ) : null,
            )}
          </div>
        </div>
      )}
    </motion.div>
  )
}

function FloatingText({ text, color, icon, onComplete }: { text: string; color: string; icon?: string; onComplete: () => void }) {
  const isLoot = text.includes('+') && !text.includes('HP')

  return (
    <>
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
      {isLoot && (
        <motion.div
          className="loot-particle"
          initial={{ opacity: 0.9, y: 0, x: 0, scale: 1 }}
          animate={{ opacity: 0, y: 60, x: (Math.random() - 0.5) * 20, scale: 0.3 }}
          exit={{ opacity: 0 }}
          transition={{ duration: 0.7, ease: 'easeIn' }}
        >
          {icon
            ? <img className="loot-particle-icon" src={icon} alt="" />
            : <img className="loot-particle-icon" src="/assets/ui/gold-coin.webp" alt="" />
          }
        </motion.div>
      )}
    </>
  )
}

const NODE_POSITIONS = {
  athanor: { x: 50, y: 80 },
  lineOrigin: { x: 50, y: 76 },
  zones: [
    { x: 38, y: 62 },
    { x: 62, y: 56 },
    { x: 36, y: 38 },
    { x: 64, y: 32 },
    { x: 50, y: 18 },
  ],
} as const

function ZoneTooltip({ zoneId }: { zoneId: number }) {
  const drain = ZONE_DRAIN[zoneId]
  const [goldMin, goldMax] = ZONE_GOLD_RANGE[zoneId]
  const riskLabel = ZONE_RISK_LABEL[zoneId]
  const riskColor = ZONE_RISK_COLOR[zoneId]
  const startIdx = zoneId * DEFAULT_INGREDIENTS_PER_ZONE
  const ingredientIds = Array.from({ length: DEFAULT_INGREDIENTS_PER_ZONE }, (_, i) => startIdx + i)

  return (
    <div className="zone-tooltip">
      <div className="zone-tooltip-header">
        <span className="zone-tooltip-name" style={{ color: ZONE_COLORS[zoneId] }}>
          {ZONE_NAMES[zoneId]}
        </span>
        <span className="zone-tooltip-risk" style={{ color: riskColor }}>
          {'💀'.repeat(zoneId + 1)} {riskLabel}
        </span>
      </div>
      <div className="zone-tooltip-stats">
        <span className="zone-tooltip-gold">{goldMin}–{goldMax}g</span>
        <span className="zone-tooltip-drain">{drain} HP/tick</span>
      </div>
      <div className="zone-tooltip-ingredients">
        {ingredientIds.map(id => (
          <img
            key={id}
            className="zone-tooltip-ingredient"
            src={ingredientAssetUrl(id)}
            alt={INGREDIENT_NAMES[id]}
            title={INGREDIENT_NAMES[id]}
          />
        ))}
      </div>
    </div>
  )
}

function ZoneNode({
  zoneId,
  x, y,
  heroes,
  isActive,
  canSendHero,
  selectedHeroId,
  onSelectHero,
  onClaim,
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
  selectedHeroId: number
  onSelectHero: (heroId: number) => void
  onClaim: (heroId: number) => void
  floatingTexts: FloatingTextAnim[]
  onFloatingTextComplete: (id: string) => void
  onHover: () => void
  onLeave: () => void
  onClick: () => void
  isHovered: boolean
}) {
  const color = ZONE_COLORS[zoneId]
  const portalKey = ZONE_PORTAL_KEYS[zoneId]
  const FLOAT_DURATIONS = [3.8, 5.2, 4.4, 6.0, 4.9] as const
  const FLOAT_DELAYS = [-0.5, -3.1, -1.7, -4.8, -2.3] as const

  return (
    <div
      className={`zone-node${isActive ? ' zone-node-active' : ''}${isHovered ? ' zone-node-hovered' : ''}`}
      style={{
        left: `${x}%`,
        top: `${y}%`,
        ['--zone-color' as string]: color,
      }}
      onMouseEnter={onHover}
      onMouseLeave={onLeave}
    >
      <div className="zone-node-glow" />
      <img
        className="zone-node-icon"
        src={`/assets/zones/${portalKey}.webp`}
        alt={ZONE_NAMES[zoneId]}
        style={{
          animationDuration: `${FLOAT_DURATIONS[zoneId]}s`,
          animationDelay: `${FLOAT_DELAYS[zoneId]}s`,
        }}
      />

      {heroes.length > 0 && (
        <div className="zone-node-heroes">
          {heroes.map(hero => (
            <HeroToken key={hero.hero_id} hero={hero} small selected={hero.hero_id === selectedHeroId} onClick={() => onSelectHero(hero.hero_id)} onClaim={() => onClaim(hero.hero_id)} />
          ))}
        </div>
      )}

      {canSendHero && (
        <button className="zone-action-btn" onClick={onClick}>
          Explore
        </button>
      )}

      <AnimatePresence>
        {floatingTexts.map(ft => (
          <FloatingText key={ft.id} text={ft.text} color={ft.color} icon={ft.icon} onComplete={() => onFloatingTextComplete(ft.id)} />
        ))}
      </AnimatePresence>

      {isHovered && <ZoneTooltip zoneId={zoneId} />}
    </div>
  )
}

function AthanorNode({
  heroes,
  selectedHeroId,
  onSelectHero,
  onClaim,
  floatingTexts,
  onFloatingTextComplete,
  hintText,
}: {
  heroes: HeroData[]
  selectedHeroId: number
  onSelectHero: (heroId: number) => void
  onClaim: (heroId: number) => void
  floatingTexts: FloatingTextAnim[]
  onFloatingTextComplete: (id: string) => void
  hintText: string | null
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
            <HeroToken key={hero.hero_id} hero={hero} selected={hero.hero_id === selectedHeroId} onClick={() => onSelectHero(hero.hero_id)} onClaim={() => onClaim(hero.hero_id)} />
          ))}
        </div>
      )}

      {hintText && (
        <div className="constellation-hint">{hintText}</div>
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
  onSelectHero,
  onClaim,
}: JourneyMapProps) {
  const [hoveredZone, setHoveredZone] = useState<number | null>(null)
  const particlesRef = useRef(Array.from({ length: 20 }, (_, i) => i))

  const heroesByZone = useMemo(() => {
    const map = new Map<number, HeroData[]>()
    for (let i = -1; i < 5; i++) map.set(i, [])

    for (const hero of heroes) {
      const pos = heroPositions.get(hero.hero_id)
      const trackerZone = pos ? pos.zoneIndex : -1
      const isActivelyExploring = pos != null && pos.zoneIndex >= 0
      const override = isActivelyExploring ? heroOverrides?.get(hero.hero_id) : undefined
      const zone = override?.zoneIndex ?? (pos?.returning ? -1 : trackerZone)
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
  const selectedPos = heroPositions.get(selectedHeroId)
  const canSendSelected = selectedHero != null
    && !isGameOver
    && selectedHero.health > 0
    && (!selectedPos || (selectedPos.zoneIndex === -1 && !selectedPos.returning))

  const origin = NODE_POSITIONS.lineOrigin
  const zones = NODE_POSITIONS.zones

  return (
    <div className="journey-map">
      <img
        className="constellation-bg"
        src="/assets/zones/constellation-bg.webp"
        alt=""
      />
      <div className="constellation-overlay" />

      <div className="map-particles" aria-hidden>
        {particlesRef.current.map(i => (
          <span key={`map-particle-${i}`} className="map-particle" />
        ))}
      </div>

      <svg className="constellation-lines">
        {zones.map((pos, i) => (
          <g key={i}>
            <line
              x1={`${origin.x}%`} y1={`${origin.y}%`}
              x2={`${pos.x}%`} y2={`${pos.y}%`}
              stroke="rgba(0,0,0,0.8)"
              strokeWidth="5"
              strokeDasharray="6 8"
              strokeLinecap="round"
            />
            <line
              x1={`${origin.x}%`} y1={`${origin.y}%`}
              x2={`${pos.x}%`} y2={`${pos.y}%`}
              stroke={ZONE_COLORS[i]}
              strokeWidth="2"
              strokeDasharray="6 8"
              strokeLinecap="round"
              strokeOpacity={activeZones.has(i) ? '0.9' : '0.5'}
            />
          </g>
        ))}
      </svg>

      <LayoutGroup>
        {zones.map((pos, zoneId) => (
          <ZoneNode
            key={zoneId}
            zoneId={zoneId}
            x={pos.x}
            y={pos.y}
            heroes={heroesByZone.get(zoneId) ?? []}
            isActive={activeZones.has(zoneId)}
            canSendHero={canSendSelected}
            selectedHeroId={selectedHeroId}
            onSelectHero={onSelectHero}
            onClaim={onClaim}
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
          selectedHeroId={selectedHeroId}
          onSelectHero={onSelectHero}
          onClaim={onClaim}
          floatingTexts={textsByZone.get(-1) ?? []}
          onFloatingTextComplete={onFloatingTextComplete}
          hintText={canSendSelected ? `Select a zone to send ${ROLE_NAMES[selectedHero!.role > 0 ? selectedHero!.role - 1 : selectedHeroId] ?? 'hero'}` : null}
        />
      </LayoutGroup>
    </div>
  )
}
