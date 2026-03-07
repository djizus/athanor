import { useCallback, useEffect, useMemo, useRef, useState } from 'react'
import { useAccount } from '@starknet-react/core'
import { useDojo } from '@/dojo/useDojo'
import { useGame } from '@/hooks/useGame'
import { useHeroes } from '@/hooks/useHeroes'
import { useInventory } from '@/hooks/useInventory'
import { useRecipes } from '@/hooks/useRecipes'
import { useHints } from '@/hooks/useHints'
import { useExplorationLog } from '@/hooks/useExplorationLog'
import type { RawExplorationEvent, HeroOverride } from '@/hooks/useExplorationLog'
import { useExpeditionTracker } from '@/hooks/useExpeditionTracker'
import type { HeroPosition } from '@/hooks/useExpeditionTracker'
import { useNavigationStore } from '@/stores/navigationStore'
import { txToast } from '@/stores/toastStore'
import { soundManager } from '@/sound/SoundManager'
import { JourneyMap } from '@/ui/components/JourneyMap'
import type { FloatingTextAnim } from '@/ui/components/JourneyMap'
import {
  EFFECT_CATEGORIES,
  EFFECT_COLORS,
  HERO_RECRUIT_COSTS,
  ROLE_NAMES,
  displayGold,
  displayHp,
  effectAssetUrl,
  effectStatLabel,
  roleAssetUrl,
} from '@/game/constants'
import { bitmapGet, bitmapPopcount, unpackEffects } from '@/game/packer'
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

