import { useCallback, useEffect, useMemo, useRef, useState } from 'react'
import { useAccount } from '@starknet-react/core'
import { Has, getComponentValue } from '@dojoengine/recs'
import { useEntityQuery } from '@dojoengine/react'
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
import { usePendingTxStore } from '@/stores/pendingTxStore'
import { txToast } from '@/stores/toastStore'
import { soundManager } from '@/sound/SoundManager'
import { JourneyMap } from '@/ui/components/JourneyMap'
import type { FloatingTextAnim } from '@/ui/components/JourneyMap'
import {
  EFFECT_CATEGORIES,
  EFFECT_COLORS,
  HERO_RECRUIT_COSTS,
  ROLE_NAMES,
  ZONE_NAMES,
  displayGold,
  displayHp,
  effectAssetUrl,
  effectStatLabel,
  ingredientAssetUrl,
  roleAssetUrl,
} from '@/game/constants'
import { bitmapGet, bitmapPopcount, unpackCharacterIngredients, unpackEffects } from '@/game/packer'
import type { DiscoveryData } from '@/hooks/useRecipes'
import { StatusHUD } from '@/ui/components/StatusHUD'
import { BrewContent, IngredientsContent, GrimoireContent } from '@/ui/components/RightPanel'
import type { PanelMode } from '@/ui/components/RightPanel'
import { SettingsOverlay } from '@/ui/components/SettingsOverlay'

function computeOptimisticHp(
  hero: { health: number; max_health: number; regen: number; available_at: number },
  now: number,
  override: { health: number } | undefined,
): number {
  if (override) return override.health
  const availableAt = Number(hero.available_at)
  const isIdle = availableAt <= now
  const regenElapsed = isIdle ? Math.max(0, now - availableAt) : 0
  return Math.min(hero.health + hero.regen * regenElapsed, hero.max_health)
}

function formatGameDuration(seconds: number): string {
  if (seconds <= 0) return '-'
  const h = Math.floor(seconds / 3600)
  const m = Math.floor((seconds % 3600) / 60)
  const s = seconds % 60
  if (h > 0) return `${h}h ${m}m ${s}s`
  return `${m}m ${s}s`
}

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

function computeUntriedPairsForFirstIngredient(
  inventory: { ingredient_id: number; quantity: number }[],
  recipes: DiscoveryData[],
  firstIngredient: number,
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

  const firstQty = inv.get(firstIngredient) ?? 0
  if (firstQty <= 0) return []

  const ids = [...inv.keys()].filter(id => id !== firstIngredient).sort((a, b) => a - b)
  const pairs: [number, number][] = []
  let remainingFirst = firstQty

  for (const id of ids) {
    if (remainingFirst <= 0) break
    if (tried.has(`${firstIngredient}-${id}`)) continue
    const q = inv.get(id) ?? 0
    if (q <= 0) continue
    const lo = Math.min(firstIngredient, id)
    const hi = Math.max(firstIngredient, id)
    pairs.push([lo, hi])
    remainingFirst -= 1
    inv.set(id, q - 1)
  }

  return pairs
}

const NAMESPACE = import.meta.env.VITE_PUBLIC_NAMESPACE || 'ATHANOR'
const DISCOVERY_MODEL = `${NAMESPACE}-Discovery`

function createPendingTxId() {
  return `pending-${Date.now()}-${Math.random()}`
}

async function fetchFreshRecipes(
  toriiClient: ReturnType<typeof useDojo>['toriiClient'],
  gameId: number,
): Promise<DiscoveryData[]> {
  const result = await toriiClient.getEntities({
    world_addresses: [],
    pagination: { limit: 500, cursor: undefined, direction: 'Forward', order_by: [] },
    clause: { Keys: { keys: ['0x' + gameId.toString(16)], pattern_matching: 'VariableLen', models: [DISCOVERY_MODEL] } },
    no_hashed_keys: false,
    models: [DISCOVERY_MODEL],
    historical: false,
  })
  return result.items
    .map(e => e.models[DISCOVERY_MODEL])
    .filter(Boolean)
    .map(m => ({
      ingredient_a: Number((m.ingredient_a as { value: unknown }).value) - 1,
      ingredient_b: Number((m.ingredient_b as { value: unknown }).value) - 1,
      effect: Number((m.effect as { value: unknown }).value) - 1,
      discovered: Boolean((m.discovered as { value: unknown }).value),
    }))
}

