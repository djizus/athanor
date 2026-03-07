import { useCallback, useEffect, useMemo, useRef, useState } from 'react'
import { useAccount } from '@starknet-react/core'
import { useDojo } from '@/dojo/useDojo'
import { useGame } from '@/hooks/useGame'
import { useHeroes } from '@/hooks/useHeroes'
import { useInventory } from '@/hooks/useInventory'
import { useRecipes } from '@/hooks/useRecipes'
import { useHints } from '@/hooks/useHints'
import { useExplorationLog } from '@/hooks/useExplorationLog'
import { useNavigationStore } from '@/stores/navigationStore'
import { txToast } from '@/stores/toastStore'
import type { PhaserBridge } from '@/phaser'
import {
  HERO_RECRUIT_COSTS,
  ROLE_NAMES,
  displayGold,
  displayHp,
  roleAssetUrl,
} from '@/game/constants'
import { bitmapPopcount, unpackEffects } from '@/game/packer'
import type { DiscoveryData } from '@/hooks/useRecipes'
import { StatusHUD } from '@/ui/components/StatusHUD'
import { BrewContent, IngredientsContent, GrimoireContent } from '@/ui/components/RightPanel'
import type { PanelMode } from '@/ui/components/RightPanel'
import { SettingsOverlay } from '@/ui/components/SettingsOverlay'

function computeUntriedPairs(
  inventory: { ingredient_id: number; quantity: number }[],
  recipes: DiscoveryData[],
): [number, number][] {
  const tried = new Set<string>()
  for (const r of recipes) {
    tried.add(`${r.ingredient_a}-${r.ingredient_b}`)
    tried.add(`${r.ingredient_b}-${r.ingredient_a}`)
  }

  const inv = new Map<number, number>()
  for (const item of inventory) {
    if (item.quantity > 0) inv.set(item.ingredient_id, item.quantity)
  }

  const ids = [...inv.keys()].sort((a, b) => a - b)
  const pairs: [number, number][] = []

  for (let i = 0; i < ids.length; i++) {
    for (let j = i + 1; j < ids.length; j++) {
      const a = ids[i]
      const b = ids[j]
      if (tried.has(`${a}-${b}`)) continue
      const qA = inv.get(a) ?? 0
      const qB = inv.get(b) ?? 0
      if (qA >= 1 && qB >= 1) {
        pairs.push([a, b])
        inv.set(a, qA - 1)
        inv.set(b, qB - 1)
      }
    }
  }
  return pairs
}

interface Props {
  bridge: PhaserBridge
}