export function PlayScreen() {
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
  const [logsCollapsed, setLogsCollapsed] = useState(false)
  const [potionTargetHeroId, setPotionTargetHeroId] = useState<number | null>(null)
  const [mobilePanel, setMobilePanel] = useState<string | null>(null)

  const [floatingTexts, setFloatingTexts] = useState<FloatingTextAnim[]>([])
  const floatingIdRef = useRef(0)

  const { heroPositions, onExpeditionStart, onExplorationZoneUpdate } = useExpeditionTracker(heroes, now)

  const addFloatingText = useCallback((heroId: number, text: string, color: string, zoneId?: number) => {
    const id = String(floatingIdRef.current++)
    setFloatingTexts(prev => [...prev, { id, heroId, text, color, zoneId }])
  }, [])

  const removeFloatingText = useCallback((id: string) => {
    setFloatingTexts(prev => prev.filter(ft => ft.id !== id))
  }, [])

  const onExplorationEvent = useCallback((event: RawExplorationEvent) => {
    if (event.zoneId != null) {
      onExplorationZoneUpdate(event.heroId, event.zoneId)
    }

    const zone = event.zoneId

    switch (event.kind) {
      case 'trap':
        soundManager.playSfx('trap', 0.5)
        addFloatingText(event.heroId, `-${event.value} HP`, '#d04050', zone)
        break
      case 'gold':
        soundManager.playSfx('gold-find', 0.5)
        addFloatingText(event.heroId, `+${event.value}g`, '#f0c040', zone)
        break
      case 'heal':
        soundManager.playSfx('heal', 0.5)
        addFloatingText(event.heroId, `+${event.value} HP`, '#40c060', zone)
        break
      case 'beastWin':
        soundManager.playSfx('beast-win', 0.5)
        addFloatingText(event.heroId, `+${event.value}g`, '#f0c040', zone)
        break
      case 'beastLose':
        soundManager.playSfx('beast-lose', 0.5)
        addFloatingText(event.heroId, `-${event.value} HP`, '#d04050', zone)
        break
      case 'ingredient':
        soundManager.playSfx('gold-find', 0.3)
        addFloatingText(event.heroId, '+1 Ingredient', '#a050d0', zone)
        break
    }
  }, [addFloatingText, onExplorationZoneUpdate])

  const { logs, pushInfo, heroOverrides } = useExplorationLog(gameId ?? null, heroes, onExplorationEvent)
  const logsEndRef = useRef<HTMLDivElement>(null)

  useEffect(() => {
    const timer = window.setInterval(() => setNow(Math.floor(Date.now() / 1000)), 1000)
    return () => window.clearInterval(timer)
  }, [])

  const prevDiscoveredRef = useRef(0)
  const prevGameOverRef = useRef(false)
  const discoveredCount = game ? bitmapPopcount(game.grimoire) : 0
  const isGameOver = game ? Number(game.ended_at) > 0 : false

  useEffect(() => {
    if (discoveredCount > prevDiscoveredRef.current && prevDiscoveredRef.current > 0) {
      soundManager.playSfx('discovery', 0.6)
    }
    prevDiscoveredRef.current = discoveredCount
  }, [discoveredCount])

  useEffect(() => {
    if (isGameOver && !prevGameOverRef.current) {
      soundManager.playSfx('victory', 0.7)
    }
    prevGameOverRef.current = isGameOver
  }, [isGameOver])

  const scrollPanelIntoView = useCallback((panelClass: string, collapseSetter: React.Dispatch<React.SetStateAction<boolean>>) => {
    collapseSetter(false)
    requestAnimationFrame(() => {
      const el = document.querySelector(`.${panelClass}`)
      el?.scrollIntoView({ behavior: 'smooth', block: 'nearest' })
    })
  }, [])

  const handlePickIngredient = useCallback((id: number) => {
    soundManager.playSfx('click', 0.25)
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
        case 'g': { setCollectionTab('grimoire'); scrollPanelIntoView('panel-brew', setBrewCollapsed); break }
        case 'i': { setCollectionTab('ingredients'); scrollPanelIntoView('panel-brew', setBrewCollapsed); break }
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
    onExpeditionStart(characterId)
    soundManager.playSfx('expedition-start', 0.5)
    const t = txToast('Sending expedition')
    try { await client.explore(account, gameId, characterId); t.success() } catch (e) { t.error(); pushInfo(`${name} expedition failed`); console.error('Explore failed:', e) }
  }

  const handleClaim = async (characterId: number) => {
    if (!account || gameId == null) return
    const hero = heroes.find((h) => h.id === characterId)
    const name = hero ? ROLE_NAMES[hero.role > 0 ? hero.role - 1 : characterId] : `Hero ${characterId}`
    pushInfo(`${name} claiming loot...`)
    soundManager.playSfx('claim-loot', 0.5)
    if (hero && hero.gold > 0) {
      addFloatingText(characterId, `+${hero.gold}g`, '#f0c040')
    }
    const t = txToast('Claiming loot')
    try { await client.claim(account, gameId, characterId); t.success() } catch (e) { t.error(); pushInfo(`${name} claim failed`); console.error('Claim failed:', e) }
  }

  const handleCraft = async (ingredientA: number, ingredientB: number) => {
    if (!account || gameId == null) return
    pushInfo(`Brewing potion...`)
    const lo = Math.min(ingredientA, ingredientB)
    const hi = Math.max(ingredientA, ingredientB)
    const existingRecipe = recipes.find(
      (r) => r.discovered && Math.min(r.ingredient_a, r.ingredient_b) === lo && Math.max(r.ingredient_a, r.ingredient_b) === hi,
    )
    const isSoup = existingRecipe != null && EFFECT_CATEGORIES[existingRecipe.effect] === undefined
    const t = txToast('Brewing potion')
    try {
      await client.craft(account, gameId, lo, hi)
      t.success()
      soundManager.playSfx('brew-success', 0.4)
      if (isSoup) {
        addFloatingText(0, '+1g', '#f0c040')
      }
    } catch (e) { t.error(); pushInfo('Brew failed'); console.error('Craft failed:', e) }
  }

  const handleBrewAll = async () => {
    if (!account || gameId == null) return
    const pairs = computeUntriedPairs(inventory, recipes)
    if (pairs.length === 0) return
    pushInfo(`Brewing ${pairs.length} new combinations...`)
    const t = txToast(`Brewing ${pairs.length} potions`)
    try {
      await client.craftBatch(account, gameId, pairs)
      t.success()
      soundManager.playSfx('brew-success', 0.4)
    } catch (e) { t.error(); pushInfo('Batch brew failed'); console.error('Batch craft failed:', e) }
  }

  const handleClue = async () => {
    if (!account || gameId == null) return
    pushInfo('Buying hint...')
    const t = txToast('Buying hint')
    try { await client.clue(account, gameId); t.success(); soundManager.playSfx('notification', 0.4) } catch (e) { t.error(); pushInfo('Hint purchase failed'); console.error('Clue failed:', e) }
  }

  const handleRecruit = async () => {
    if (!account || gameId == null) return
    pushInfo('Recruiting hero...')
    const t = txToast('Recruiting hero')
    try { await client.recruit(account, gameId); t.success(); soundManager.playSfx('recruit', 0.6) } catch (e) { t.error(); pushInfo('Recruitment failed'); console.error('Recruit failed:', e) }
  }

  const handleBuff = async (effect: number, heroId: number, quantity: number) => {
    if (!account || gameId == null) return
    pushInfo(`Applying potion to hero...`)
    const t = txToast('Applying potion')
    try { await client.buff(account, gameId, heroId, effect, quantity); t.success(); soundManager.playSfx('potion-apply', 0.5) } catch (e) { t.error(); pushInfo('Potion application failed'); console.error('Buff failed:', e) }
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
  const brewAllCount = useMemo(() => computeUntriedPairs(inventory, recipes).length, [inventory, recipes])
  const effectQuantities = useMemo(() => game ? unpackEffects(BigInt(game.effects)) : Array(30).fill(0) as number[], [game])
  const hasPotions = effectQuantities.some((q) => q > 0)
  const heroCount = game ? bitmapPopcount(game.heroes) : heroes.length
  const hintCost = game?.hint_price ?? 4
  const startedAt = game ? Number(game.started_at) : now
  const elapsedSeconds = Math.max(0, now - startedAt)

  const journeyHeroes = useMemo(() =>
    heroes.map(h => {
      const override = heroOverrides.get(h.id)
      return {
        hero_id: h.id,
        role: h.role,
        health: override ? override.health : h.health,
        max_health: h.max_health,
      }
    }),
    [heroes, heroOverrides],
  )

  return (
    <div className="play-screen">
      <JourneyMap
        heroes={journeyHeroes}
        heroPositions={heroPositions}
        floatingTexts={floatingTexts}
        onFloatingTextComplete={removeFloatingText}
      />

      <StatusHUD
        gold={gold}
        discoveredCount={discoveredCount}
        elapsedSeconds={elapsedSeconds}
        onBack={() => navigate('home')}
        onSettings={() => setSettingsOpen(true)}
      />

      <div className={`play-left-panels${mobilePanel && mobilePanel !== 'heroes' && mobilePanel !== 'logs' ? ' mobile-hidden' : ''}${mobilePanel === 'heroes' || mobilePanel === 'logs' ? ' mobile-open' : ''}`}>
        <div className={`side-panel floating-panel panel-heroes${mobilePanel === 'logs' ? ' mobile-panel-hidden' : ''}`}>

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
                  heroOverrides={heroOverrides}
                  heroPositions={heroPositions}
                  onSelectHero={(id) => setSelectedHeroId(id)}
                  onRecruit={() => void handleRecruit()}
                  onExplore={(id) => void handleExplore(id)}
                  onClaim={(id) => void handleClaim(id)}
                  hasPotions={hasPotions}
                  onApplyPotion={(id) => setPotionTargetHeroId(id)}
                />
              ))}
            </div>
          )}
        </div>

        <div className={`side-panel floating-panel panel-logs${mobilePanel === 'heroes' ? ' mobile-panel-hidden' : ''}`}>
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

      <div className={`play-right-panels${mobilePanel && mobilePanel !== 'brew' ? ' mobile-hidden' : ''}${mobilePanel === 'brew' ? ' mobile-open' : ''}`}>
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
                inventory={inventory}
                recipes={recipes}
                isGameOver={isGameOver}
                onSetSlotA={setSlotA}
                onSetSlotB={setSlotB}
                onCraft={(a, b) => void handleCraft(a, b)}
              />

              <div className="craft-btn-row">
                <button onClick={() => void handleBrewAll()} disabled={isGameOver || brewAllCount === 0}>
                  Brew All ({brewAllCount})
                </button>
              </div>

              <div className="collection-tabs">
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
              </div>

              {collectionTab === 'ingredients' ? (
                <IngredientsContent
                  inventory={inventory}
                  slotA={slotA}
                  slotB={slotB}
                  remainingTries={game?.remaining_tries ?? 300}
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
                  inventory={inventory}
                  onBuyHint={() => void handleClue()}
                  onSelectIngredients={(a, b) => {
                    console.log('[PlayScreen] onSelectIngredients called', { a, b })
                    setSlotA(a >= 0 ? a : null)
                    setSlotB(b >= 0 ? b : null)
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
          onSurrender={async () => {
            if (!account || gameId == null) return
            try {
              await client.surrender(account, gameId)
              setSettingsOpen(false)
              navigate('home')
            } catch (e) {
              console.error('Surrender failed:', e)
            }
          }}
        />
      )}

      <div className="mobile-tab-bar">
        {(['heroes', 'brew', 'logs'] as const).map(tab => (
          <button
            key={tab}
            className={`mobile-tab${mobilePanel === tab ? ' active' : ''}`}
            onClick={() => setMobilePanel(prev => prev === tab ? null : tab)}
          >
            {tab === 'heroes' ? '⚔' : tab === 'brew' ? '⚗' : '📜'}
            <span>{tab.charAt(0).toUpperCase() + tab.slice(1)}</span>
          </button>
        ))}
      </div>

      {potionTargetHeroId !== null && (
        <HeroPotionPopup
          heroId={potionTargetHeroId}
          heroes={heroes}
          grimoire={game?.grimoire ?? 0}
          effectQuantities={effectQuantities}
          onApply={async (selections) => {
            for (const { effect, quantity } of selections) {
              await handleBuff(effect, potionTargetHeroId, quantity)
            }
            setPotionTargetHeroId(null)
          }}
          onClose={() => setPotionTargetHeroId(null)}
        />
      )}
    </div>
  )
}