export function PlayScreen() {
  const { client, toriiClient, contractComponents } = useDojo()
  const { gameId, navigate } = useNavigationStore()
  const { account } = useAccount()
  const { game } = useGame(gameId)
  const heroes = useHeroes(gameId)
  const inventory = useInventory(gameId)
  const recipes = useRecipes(gameId)
  const hintIngredients = useHints(gameId)
  const effectQuantities = useMemo(
    () => (game ? unpackEffects(BigInt(game.effects)) : Array(30).fill(0) as number[]),
    [game],
  )
  const addPendingTx = usePendingTxStore((s) => s.addTx)
  const finalizePendingTx = usePendingTxStore((s) => s.finalizeTx)
  const notifySyncTick = usePendingTxStore((s) => s.notifySyncTick)
  const isActionPending = usePendingTxStore((s) => s.isActionPending)
  const isHeroActionPending = usePendingTxStore((s) => s.isHeroActionPending)

  const [selectedHeroId, setSelectedHeroId] = useState(0)
  const [settingsOpen, setSettingsOpen] = useState(false)
  const [now, setNow] = useState(() => Math.floor(Date.now() / 1000))
  const [slotA, setSlotA] = useState<number | null>(null)
  const [slotB, setSlotB] = useState<number | null>(null)
  const [collectionTab, setCollectionTab] = useState<PanelMode>('ingredients')

  const [heroesCollapsed, setHeroesCollapsed] = useState(false)
  const [brewCollapsed, setBrewCollapsed] = useState(false)
  const [logsCollapsed, setLogsCollapsed] = useState(true)
  const [potionTargetHeroId, setPotionTargetHeroId] = useState<number | null>(null)
  const [mobilePanel, setMobilePanel] = useState<string | null>(null)
  const [surrendered, setSurrendered] = useState(false)
  const [brewAllCount, setBrewAllCount] = useState(0)
  const [brewRefreshKey, setBrewRefreshKey] = useState(0)

  const [floatingTexts, setFloatingTexts] = useState<FloatingTextAnim[]>([])
  const [goldFloats, setGoldFloats] = useState<{ id: string; text: string }[]>([])
  const floatingIdRef = useRef(0)
  const lastSyncFingerprintRef = useRef<string | null>(null)

  const { heroPositions, onExpeditionStart, onExplorationZoneUpdate } = useExpeditionTracker(heroes, now)

  const addFloatingText = useCallback((heroId: number, text: string, color: string, zoneId?: number, icon?: string) => {
    const id = String(floatingIdRef.current++)
    setFloatingTexts(prev => [...prev, { id, heroId, text, color, zoneId, icon }])
  }, [])

  const removeFloatingText = useCallback((id: string) => {
    setFloatingTexts(prev => prev.filter(ft => ft.id !== id))
  }, [])

  const addGoldFloat = useCallback((text: string) => {
    const id = String(floatingIdRef.current++)
    setGoldFloats(prev => [...prev, { id, text }])
    setTimeout(() => setGoldFloats(prev => prev.filter(f => f.id !== id)), 1200)
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
        addFloatingText(event.heroId, '+1', '#a050d0', zone, ingredientAssetUrl(event.value))
        break
    }
  }, [addFloatingText, onExplorationZoneUpdate])

  const { logs, pushInfo, heroOverrides } = useExplorationLog(gameId ?? null, heroes, onExplorationEvent)
  const logsEndRef = useRef<HTMLDivElement>(null)

  const syncFingerprint = useMemo(() => {
    const gamePart = game
      ? [
        game.id,
        game.gold,
        String(game.effects),
        game.remaining_tries,
        game.grimoire,
        game.heroes,
        game.hint_price,
        game.started_at,
        game.ended_at,
      ].join(':')
      : 'no-game'
    const inventoryPart = inventory
      .map(item => `${item.ingredient_id}:${item.quantity}`)
      .join('|')
    const heroesPart = heroes
      .map(hero => `${hero.id}:${hero.health}:${hero.max_health}:${hero.available_at}:${hero.gold}:${hero.ingredients}`)
      .join('|')
    return `${gamePart}#${inventoryPart}#${heroesPart}`
  }, [game, inventory, heroes])

  useEffect(() => {
    const timer = window.setInterval(() => setNow(Math.floor(Date.now() / 1000)), 1000)
    return () => window.clearInterval(timer)
  }, [])

  useEffect(() => {
    const prev = lastSyncFingerprintRef.current
    if (prev !== null && prev !== syncFingerprint) {
      notifySyncTick()
    }
    lastSyncFingerprintRef.current = syncFingerprint
  }, [syncFingerprint, notifySyncTick])

  const prevDiscoveredRef = useRef(0)
  const prevGameOverRef = useRef(false)
  const prevGrimoireRef = useRef(0)
  const [newlyDiscoveredEffects, setNewlyDiscoveredEffects] = useState<Set<number>>(new Set())
  const discoveredCount = game ? bitmapPopcount(game.grimoire) : 0
  const isGameOver = game ? Number(game.ended_at) > 0 : false

  useEffect(() => {
    if (discoveredCount > prevDiscoveredRef.current && prevDiscoveredRef.current > 0) {
      soundManager.playSfx('discovery', 0.6)
    }
    prevDiscoveredRef.current = discoveredCount
  }, [discoveredCount])

  useEffect(() => {
    const current = game?.grimoire ?? 0
    const prev = prevGrimoireRef.current
    if (prev > 0 && current !== prev) {
      const found = new Set<number>()
      for (let i = 0; i < 30; i++) {
        if (bitmapGet(current, i) && !bitmapGet(prev, i)) found.add(i)
      }
      if (found.size > 0) {
        setNewlyDiscoveredEffects(found)
        setTimeout(() => setNewlyDiscoveredEffects(new Set()), 2000)
      }
    }
    prevGrimoireRef.current = current
  }, [game?.grimoire])

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
    else { setSlotB(id) }
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

  useEffect(() => {
    if (gameId == null) return
    let stale = false
    fetchFreshRecipes(toriiClient, gameId)
      .then((fresh) => {
        if (stale) return
        const selectedIngredient = slotA ?? slotB
        const selectedCount = Number(slotA != null) + Number(slotB != null)
        if (selectedCount >= 2) {
          setBrewAllCount(0)
          return
        }
        if (selectedCount === 1 && selectedIngredient != null) {
          setBrewAllCount(computeUntriedPairsForFirstIngredient(inventory, fresh, selectedIngredient).length)
          return
        }
        setBrewAllCount(computeUntriedPairs(inventory, fresh).length)
      })
      .catch(() => {})
    return () => { stale = true }
  }, [toriiClient, gameId, inventory, recipes, brewRefreshKey, slotA, slotB])

  const handleExplore = async (characterId: number, zoneId: number) => {
    if (!account || gameId == null) return
    const hero = heroes.find((h) => h.id === characterId)
    const name = hero ? ROLE_NAMES[hero.role > 0 ? hero.role - 1 : characterId] : `Hero ${characterId}`
    pushInfo(`${name} sent to ${ZONE_NAMES[zoneId] ?? `Zone ${zoneId}`}...`)
    onExpeditionStart(characterId, zoneId)
    soundManager.playSfx('expedition-start', 0.5)
    const pendingId = createPendingTxId()
    addPendingTx({
      id: pendingId,
      action: 'explore',
      heroId: characterId,
      inventoryDelta: new Map(),
      goldDelta: 0,
      effectsDelta: new Map(),
    })
    const t = txToast('Sending expedition')
    let success = false
    try {
      await client.explore(account, gameId, characterId, zoneId)
      success = true
      t.success()
    } catch (e) {
      t.error()
      pushInfo(`${name} expedition failed`)
      console.error('Explore failed:', e)
    } finally {
      finalizePendingTx(pendingId, success)
    }
  }

  const handleClaim = async (characterId: number) => {
    if (!account || gameId == null) return
    const hero = heroes.find((h) => h.id === characterId)
    const name = hero ? ROLE_NAMES[hero.role > 0 ? hero.role - 1 : characterId] : `Hero ${characterId}`
    pushInfo(`${name} claiming loot...`)
    soundManager.playSfx('claim-loot', 0.5)
    if (hero && hero.gold > 0) {
      addGoldFloat(`+${hero.gold}g`)
    }
    const pendingId = createPendingTxId()
    const claimInventoryDelta = new Map<number, number>()
    if (hero && hero.ingredients != null && hero.ingredients !== 0n) {
      const bagItems = unpackCharacterIngredients(BigInt(hero.ingredients))
      for (let i = 0; i < bagItems.length; i++) {
        if (bagItems[i] > 0) claimInventoryDelta.set(i, bagItems[i])
      }
    }
    addPendingTx({
      id: pendingId,
      action: 'claim',
      heroId: characterId,
      inventoryDelta: claimInventoryDelta,
      goldDelta: hero?.gold ?? 0,
      effectsDelta: new Map(),
    })
    const t = txToast('Claiming loot')
    let success = false
    try {
      await client.claim(account, gameId, characterId)
      success = true
      t.success()
      setBrewRefreshKey(k => k + 1)
    } catch (e) {
      t.error()
      pushInfo(`${name} claim failed`)
      console.error('Claim failed:', e)
    } finally {
      finalizePendingTx(pendingId, success)
    }
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
    const pendingId = createPendingTxId()
    addPendingTx({
      id: pendingId,
      action: 'craft',
      inventoryDelta: new Map<number, number>([[lo, -1], [hi, -1]]),
      goldDelta: 0,
      effectsDelta: new Map(),
    })
    const t = txToast('Brewing potion')
    let success = false
    try {
      await client.craft(account, gameId, lo, hi)
      success = true
      t.success()
      soundManager.playSfx('brew-success', 0.4)
      setBrewRefreshKey(k => k + 1)
      if (isSoup) {
        addGoldFloat('+1g')
      }
      const qty = (id: number) => inventory.find(i => i.ingredient_id === id)?.quantity ?? 0
      if (slotA != null && qty(slotA) <= 0) setSlotA(null)
      if (slotB != null && qty(slotB) <= 0) setSlotB(null)
    } catch (e) {
      t.error()
      pushInfo('Brew failed')
      console.error('Craft failed:', e)
    } finally {
      finalizePendingTx(pendingId, success)
    }
  }

  const handleBrewAll = async () => {
    if (!account || gameId == null) return
    const freshRecipes = await fetchFreshRecipes(toriiClient, gameId)
    const selectedIngredient = slotA ?? slotB
    const selectedCount = Number(slotA != null) + Number(slotB != null)
    if (selectedCount >= 2) return
    const pairs = selectedCount === 1 && selectedIngredient != null
      ? computeUntriedPairsForFirstIngredient(inventory, freshRecipes, selectedIngredient)
      : computeUntriedPairs(inventory, freshRecipes)
    if (pairs.length === 0) { pushInfo('No new combinations available'); return }
    pushInfo(selectedCount === 1
      ? `Brewing ${pairs.length} new combinations for selected ingredient...`
      : `Brewing ${pairs.length} new combinations...`)
    const pendingId = createPendingTxId()
    const inventoryDelta = new Map<number, number>()
    for (const [a, b] of pairs) {
      inventoryDelta.set(a, (inventoryDelta.get(a) ?? 0) - 1)
      inventoryDelta.set(b, (inventoryDelta.get(b) ?? 0) - 1)
    }
    addPendingTx({
      id: pendingId,
      action: 'craftBatch',
      inventoryDelta,
      goldDelta: 0,
      effectsDelta: new Map(),
    })
    const t = txToast(`Brewing ${pairs.length} potions`)
    let success = false
    try {
      await client.craftBatch(account, gameId, pairs)
      success = true
      t.success()
      soundManager.playSfx('brew-success', 0.4)
      setBrewRefreshKey(k => k + 1)
    } catch (e) {
      t.error()
      pushInfo('Batch brew failed')
      console.error('Batch craft failed:', e)
    } finally {
      finalizePendingTx(pendingId, success)
    }
  }

  const handleClue = async () => {
    if (!account || gameId == null) return
    pushInfo('Buying hint...')
    const pendingId = createPendingTxId()
    const currentHintCost = game?.hint_price ?? 4
    addPendingTx({
      id: pendingId,
      action: 'clue',
      inventoryDelta: new Map(),
      goldDelta: -currentHintCost,
      effectsDelta: new Map(),
    })
    const t = txToast('Buying hint')
    let success = false
    try {
      await client.clue(account, gameId)
      success = true
      t.success()
      soundManager.playSfx('notification', 0.4)
    } catch (e) {
      t.error()
      pushInfo('Hint purchase failed')
      console.error('Clue failed:', e)
    } finally {
      finalizePendingTx(pendingId, success)
    }
  }

  const handleRecruit = async () => {
    if (!account || gameId == null) return
    pushInfo('Recruiting hero...')
    const pendingId = createPendingTxId()
    const currentHeroCount = game ? bitmapPopcount(game.heroes) : heroes.length
    const recruitCost = HERO_RECRUIT_COSTS[Math.min(currentHeroCount, 2)]
    addPendingTx({
      id: pendingId,
      action: 'recruit',
      inventoryDelta: new Map(),
      goldDelta: -recruitCost,
      effectsDelta: new Map(),
    })
    const t = txToast('Recruiting hero')
    let success = false
    try {
      await client.recruit(account, gameId)
      success = true
      t.success()
      soundManager.playSfx('recruit', 0.6)
    } catch (e) {
      t.error()
      pushInfo('Recruitment failed')
      console.error('Recruit failed:', e)
    } finally {
      finalizePendingTx(pendingId, success)
    }
  }

  const handleBuff = async (effect: number, heroId: number, quantity: number) => {
    if (!account || gameId == null) return
    pushInfo(`Applying potion to hero...`)
    const pendingId = createPendingTxId()
    addPendingTx({
      id: pendingId,
      action: 'buff',
      heroId,
      inventoryDelta: new Map(),
      goldDelta: 0,
      effectsDelta: new Map<number, number>([[effect, -quantity]]),
    })
    const t = txToast('Applying potion')
    let success = false
    try {
      await client.buff(account, gameId, heroId, effect, quantity)
      success = true
      t.success()
      soundManager.playSfx('potion-apply', 0.5)
    } catch (e) {
      t.error()
      pushInfo('Potion application failed')
      console.error('Buff failed:', e)
    } finally {
      finalizePendingTx(pendingId, success)
    }
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
  const hasPotions = effectQuantities.some((q) => q > 0)
  const heroCount = game ? bitmapPopcount(game.heroes) : Math.max(1, heroes.length)
  const hintCost = game?.hint_price ?? 4
  const startedAt = game ? Number(game.started_at) : now
  const endedAt = game && Number(game.ended_at) > 0 ? Number(game.ended_at) : now
  const elapsedSeconds = Math.max(0, endedAt - startedAt)
  const isCraftPending = isActionPending('craft')
  const isCraftBatchPending = isActionPending('craftBatch')
  const isHintPending = isActionPending('clue')
  const isBuffPending = isActionPending('buff')
  const isRecruitPending = isActionPending('recruit')

  const allGameEntities = useEntityQuery([Has(contractComponents.Game)])
  const leaderboardRank = useMemo(() => {
    if (!isGameOver || !gameId) return null
    const entries: { id: number; discovered: number; duration: number }[] = []
    for (const entity of allGameEntities) {
      const g = getComponentValue(contractComponents.Game, entity)
      if (!g || g.ended_at <= 0) continue
      entries.push({ id: g.id, discovered: bitmapPopcount(g.grimoire), duration: g.ended_at - g.started_at })
    }
    entries.sort((a, b) => b.discovered !== a.discovered ? b.discovered - a.discovered : a.duration - b.duration)
    const idx = entries.findIndex(e => e.id === gameId)
    return idx >= 0 ? idx + 1 : null
  }, [allGameEntities, contractComponents.Game, isGameOver, gameId])

  const journeyHeroes = useMemo(() =>
    heroes.map(h => {
      const isExploring = Number(h.available_at) > now
      const override = isExploring ? heroOverrides.get(h.id) : undefined
      return {
        hero_id: h.id,
        role: h.role,
        health: computeOptimisticHp(h, now, override),
        max_health: h.max_health,
        gold: override ? override.bagGold : h.gold,
        ingredients: override ? override.bagIngredients : h.ingredients,
      }
    }),
    [heroes, heroOverrides, now],
  )

  return (
    <div className="play-screen">
      <JourneyMap
        heroes={journeyHeroes}
        heroPositions={heroPositions}
        heroOverrides={heroOverrides}
        floatingTexts={floatingTexts}
        onFloatingTextComplete={removeFloatingText}
        selectedHeroId={selectedHeroId}
        isGameOver={isGameOver}
        onExplore={(heroId: number, zoneId: number) => void handleExplore(heroId, zoneId)}
      />

      <StatusHUD
        gold={gold}
        discoveredCount={discoveredCount}
        elapsedSeconds={elapsedSeconds}
        goldFloats={goldFloats}
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
              {heroCount > 0 && heroes.length === 0 && (
                <div className="panel-spinner">Loading heroes...</div>
              )}
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
                  onClaim={(id) => void handleClaim(id)}
                  hasPotions={hasPotions}
                  isRecruitPending={isRecruitPending}
                  isClaimPending={isHeroActionPending(slot, 'claim')}
                  isBuffPending={isBuffPending}
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
                brewAllCount={brewAllCount}
                isGameOver={isGameOver}
                isBrewing={isCraftPending || isCraftBatchPending}
                isBrewingAll={isCraftBatchPending}
                onSetSlotA={setSlotA}
                onSetSlotB={setSlotB}
                onCraft={(a, b) => void handleCraft(a, b)}
                onBrewAll={() => void handleBrewAll()}
              />

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
                  isHintPending={isHintPending}
                  inventory={inventory}
                  newlyDiscovered={newlyDiscoveredEffects}
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

      {(isGameOver || surrendered) && (
        <div className="game-over-overlay">
          <div className={`game-over-card floating-panel ${discoveredCount >= 30 ? 'won' : 'lost'}`}>
            <h2>{discoveredCount >= 30 ? 'Grimoire Complete' : surrendered ? 'Surrendered' : 'Game Over'}</h2>
            {discoveredCount >= 30 && (
              <p className="game-over-flavor">The Athanor blazes with primordial fire. All secrets are yours.</p>
            )}
            {surrendered && <p className="game-over-flavor">The Athanor grows cold. Your ambition fades to ash.</p>}
            {!surrendered && discoveredCount < 30 && (
              <p className="game-over-flavor">Your heroes fell. The Grimoire remains incomplete.</p>
            )}
            <div className="game-over-stats">
              {leaderboardRank != null && (
                <div className="game-over-stat">
                  <span className="game-over-stat-label">Rank</span>
                  <span className="game-over-stat-value">#{leaderboardRank}</span>
                </div>
              )}
              <div className="game-over-stat">
                <span className="game-over-stat-label">Time</span>
                <span className="game-over-stat-value">{formatGameDuration(elapsedSeconds)}</span>
              </div>
            </div>
            <div className="game-over-actions">
              {discoveredCount >= 30 && (
                <button onClick={() => {
                  const time = formatGameDuration(elapsedSeconds)
                  const text = `I completed the Grimoire in ${time}${leaderboardRank ? `, rank #${leaderboardRank}` : ''} on Athanor! Think you can beat that?\n\nPlay now:`
                  const url = window.location.origin
                  window.open(`https://x.com/intent/tweet?text=${encodeURIComponent(text)}&url=${encodeURIComponent(url)}`, '_blank')
                }}>
                  Share on X
                </button>
              )}
              <button onClick={() => navigate('home')}>
                Return to Menu
              </button>
            </div>
          </div>
        </div>
      )}

      {settingsOpen && (
        <SettingsOverlay
          open={settingsOpen}
          onClose={() => setSettingsOpen(false)}
          onSurrender={async () => {
            if (!account || gameId == null) return
            const pendingId = createPendingTxId()
            addPendingTx({
              id: pendingId,
              action: 'surrender',
              inventoryDelta: new Map(),
              goldDelta: 0,
              effectsDelta: new Map(),
            })
            let success = false
            try {
              await client.surrender(account, gameId)
              success = true
              setSurrendered(true)
              setSettingsOpen(false)
            } catch (e) {
              console.error('Surrender failed:', e)
            } finally {
              finalizePendingTx(pendingId, success)
            }
          }}
        />
      )}

      {newlyDiscoveredEffects.size > 0 && <div className="discovery-flash" />}

      <div className="mobile-tab-bar">
        {(['heroes', 'brew', 'logs'] as const).map(tab => (
          <button
            key={tab}
            className={`mobile-tab${mobilePanel === tab ? ' active' : ''}`}
            onClick={() => {
              setMobilePanel(prev => prev === tab ? null : tab)
              if (tab === 'heroes') setHeroesCollapsed(false)
              else if (tab === 'brew') setBrewCollapsed(false)
              else if (tab === 'logs') setLogsCollapsed(false)
            }}
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
          isBuffPending={isBuffPending}
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
  isBuffPending,
  onApply,
  onClose,
}: {
  heroId: number
  heroes: Array<{ id: number; role: number }>
  grimoire: number
  effectQuantities: number[]
  isBuffPending: boolean
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
      if (bitmapGet(grimoire, i) && effectQuantities[i] > 0) {
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
                      <span className={`craft-slot-qty${qty <= 0 ? ' craft-slot-qty-zero' : ''}`} style={qty > 0 ? { ['--qty-color' as string]: color } : undefined}>{qty}</span>
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
                disabled={totalSelected === 0 || isBuffPending}
              >
                {isBuffPending ? 'Applying...' : `Apply ${totalSelected > 0 ? `${totalSelected} to ${heroName}` : ''}`}
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
  onClaim: (characterId: number) => void
  hasPotions: boolean
  isRecruitPending: boolean
  isClaimPending: boolean
  isBuffPending: boolean
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
  onClaim,
  hasPotions,
  isRecruitPending,
  isClaimPending,
  isBuffPending,
  onApplyPotion,
}: HeroSlotProps) {
  const hero = heroes.find((h) => h.id === slot)

  const prevStatsRef = useRef<{ maxHp: number; power: number; regen: number } | null>(null)
  const [statDeltas, setStatDeltas] = useState<Array<{ id: string; label: string; value: number; color: string }>>([])
  const deltaIdRef = useRef(0)
  const deltasTimeoutRef = useRef<ReturnType<typeof setTimeout>>(0)

  useEffect(() => {
    if (!hero) { prevStatsRef.current = null; return }
    const prev = prevStatsRef.current
    if (prev !== null) {
      const deltas: Array<{ id: string; label: string; value: number; color: string }> = []
      if (hero.max_health > prev.maxHp)
        deltas.push({ id: `d${deltaIdRef.current++}`, label: 'Max HP', value: hero.max_health - prev.maxHp, color: '#d04050' })
      if (hero.power > prev.power)
        deltas.push({ id: `d${deltaIdRef.current++}`, label: 'Power', value: hero.power - prev.power, color: '#4080d0' })
      if (hero.regen > prev.regen)
        deltas.push({ id: `d${deltaIdRef.current++}`, label: 'Regen', value: hero.regen - prev.regen, color: '#40c060' })
      if (deltas.length > 0) {
        setStatDeltas(deltas)
        clearTimeout(deltasTimeoutRef.current)
        deltasTimeoutRef.current = setTimeout(() => setStatDeltas([]), 1500)
      }
    }
    prevStatsRef.current = { maxHp: hero.max_health, power: hero.power, regen: hero.regen }
  }, [hero?.max_health, hero?.power, hero?.regen])

  if (!hero) {
    if (slot < heroCount) return null
    if (slot === heroCount && heroCount < 3) {
      const cost = HERO_RECRUIT_COSTS[Math.min(heroCount, 2)]
      const canAfford = gold >= cost && !isGameOver && !isRecruitPending
      return (
        <div className="hero-card hero-card-locked">
          <div className="hero-card-locked-icon">+</div>
          <button
            className={`hero-card-recruit btn-primary${canAfford ? ' pulse-afford' : ''}`}
            onClick={onRecruit}
            disabled={!canAfford}
          >
            {isRecruitPending && !isGameOver ? 'Recruiting...' : `Recruit (${displayGold(cost)}g)`}
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
  const override = isExploring ? heroOverrides.get(hero.id) : undefined
  const isReturning = isExploring && (override?.returning === true || heroPos?.returning === true)

  let statusText = 'Ready'
  let statusClass = ''
  if (isReturning) { statusText = `Returning ${remaining}s`; statusClass = 'returning' }
  else if (isExploring) { statusText = `Exploring ${remaining}s`; statusClass = 'exploring' }
  else if (lootReady) { statusText = 'Loot Ready'; statusClass = 'loot-ready' }

  const optimisticHp = computeOptimisticHp(hero, now, override)

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
      {statDeltas.length > 0 && (
        <div className="hero-card-deltas">
          {statDeltas.map(d => (
            <span key={d.id} className="hero-stat-delta" style={{ color: d.color }}>
              +{d.value} {d.label}
            </span>
          ))}
        </div>
      )}
      {(() => {
        const bagGold = override ? override.bagGold : hero.gold
        const bagIngs = override
          ? override.bagIngredients
          : (hero.ingredients != null && hero.ingredients !== 0n
            ? unpackCharacterIngredients(BigInt(hero.ingredients))
            : null)
        const hasItems = bagGold > 0 || (bagIngs && bagIngs.some(q => q > 0))
        return hasItems ? (
          <div className="hero-bag">
            {bagGold > 0 && <span className="hero-bag-gold">{bagGold}g</span>}
            {bagIngs && bagIngs.map((qty, idx) =>
              qty > 0 ? (
                <span key={idx} className="hero-bag-item">
                  <img className="hero-bag-icon" src={ingredientAssetUrl(idx)} alt="" />
                  {qty > 1 && <span className="hero-bag-qty">{qty}</span>}
                </span>
              ) : null,
            )}
          </div>
        ) : null
      })()}
      <div className="hero-card-btn-row">
        <button
          className="btn-primary btn-sm btn-loot"
          onClick={(e) => { e.stopPropagation(); onClaim(hero.id) }}
          disabled={isGameOver || !lootReady || isClaimPending}
        >
          {isClaimPending && !isGameOver ? 'Claiming...' : 'Claim'}
        </button>
        <button
          className="btn-sm btn-potion"
          onClick={(e) => { e.stopPropagation(); onApplyPotion(hero.id) }}
          disabled={isGameOver || !hasPotions || isExploring || isBuffPending}
        >
          Apply Potion
        </button>
      </div>
    </div>
  )
}
