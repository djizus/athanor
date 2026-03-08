import { useEffect, useRef, useState, useCallback } from 'react'
import { useDojo } from '@/dojo/useDojo'
import {
  INGREDIENT_NAMES,
  ZONE_NAMES,
  EFFECT_NAMES,
  ROLE_NAMES,
  displayGold,
} from '@/game/constants'

const { VITE_PUBLIC_NAMESPACE } = import.meta.env
const namespace = VITE_PUBLIC_NAMESPACE || 'ATHANOR'

export interface LogEntry {
  ts: number
  text: string
  kind: 'exploration' | 'loot' | 'recipe' | 'recruit' | 'potion' | 'expedition' | 'info'
}

export type ExplorationEventKind = 'drain' | 'trap' | 'gold' | 'heal' | 'beastWin' | 'beastLose' | 'ingredient'

export interface RawExplorationEvent {
  kind: ExplorationEventKind
  heroId: number
  value: number
  hpAfter: number
  zoneId: number
  depth: number
}

export interface HeroOverride {
  health: number
  zoneIndex?: number
  bagGold: number
  bagIngredients: number[]
  autoClaimAnimating?: boolean
  returning?: boolean
  returnStartedAt?: number
  returnDuration?: number
}

const CATEGORY_NONE = 0
const CATEGORY_TRAP = 1
const CATEGORY_GOLD = 2
const CATEGORY_HEAL = 3
const CATEGORY_BEAST_WIN = 4
const CATEGORY_BEAST_LOSE = 5
const CATEGORY_INGREDIENT = 6

const CATEGORY_TO_KIND: Record<number, ExplorationEventKind> = {
  [CATEGORY_NONE]: 'drain',
  [CATEGORY_TRAP]: 'trap',
  [CATEGORY_GOLD]: 'gold',
  [CATEGORY_HEAL]: 'heal',
  [CATEGORY_BEAST_WIN]: 'beastWin',
  [CATEGORY_BEAST_LOSE]: 'beastLose',
  [CATEGORY_INGREDIENT]: 'ingredient',
}

// Per-depth HP drain per zone (contracts/src/constants.cairo ZONE_*_DRAIN / 100)
const ZONE_DRAIN = [1, 2, 3, 4, 5]

// Mirrors contracts/src/constants.cairo DEFAULT_WALK_RATIO and WALK_BASE_MULTIPLIER
// Walk-back time = death_depth * (WALK_RATIO / WALK_BASE) seconds
const WALK_RATIO = 25
const WALK_BASE = 100

const TICK_INTERVAL_MS = 1000

interface QueuedEvent {
  entry: LogEntry
  rawEvent?: RawExplorationEvent
}

function extractNumber(val: unknown): number {
  if (val == null) return 0
  if (typeof val === 'number') return val
  if (typeof val === 'bigint') return Number(val)
  if (typeof val === 'string') return Number(val)
  if (typeof val === 'object') {
    const obj = val as Record<string, unknown>
    if ('value' in obj) {
      const inner = obj.value
      if (typeof inner === 'object' && inner != null && 'value' in (inner as Record<string, unknown>)) {
        return extractNumber((inner as Record<string, unknown>).value)
      }
      return extractNumber(inner)
    }
  }
  return 0
}

function parseModelValues(model: Record<string, unknown>): Record<string, number> {
  const out: Record<string, number> = {}
  for (const [key, val] of Object.entries(model)) {
    out[key] = extractNumber(val)
  }
  return out
}

function formatExplorationDetail(eventKind: number, value: number, hpAfter: number): string {
  switch (eventKind) {
    case CATEGORY_NONE: return `collapsed from exhaustion (HP: ${hpAfter})`
    case CATEGORY_TRAP: return `took ${value} trap damage (HP: ${hpAfter})`
    case CATEGORY_GOLD: return `found ${displayGold(value)}g (HP: ${hpAfter})`
    case CATEGORY_HEAL: return `healed ${value} HP (HP: ${hpAfter})`
    case CATEGORY_BEAST_WIN: return `slew a beast, looted ${displayGold(value)}g (HP: ${hpAfter})`
    case CATEGORY_BEAST_LOSE: return `lost to a beast, took ${value} damage (HP: ${hpAfter})`
    case CATEGORY_INGREDIENT: return `found ${INGREDIENT_NAMES[value] ?? `ingredient #${value}`} (HP: ${hpAfter})`
    default: return `unknown event ${eventKind} (HP: ${hpAfter})`
  }
}