function HeroPotionPopup({
  heroId,
  heroes,
  grimoire,
  effectQuantities,
  onApply,
  onClose,
}: {
  heroId: number
  heroes: Array<{ id: number; role: number }>
  grimoire: number
  effectQuantities: number[]
  onApply: (selections: { effect: number; quantity: number }[]) => void
  onClose: () => void
}) {
  const [selected, setSelected] = useState<Map<number, number>>(() => new Map())

  const hero = heroes.find((h) => h.id === heroId)
  const roleIdx = hero ? (hero.role > 0 ? hero.role - 1 : heroId) : 0
  const heroName = ROLE_NAMES[roleIdx] ?? `Hero ${heroId}`

  const availablePotions = useMemo(() => {
    const result: { effectIdx: number; qty: number }[] = []
    for (let i = 0; i < 30; i++) {
      if (bitmapGet(grimoire, i + 1) && effectQuantities[i] > 0) {
        result.push({ effectIdx: i, qty: effectQuantities[i] })
      }
    }
    return result
  }, [grimoire, effectQuantities])

  const togglePotion = (idx: number, delta: number) => {
    setSelected(prev => {
      const next = new Map(prev)
      const cur = next.get(idx) ?? 0
      const max = effectQuantities[idx]
      const val = Math.max(0, Math.min(max, cur + delta))
      if (val === 0) next.delete(idx)
      else next.set(idx, val)
      return next
    })
  }

  const totalSelected = Array.from(selected.values()).reduce((a, b) => a + b, 0)

  const handleSelectAll = () => {
    const next = new Map<number, number>()
    for (const { effectIdx, qty } of availablePotions) {
      next.set(effectIdx, qty)
    }
    setSelected(next)
  }

  const handleMaxPotion = (idx: number) => {
    setSelected(prev => {
      const next = new Map(prev)
      next.set(idx, effectQuantities[idx])
      return next
    })
  }

  return (
    <div className="potion-popup-backdrop" onClick={onClose}>
      <div className="potion-popup floating-panel" onClick={(e) => e.stopPropagation()}>
        <div className="potion-popup-header">
          <span className="potion-popup-name">Apply Potions to {heroName}</span>
          {availablePotions.length > 0 && (
            <button className="btn-sm" onClick={handleSelectAll}>Select All</button>
          )}
        </div>
        {availablePotions.length === 0 ? (
          <p style={{ color: 'var(--text-muted)', fontStyle: 'italic', fontSize: '0.8rem' }}>No potions available</p>
        ) : (
          <>
            <div className="potion-popup-grid">
              {availablePotions.map(({ effectIdx, qty }) => {
                const category = EFFECT_CATEGORIES[effectIdx]
                const color = EFFECT_COLORS[category]
                const count = selected.get(effectIdx) ?? 0
                const isActive = count > 0
                return (
                  <div
                    key={effectIdx}
                    className={`grimoire-cell${isActive ? ' discovered' : ''} grimoire-cell-clickable`}
                    style={{ ['--effect-color' as string]: color }}
                    onClick={() => togglePotion(effectIdx, count > 0 ? -count : 1)}
                  >
                    <div
                      className="grimoire-icon-wrap"
                      style={{ ['--effect-color' as string]: color }}
                    >
                      <img
                        className="grimoire-icon"
                        src={effectAssetUrl(effectIdx)}
                        alt={effectStatLabel(effectIdx)}
                      />
                      <span className="grimoire-badge-tr">{effectStatLabel(effectIdx)}</span>
                      <span className={`craft-slot-qty${qty <= 0 ? ' craft-slot-qty-zero' : ''}`}>{qty}</span>
                    </div>
                    <div className="potion-popup-cell-qty" onClick={(e) => e.stopPropagation()}>
                      <button onClick={() => togglePotion(effectIdx, -1)} disabled={count <= 0}>&minus;</button>
                      <span>{count}</span>
                      <button onClick={() => togglePotion(effectIdx, 1)} disabled={count >= qty}>+</button>
                      <button className="btn-max" onClick={() => handleMaxPotion(effectIdx)} disabled={count >= qty}>Max</button>
                    </div>
                  </div>
                )
              })}
            </div>
            <div className="potion-popup-actions">
              <button
                className="btn-primary"
                onClick={() => {
                  if (selected.size === 0) return
                  onApply(Array.from(selected.entries()).map(([effect, quantity]) => ({ effect, quantity })))
                }}
                disabled={totalSelected === 0}
              >
                Apply {totalSelected > 0 ? `${totalSelected} to ${heroName}` : ''}
              </button>
              <button onClick={onClose}>Cancel</button>
            </div>
          </>
        )}
      </div>
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
  heroOverrides: Map<number, HeroOverride>
  heroPositions: Map<number, HeroPosition>
  onSelectHero: (heroId: number) => void
  onRecruit: () => void
  onExplore: (characterId: number) => void
  onClaim: (characterId: number) => void
  hasPotions: boolean
  onApplyPotion: (heroId: number) => void
}

function HeroSlot({
  slot,
  heroes,
  heroCount,
  selectedHeroId,
  gold,
  isGameOver,
  now,
  heroOverrides,
  heroPositions,
  onSelectHero,
  onRecruit,
  onExplore,
  onClaim,
  hasPotions,
  onApplyPotion,
}: HeroSlotProps) {
  const hero = heroes.find((h) => h.id === slot)

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

  const roleIdx = hero.role > 0 ? hero.role - 1 : slot
  const roleName = ROLE_NAMES[roleIdx] ?? `Hero ${slot}`
  const availableAt = Number(hero.available_at)
  const remaining = Math.max(0, availableAt - now)
  const isIdle = remaining === 0
  const isExploring = remaining > 0
  const lootReady = isIdle && (hero.gold > 0 || (hero.ingredients != null && hero.ingredients !== 0n))

  const heroPos = heroPositions.get(hero.id)
  const isReturning = isExploring && heroPos?.returning === true

  let statusText = 'Ready'
  let statusClass = ''
  if (isReturning) { statusText = `Returning ${remaining}s`; statusClass = 'returning' }
  else if (isExploring) { statusText = `Exploring ${remaining}s`; statusClass = 'exploring' }
  else if (lootReady) { statusText = 'Loot Ready'; statusClass = 'loot-ready' }

  const override = heroOverrides.get(hero.id)
  const regenElapsed = isIdle ? Math.max(0, now - availableAt) : 0
  const baseHp = override ? override.health : hero.health
  const optimisticHp = override
    ? baseHp
    : Math.min(baseHp + hero.regen * regenElapsed, hero.max_health)

  const hpPct = hero.max_health > 0 ? Math.min(100, (optimisticHp / hero.max_health) * 100) : 0
  const regenPreviewPct = (isIdle && optimisticHp < hero.max_health && hero.regen > 0)
    ? Math.min(100 - hpPct, (hero.regen / hero.max_health) * 100)
    : 0
  const hpColor = hpPct > 50 ? 'var(--accent-green)' : hpPct > 25 ? '#ff9800' : 'var(--accent-red)'

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
        <span className={`hero-card-status ${statusClass}`}>{statusText}</span>
      </div>
      <div className="hero-card-top">
        <img
          className="hero-card-portrait"
          src={roleAssetUrl(roleIdx)}
          alt={roleName}
        />
        <div className="hero-card-info">
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
          {hero.regen > 0 && (
            <span className="hero-card-regen">Regen +{hero.regen} HP/s</span>
          )}
        </div>
      </div>
      <div className="hero-card-btn-row">
        <button
          className="btn-primary btn-sm"
          onClick={(e) => { e.stopPropagation(); onExplore(hero.id) }}
          disabled={isGameOver || isExploring || displayHpVal <= 0}
        >
          Explore
        </button>
        <button
          className="btn-primary btn-sm btn-loot"
          onClick={(e) => { e.stopPropagation(); onClaim(hero.id) }}
          disabled={isGameOver || !lootReady}
        >
          Claim
        </button>
        <button
          className="btn-sm btn-potion"
          onClick={(e) => { e.stopPropagation(); onApplyPotion(hero.id) }}
          disabled={isGameOver || !hasPotions}
        >
          Apply Potion
        </button>
      </div>
    </div>
  )
}