export function PlayScreen({ bridge }: Props) {
  const { client } = useDojo()
  const { gameId, navigate } = useNavigationStore()
  const { account } = useAccount()
  const { game } = useGame(gameId)
  const heroes = useHeroes(gameId)
  const inventory = useInventory(gameId)
  const recipes = useRecipes(gameId)
  const hintIngredients = useHints(gameId)

  const [selectedHeroId, setSelectedHeroId] = useState(0)
  const [settingsOpen, setSettingsOpen] = useState(false)
  const [now, setNow] = useState(() => Math.floor(Date.now() / 1000))
  const [slotA, setSlotA] = useState<number | null>(null)
  const [slotB, setSlotB] = useState<number | null>(null)
  const [collectionTab, setCollectionTab] = useState<PanelMode>('ingredients')

  const [heroesCollapsed, setHeroesCollapsed] = useState(false)
  const [brewCollapsed, setBrewCollapsed] = useState(false)
  const [collectionCollapsed, setCollectionCollapsed] = useState(false)
  const [logsCollapsed, setLogsCollapsed] = useState(false)
  const { logs, pushInfo } = useExplorationLog(gameId ?? null)
  const logsEndRef = useRef<HTMLDivElement>(null)

  useEffect(() => {
    const timer = window.setInterval(() => setNow(Math.floor(Date.now() / 1000)), 1000)
    return () => window.clearInterval(timer)
  }, [])

  useEffect(() => {
    bridge.updateHeroes(
      heroes.map((h) => ({
        hero_id: h.id,
        role: h.role,
        health: h.health,
        max_health: h.max_health,
        power: h.power,
        regen: h.regen,
        gold: h.gold,
        available_at: Number(h.available_at),
      })),
    )
  }, [heroes, bridge])

  useEffect(() => {
    if (game) {
      const heroCount = bitmapPopcount(game.heroes)
      const discoveredCount = bitmapPopcount(game.grimoire)
      bridge.updateSession({
        game_id: gameId ?? 0,
        gold: game.gold,
        discovered_count: discoveredCount,
        hero_count: heroCount,
        game_over: Number(game.ended_at) > 0,
        started_at: Number(game.started_at),
        remaining_tries: game.remaining_tries,
      })
    }
  }, [game, bridge, gameId])

  useEffect(() => {
    const onHeroSelected = (heroId: number) => {
      if (heroId >= 0) setSelectedHeroId(heroId)
    }
    bridge.on('heroSelected', onHeroSelected)
    return () => { bridge.off('heroSelected', onHeroSelected) }
  }, [bridge])

  const scrollPanelIntoView = useCallback((panelClass: string, collapseSetter: React.Dispatch<React.SetStateAction<boolean>>) => {
    collapseSetter(false)
    requestAnimationFrame(() => {
      const el = document.querySelector(`.${panelClass}`)
      el?.scrollIntoView({ behavior: 'smooth', block: 'nearest' })
    })
  }, [])

  const handlePickIngredient = useCallback((id: number) => {
    if (slotA === id) { setSlotA(null); return }
    if (slotB === id) { setSlotB(null); return }
    if (slotA === null) { setSlotA(id) }
    else if (slotB === null) { setSlotB(id) }
    else { setSlotA(id); setSlotB(null) }
  }, [slotA, slotB])

  useEffect(() => {
    const onKeyDown = (e: KeyboardEvent) => {
      if (e.target instanceof HTMLInputElement || e.target instanceof HTMLSelectElement) return
      switch (e.key.toLowerCase()) {
        case 'c': scrollPanelIntoView('panel-brew', setBrewCollapsed); break
        case 'g': { setCollectionTab('grimoire'); scrollPanelIntoView('panel-collection', setCollectionCollapsed); break }
        case 'i': { setCollectionTab('ingredients'); scrollPanelIntoView('panel-collection', setCollectionCollapsed); break }
        case 'escape': setSelectedHeroId(-1); break
      }
    }
    window.addEventListener('keydown', onKeyDown)
    return () => window.removeEventListener('keydown', onKeyDown)
  }, [scrollPanelIntoView])

  useEffect(() => {
    if (logs.length > 0) {
      requestAnimationFrame(() => logsEndRef.current?.scrollIntoView({ behavior: 'smooth' }))
    }
  }, [logs.length])

  const handleExplore = async (characterId: number) => {
    if (!account || gameId == null) return
    const hero = heroes.find((h) => h.id === characterId)
    const name = hero ? ROLE_NAMES[hero.role > 0 ? hero.role - 1 : characterId] : `Hero ${characterId}`
    pushInfo(`${name} sent on expedition...`)
    const t = txToast('Sending expedition')
    try { await client.explore(account, gameId, characterId); t.success() } catch (e) { t.error(); pushInfo(`${name} expedition failed`); console.error('Explore failed:', e) }
  }

  const handleClaim = async (characterId: number) => {
    if (!account || gameId == null) return
    const hero = heroes.find((h) => h.id === characterId)
    const name = hero ? ROLE_NAMES[hero.role > 0 ? hero.role - 1 : characterId] : `Hero ${characterId}`
    pushInfo(`${name} claiming loot...`)
    const t = txToast('Claiming loot')
    try { await client.claim(account, gameId, characterId); t.success() } catch (e) { t.error(); pushInfo(`${name} claim failed`); console.error('Claim failed:', e) }
  }

  const handleCraft = async (ingredientA: number, ingredientB: number) => {
    if (!account || gameId == null) return
    pushInfo(`Brewing potion...`)
    const t = txToast('Brewing potion')
    try { await client.craft(account, gameId, ingredientA, ingredientB); t.success() } catch (e) { t.error(); pushInfo('Brew failed'); console.error('Craft failed:', e) }
  }

  const handleBrewAll = async () => {
    if (!account || gameId == null) return
    const pairs = computeUntriedPairs(inventory, recipes)
    if (pairs.length === 0) return
    pushInfo(`Brewing ${pairs.length} new combinations...`)
    const t = txToast(`Brewing ${pairs.length} potions`)
    try { await client.craftBatch(account, gameId, pairs); t.success() } catch (e) { t.error(); pushInfo('Batch brew failed'); console.error('Batch craft failed:', e) }
  }

  const handleClue = async () => {
    if (!account || gameId == null) return
    pushInfo('Buying hint...')
    const t = txToast('Buying hint')
    try { await client.clue(account, gameId); t.success() } catch (e) { t.error(); pushInfo('Hint purchase failed'); console.error('Clue failed:', e) }
  }

  const handleRecruit = async () => {
    if (!account || gameId == null) return
    pushInfo('Recruiting hero...')
    const t = txToast('Recruiting hero')
    try { await client.recruit(account, gameId); t.success() } catch (e) { t.error(); pushInfo('Recruitment failed'); console.error('Recruit failed:', e) }
  }

  const handleBuff = async (effect: number, heroId: number, quantity: number) => {
    if (!account || gameId == null) return
    pushInfo(`Applying potion to hero...`)
    const t = txToast('Applying potion')
    try { await client.buff(account, gameId, heroId, effect, quantity); t.success() } catch (e) { t.error(); pushInfo('Potion application failed'); console.error('Buff failed:', e) }
  }

  if (gameId == null) {
    return (
      <div className="page-center">
        <p>No game selected.</p>
        <button onClick={() => navigate('home')}>Back</button>
      </div>
    )
  }

  const gold = game?.gold ?? 0
  const discoveredCount = game ? bitmapPopcount(game.grimoire) : 0
  const brewAllCount = useMemo(() => computeUntriedPairs(inventory, recipes).length, [inventory, recipes])
  const effectQuantities = useMemo(() => game ? unpackEffects(BigInt(game.effects)) : Array(30).fill(0) as number[], [game])
  const heroCount = game ? bitmapPopcount(game.heroes) : heroes.length
  const isGameOver = game ? Number(game.ended_at) > 0 : false
  const hintCost = game?.hint_price ?? 4
  const startedAt = game ? Number(game.started_at) : now
  const elapsedSeconds = Math.max(0, now - startedAt)

  return (
    <div className="play-screen">
      <StatusHUD
        gold={gold}
        discoveredCount={discoveredCount}
        elapsedSeconds={elapsedSeconds}
        onBack={() => navigate('home')}
        onSettings={() => setSettingsOpen(true)}
      />

      <div className="play-left-panels">
        <div className="side-panel floating-panel panel-heroes">
          <button className="side-panel-header" onClick={() => setHeroesCollapsed((v) => !v)}>
            <span className="side-panel-title">Heroes</span>
            <span className="side-panel-chevron">{heroesCollapsed ? '▸' : '▾'}</span>
          </button>
          {!heroesCollapsed && (
            <div className="side-panel-body">
              {[0, 1, 2].map((slot) => (
                <HeroSlot
                  key={slot}
                  slot={slot}
                  heroes={heroes}
                  heroCount={heroCount}
                  selectedHeroId={selectedHeroId}
                  gold={gold}
                  isGameOver={isGameOver}
                  now={now}
                  onSelectHero={(id) => bridge.selectHero(id)}
                  onRecruit={() => void handleRecruit()}
                  onExplore={(id) => void handleExplore(id)}
                  onClaim={(id) => void handleClaim(id)}
                />
              ))}
            </div>
          )}
        </div>

        <div className="side-panel floating-panel panel-logs">
          <button className="side-panel-header" onClick={() => setLogsCollapsed((v) => !v)}>
            <span className="side-panel-title">Exploration Log</span>
            <span className="side-panel-chevron">{logsCollapsed ? '▸' : '▾'}</span>
          </button>
          {!logsCollapsed && (
            <div className="side-panel-body log-body">
              {logs.length === 0 ? (
                <span className="log-empty">No events yet...</span>
              ) : (
                logs.map((entry, i) => (
                  <div key={i} className={`log-entry log-${entry.kind}`}>
                    <span className="log-ts">{new Date(entry.ts).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit', second: '2-digit' })}</span>
                    <span className="log-text">{entry.text}</span>
                  </div>
                ))
              )}
              <div ref={logsEndRef} />
            </div>
          )}
        </div>
      </div>

      <div className="play-right-panels">
        <div className="side-panel floating-panel panel-brew">
          <button className="side-panel-header" onClick={() => setBrewCollapsed((v) => !v)}>
            <span className="side-panel-title">Brew</span>
            <span className="side-panel-chevron">{brewCollapsed ? '▸' : '▾'}</span>
          </button>
          {!brewCollapsed && (
            <div className="side-panel-body">
              <BrewContent
                slotA={slotA}
                slotB={slotB}
                recipes={recipes}
                remainingTries={game?.remaining_tries ?? 300}
                isGameOver={isGameOver}
                brewAllCount={brewAllCount}
                onSetSlotA={setSlotA}
                onSetSlotB={setSlotB}
                onCraft={(a, b) => void handleCraft(a, b)}
                onBrewAll={() => void handleBrewAll()}
              />
            </div>
          )}
        </div>

        <div className="side-panel floating-panel panel-collection">
          <div className="side-panel-header collection-header">
            <button
              className={`collection-tab${collectionTab === 'ingredients' ? ' active' : ''}`}
              onClick={() => setCollectionTab('ingredients')}
            >
              Ingredients
            </button>
            <button
              className={`collection-tab${collectionTab === 'grimoire' ? ' active' : ''}`}
              onClick={() => setCollectionTab('grimoire')}
            >
              Grimoire {discoveredCount}/30
            </button>
            <button
              className="side-panel-chevron collection-chevron"
              onClick={() => setCollectionCollapsed((v) => !v)}
            >
              {collectionCollapsed ? '▸' : '▾'}
            </button>
          </div>
          {!collectionCollapsed && (
            <div className="side-panel-body">
              {collectionTab === 'ingredients' ? (
                <IngredientsContent
                  inventory={inventory}
                  slotA={slotA}
                  slotB={slotB}
                  onPickIngredient={handlePickIngredient}
                />
              ) : (
                <GrimoireContent
                  grimoire={game?.grimoire ?? 0}
                  effectQuantities={effectQuantities}
                  recipes={recipes}
                  hintIngredients={hintIngredients}
                  discoveredCount={discoveredCount}
                  gold={gold}
                  hintCost={hintCost}
                  isGameOver={isGameOver}
                  heroes={heroes.map(h => ({ id: h.id, role: h.role }))}
                  inventory={inventory}
                  onBuyHint={() => void handleClue()}
                  onUsePotion={(eff, heroId, qty) => void handleBuff(eff, heroId, qty)}
                  onSelectIngredients={(a, b) => {
                    setSlotA(a)
                    setSlotB(b)
                    setBrewCollapsed(false)
                    requestAnimationFrame(() => {
                      document.querySelector('.panel-brew')?.scrollIntoView({ behavior: 'smooth', block: 'nearest' })
                    })
                  }}
                />
              )}
            </div>
          )}
        </div>
      </div>

      {isGameOver && (
        <div className="game-over-overlay">
          <div className={`game-over-card floating-panel ${discoveredCount >= 30 ? 'won' : 'lost'}`}>
            <h2>{discoveredCount >= 30 ? 'Grimoire Complete!' : 'Game Over'}</h2>
            <button onClick={() => navigate('home')} style={{ marginTop: '1rem' }}>
              Return to Menu
            </button>
          </div>
        </div>
      )}

      {settingsOpen && (
        <SettingsOverlay
          open={settingsOpen}
          onClose={() => setSettingsOpen(false)}
        />
      )}
    </div>
  )
}

interface HeroSlotProps {
  slot: number
  heroes: Array<{
    id: number
    role: number
    health: number
    max_health: number
    power: number
    regen: number
    available_at: number
    gold: number
    ingredients: bigint
  }>
  heroCount: number
  selectedHeroId: number
  gold: number
  isGameOver: boolean
  now: number
  onSelectHero: (heroId: number) => void
  onRecruit: () => void
  onExplore: (characterId: number) => void
  onClaim: (characterId: number) => void
}

function HeroSlot({
  slot,
  heroes,
  heroCount,
  selectedHeroId,
  gold,
  isGameOver,
  now,
  onSelectHero,
  onRecruit,
  onExplore,
  onClaim,
}: HeroSlotProps) {
  const hero = heroes.find((h) => h.id === slot)

  /* ── Recruit slot ─────────────────────────────── */
  if (!hero) {
    if (slot < heroCount) return null
    if (slot === heroCount && heroCount < 3) {
      const cost = HERO_RECRUIT_COSTS[Math.min(heroCount, 2)]
      const canAfford = gold >= cost && !isGameOver
      return (
        <div className="hero-card hero-card-locked">
          <div className="hero-card-locked-icon">+</div>
          <button
            className={`hero-card-recruit btn-primary${canAfford ? ' pulse-afford' : ''}`}
            onClick={onRecruit}
            disabled={!canAfford}
          >
            Recruit ({displayGold(cost)}g)
          </button>
        </div>
      )
    }
    return null
  }

  /* ── Active hero ──────────────────────────────── */
  const roleIdx = hero.role > 0 ? hero.role - 1 : slot
  const roleName = ROLE_NAMES[roleIdx] ?? `Hero ${slot}`
  const availableAt = Number(hero.available_at)
  const remaining = Math.max(0, availableAt - now)
  const isIdle = remaining === 0
  const isExploring = remaining > 0
  const lootReady = isIdle && (hero.gold > 0 || (hero.ingredients != null && hero.ingredients !== 0n))

  let statusText = 'Ready'
  let statusClass = ''
  if (isExploring) { statusText = `Exploring ${remaining}s`; statusClass = 'exploring' }

  /* ── Optimistic HP regen ──────────────────────── */
  const healthRef = useRef({ health: hero.health, ts: now })
  if (hero.health !== healthRef.current.health) {
    healthRef.current = { health: hero.health, ts: now }
  }
  const elapsedSinceUpdate = now - healthRef.current.ts
  const optimisticHp = isIdle
    ? Math.min(hero.health + hero.regen * elapsedSinceUpdate, hero.max_health)
    : hero.health

  const hpPct = hero.max_health > 0 ? Math.min(100, (optimisticHp / hero.max_health) * 100) : 0
  const regenPreviewPct = (isIdle && optimisticHp < hero.max_health && hero.regen > 0)
    ? Math.min(100 - hpPct, (hero.regen / hero.max_health) * 100)
    : 0
  const hpColor = hpPct > 50 ? 'var(--accent-green)' : hpPct > 25 ? '#ff9800' : 'var(--accent-red)'

  /* ── Power bar ────────────────────────────────── */
  const powerCap = Math.max(hero.power, 50)
  const powerPct = powerCap > 0 ? Math.min(100, (hero.power / powerCap) * 100) : 0

  const displayHpVal = Math.floor(optimisticHp)

  return (
    <div
      className={`hero-card${selectedHeroId === hero.id ? ' selected' : ''}`}
      onClick={() => onSelectHero(hero.id)}
    >
      <div className="hero-card-name-row">
        <span className="hero-card-name">{roleName}</span>
        {isIdle && (
          <button
            className="btn-primary btn-sm"
            onClick={(e) => { e.stopPropagation(); onExplore(hero.id) }}
            disabled={isGameOver}
          >
            Send Expedition
          </button>
        )}
        {lootReady && (
          <button
            className="btn-primary btn-sm btn-loot"
            onClick={(e) => { e.stopPropagation(); onClaim(hero.id) }}
            disabled={isGameOver}
          >
            Claim Loot
          </button>
        )}
      </div>
      <div className="hero-card-top">
        <img
          className="hero-card-portrait"
          src={roleAssetUrl(roleIdx)}
          alt={roleName}
        />
        <div className="hero-card-info">
          {hero.regen > 0 && (
            <span className="hero-card-regen-tag">HP Regen: +{hero.regen} HP/s</span>
          )}
          <div className="hero-card-hp">
            <div className="hero-card-hp-fill" style={{ width: `${hpPct}%`, background: hpColor }} />
            {regenPreviewPct > 0 && (
              <div
                className="hero-card-hp-regen"
                style={{ left: `${hpPct}%`, width: `${regenPreviewPct}%`, background: hpColor }}
              />
            )}
            <span className="hero-card-bar-label">HP {displayHp(displayHpVal)}/{displayHp(hero.max_health)}</span>
          </div>
          <div className="hero-card-power">
            <div className="hero-card-power-fill" style={{ width: `${powerPct}%` }} />
            <span className="hero-card-bar-label">Power {hero.power}</span>
          </div>
          <span className={`hero-card-status ${statusClass}`}>{statusText}</span>
        </div>
      </div>
    </div>
  )
}