interface FormatResult {
  entry: LogEntry
  rawEvent?: RawExplorationEvent
  eventKind?: number
  value?: number
  hpAfter?: number
  heroId?: number
}

function formatEvent(modelName: string, values: Record<string, number>, heroName: string): FormatResult | null {
  switch (modelName) {
    case 'ExplorationEvent': {
      const zone = ZONE_NAMES[values.zone_id] ?? `Zone ${values.zone_id}`
      const detail = formatExplorationDetail(values.event_kind, values.value, values.hp_after)
      const eventKind = CATEGORY_TO_KIND[values.event_kind]
      return {
        entry: { ts: Date.now(), text: `${heroName} in ${zone} (depth ${values.depth}): ${detail}`, kind: 'exploration' },
        rawEvent: eventKind ? { kind: eventKind, heroId: values.hero_id, value: values.value, hpAfter: values.hp_after, zoneId: values.zone_id, depth: values.depth } : undefined,
        eventKind: values.event_kind,
        value: values.value,
        hpAfter: values.hp_after,
        heroId: values.hero_id,
      }
    }
    case 'ExpeditionStarted': {
      return { entry: { ts: Date.now(), text: `${heroName} departed on expedition`, kind: 'expedition' } }
    }
    case 'LootClaimed': {
      return { entry: { ts: Date.now(), text: `${heroName} claimed ${displayGold(values.gold)}g loot`, kind: 'loot' } }
    }
    case 'RecipeDiscovered': {
      const a = INGREDIENT_NAMES[values.ingredient_a - 1] ?? '?'
      const b = INGREDIENT_NAMES[values.ingredient_b - 1] ?? '?'
      const effect = EFFECT_NAMES[values.effect_type - 1] ?? '?'
      return { entry: { ts: Date.now(), text: `Discovered: ${a} + ${b} → ${effect} (${values.discovered_count}/30)`, kind: 'recipe' } }
    }
    case 'HeroRecruited': {
      return { entry: { ts: Date.now(), text: `${heroName} recruited for ${displayGold(values.cost)}g`, kind: 'recruit' } }
    }
    case 'PotionApplied': {
      const effect = EFFECT_NAMES[values.effect_type - 1] ?? '?'
      return { entry: { ts: Date.now(), text: `${heroName} consumed potion: ${effect} +${values.effect_value}`, kind: 'potion' } }
    }
    default:
      return null
  }
}

const MAX_LOG = 200

export function useExplorationLog(
  gameId: bigint | null,
  heroes: Array<{ id: number; role: number; health: number }> = [],
  onExplorationEvent?: (event: RawExplorationEvent) => void,
) {
  const { toriiClient } = useDojo()
  const [logs, setLogs] = useState<LogEntry[]>([])
  const [heroOverrides, setHeroOverrides] = useState<Map<number, HeroOverride>>(() => new Map())
  const subRef = useRef<{ cancel: () => void } | null>(null)
  const heroQueuesRef = useRef<Map<number, QueuedEvent[]>>(new Map())
  const heroDepthRef = useRef<Map<number, number>>(new Map())
  const drainTimerRef = useRef<number | null>(null)
  const heroMapRef = useRef<Map<number, string>>(new Map())
  const heroExpeditionRef = useRef<Map<number, { deathDepth: number; returnAt: number }>>(new Map())
  const heroMaxDepthRef = useRef<Map<number, number>>(new Map())
  const returnTimersRef = useRef<Map<number, number>>(new Map())
  const onEventRef = useRef(onExplorationEvent)
  onEventRef.current = onExplorationEvent

  const heroHealthRef = useRef<Map<number, number>>(new Map())

  useEffect(() => {
    const map = new Map<number, string>()
    const healthMap = new Map<number, number>()
    for (const hero of heroes) {
      const roleIdx = hero.role > 0 ? hero.role - 1 : hero.id
      map.set(hero.id, ROLE_NAMES[roleIdx] ?? `Hero ${hero.id}`)
      healthMap.set(hero.id, hero.health)
    }
    heroMapRef.current = map
    heroHealthRef.current = healthMap
  }, [heroes])

  const append = useCallback((entry: LogEntry) => {
    setLogs((prev) => [...prev.slice(-(MAX_LOG - 1)), entry])
  }, [])

  const drainTick = useCallback(() => {
    let anyRemaining = false
    for (const [heroId, queue] of heroQueuesRef.current) {
      const prevDepth = heroDepthRef.current.get(heroId) ?? -1
      const depth = prevDepth + 1
      heroDepthRef.current.set(heroId, depth)

      queue.sort((a, b) => (a.rawEvent?.depth ?? 0) - (b.rawEvent?.depth ?? 0))

      let processedEvent = false
      while (queue.length > 0 && (queue[0].rawEvent?.depth ?? 0) <= depth) {
        const event = queue.shift()!
        append(event.entry)

        if (event.rawEvent) {
          processedEvent = true
          // Track max depth for walk-back fallback
          const curMax = heroMaxDepthRef.current.get(heroId) ?? 0
          if (event.rawEvent.depth > curMax) heroMaxDepthRef.current.set(heroId, event.rawEvent.depth)

          setHeroOverrides((prev) => {
            const next = new Map(prev)
            const prevOv = prev.get(heroId)
            const bagGold = (prevOv?.bagGold ?? 0)
              + (event.rawEvent!.kind === 'gold' || event.rawEvent!.kind === 'beastWin' ? event.rawEvent!.value : 0)
            const bagIngredients = [...(prevOv?.bagIngredients ?? new Array(25).fill(0))]
            if (event.rawEvent!.kind === 'ingredient') {
              bagIngredients[event.rawEvent!.value] = (bagIngredients[event.rawEvent!.value] ?? 0) + 1
            }
            next.set(heroId, {
              health: event.rawEvent!.hpAfter,
              zoneIndex: event.rawEvent!.zoneId,
              bagGold,
              bagIngredients,
            })
            return next
          })
          onEventRef.current?.(event.rawEvent)
        }
      }

      if (!processedEvent) {
        setHeroOverrides((prev) => {
          const next = new Map(prev)
          const prevOv = prev.get(heroId)
          if (prevOv && prevOv.health > 0) {
            const zone = prevOv.zoneIndex ?? 0
            const drain = ZONE_DRAIN[zone] ?? 1
            next.set(heroId, { ...prevOv, health: Math.max(0, prevOv.health - drain) })
          }
          return next
        })
      }

      if (queue.length > 0) {
        anyRemaining = true
      } else {
        heroQueuesRef.current.delete(heroId)
        heroDepthRef.current.delete(heroId)

        const expedition = heroExpeditionRef.current.get(heroId)
        const maxDepth = heroMaxDepthRef.current.get(heroId) ?? 0
        const deathDepth = expedition?.deathDepth ?? maxDepth
        const walkDurationMs = deathDepth > 0
          ? Math.max(TICK_INTERVAL_MS, deathDepth * WALK_RATIO / WALK_BASE * TICK_INTERVAL_MS)
          : 2000
        heroMaxDepthRef.current.delete(heroId)

        const heroName = heroMapRef.current.get(heroId) ?? `Hero ${heroId}`
        const walkSeconds = (walkDurationMs / 1000).toFixed(1)

        append({ ts: Date.now(), text: `${heroName} returning to Athanor (${walkSeconds}s walk, depth ${deathDepth})`, kind: 'exploration' })

        setHeroOverrides((prev) => {
          const next = new Map(prev)
          const prevOv = prev.get(heroId)
          if (prevOv) {
            next.set(heroId, {
              ...prevOv,
              returning: true,
              returnStartedAt: Date.now(),
              returnDuration: walkDurationMs,
            })
          }
          return next
        })
      }
    }

    if (!anyRemaining) {
      window.clearInterval(drainTimerRef.current!)
      drainTimerRef.current = null
    }
  }, [append])

  const enqueue = useCallback((event: QueuedEvent) => {
    const heroId = event.rawEvent?.heroId ?? 0
    let queue = heroQueuesRef.current.get(heroId)
    if (!queue) {
      queue = []
      heroQueuesRef.current.set(heroId, queue)

      heroDepthRef.current.set(heroId, -1)

      if (event.rawEvent) {
        const startHp = heroHealthRef.current.get(heroId) ?? event.rawEvent.hpAfter
        setHeroOverrides((prev) => {
          const next = new Map(prev)
          next.set(heroId, { health: startHp, zoneIndex: event.rawEvent!.zoneId, bagGold: 0, bagIngredients: new Array(25).fill(0) })
          return next
        })
      }
    }

    queue.push(event)

    if (drainTimerRef.current == null) {
      drainTimerRef.current = window.setInterval(drainTick, TICK_INTERVAL_MS)
    }
  }, [drainTick])

  const pushInfo = useCallback((text: string) => {
    append({ ts: Date.now(), text, kind: 'info' })
  }, [append])

  useEffect(() => {
    if (gameId == null || !toriiClient) return

    const eventModels = [
      `${namespace}-ExplorationEvent`,
      `${namespace}-ExpeditionStarted`,
      `${namespace}-LootClaimed`,
      `${namespace}-RecipeDiscovered`,
      `${namespace}-HeroRecruited`,
      `${namespace}-PotionApplied`,
    ]

    const hexGameId = '0x' + gameId.toString(16)

    const clause = {
      Keys: {
        keys: [hexGameId],
        pattern_matching: 'VariableLen' as const,
        models: eventModels,
      },
    }

    let cancelled = false

    toriiClient.onEventMessageUpdated(
      clause,
      null,
      (rawEntity: unknown) => {
        if (cancelled) return

        let models: Record<string, Record<string, unknown>>
        const entity = rawEntity as Record<string, unknown>
        if (entity && typeof entity === 'object' && 'models' in entity && typeof entity.models === 'object') {
          models = entity.models as Record<string, Record<string, unknown>>
        } else if (entity && typeof entity === 'object') {
          models = entity as Record<string, Record<string, unknown>>
        } else {
          console.warn('[ExplorationLog] Unexpected entity shape:', rawEntity)
          return
        }

        for (const [fullModelName, modelValues] of Object.entries(models)) {
          if (typeof modelValues !== 'object' || modelValues == null) continue
          const shortName = fullModelName.includes('-') ? fullModelName.split('-').pop()! : fullModelName
          const values = parseModelValues(modelValues as Record<string, unknown>)
          const heroName = heroMapRef.current.get(values.hero_id) ?? `Hero ${values.hero_id}`
          const result = formatEvent(shortName, values, heroName)
          if (result) {
            if (shortName === 'ExplorationEvent' && !result.rawEvent) continue
            if (shortName === 'ExplorationEvent') {
              enqueue({ entry: result.entry, rawEvent: result.rawEvent })
            } else {
              if (shortName === 'ExpeditionStarted' && values.hero_id != null && values.death_depth > 0) {
                heroExpeditionRef.current.set(values.hero_id, {
                  deathDepth: values.death_depth,
                  returnAt: values.return_at,
                })
              }
              append(result.entry)
            }
          }
        }
      },
    ).then((sub) => {
      if (cancelled) { sub.cancel(); return }
      subRef.current = sub
      append({ ts: Date.now(), text: 'Event log connected', kind: 'info' })
    }).catch((err) => {
      if (!cancelled) {
        console.error('[ExplorationLog] Subscription failed:', err)
        append({ ts: Date.now(), text: `Event subscription failed: ${String(err)}`, kind: 'info' })
      }
    })

    return () => {
      cancelled = true
      subRef.current?.cancel()
      subRef.current = null
      if (drainTimerRef.current != null) {
        window.clearInterval(drainTimerRef.current)
        drainTimerRef.current = null
      }
      for (const timer of returnTimersRef.current.values()) {
        window.clearTimeout(timer)
      }
      returnTimersRef.current.clear()
      heroQueuesRef.current.clear()
      heroDepthRef.current.clear()
      heroExpeditionRef.current.clear()
      heroMaxDepthRef.current.clear()
    }
  }, [gameId, toriiClient, append, enqueue])

  const completeReturn = useCallback((heroId: number) => {
    const heroName = heroMapRef.current.get(heroId) ?? `Hero ${heroId}`
    append({ ts: Date.now(), text: `${heroName} arrived at Athanor`, kind: 'exploration' })

    setHeroOverrides((prev) => {
      const next = new Map(prev)
      const prevOv = prev.get(heroId)
      if (!prevOv) return prev
      next.set(heroId, { ...prevOv, returning: false, zoneIndex: -1 })
      return next
    })

    const cleanupTimer = window.setTimeout(() => {
      setHeroOverrides((p) => { const n = new Map(p); n.delete(heroId); return n })
      returnTimersRef.current.delete(heroId)
      heroExpeditionRef.current.delete(heroId)
    }, 3000)
    returnTimersRef.current.set(heroId, cleanupTimer)
  }, [append])

  return { logs, pushInfo, heroOverrides, completeReturn }
}
