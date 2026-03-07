import { useEffect, useRef, useState, useCallback } from 'react'
import { useDojo } from '@/dojo/useDojo'
import {
  INGREDIENT_NAMES,
  ZONE_NAMES,
  EFFECT_NAMES,
  displayGold,
} from '@/game/constants'

const { VITE_PUBLIC_NAMESPACE } = import.meta.env
const namespace = VITE_PUBLIC_NAMESPACE || 'ATHANOR'

export interface LogEntry {
  ts: number
  text: string
  kind: 'exploration' | 'loot' | 'recipe' | 'recruit' | 'potion' | 'expedition' | 'info'
}

// Contract Category enum: None=0, Trap=1, Gold=2, Heal=3, BeastWin=4, BeastLose=5, Ingredient=6
const CATEGORY_TRAP = 1
const CATEGORY_GOLD = 2
const CATEGORY_HEAL = 3
const CATEGORY_BEAST_WIN = 4
const CATEGORY_BEAST_LOSE = 5
const CATEGORY_INGREDIENT = 6

// Torii wraps field values as nested { value: { value: N } } — recursively unwrap to number
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
    case CATEGORY_TRAP: return `took ${value} trap damage (HP: ${hpAfter})`
    case CATEGORY_GOLD: return `found ${displayGold(value)}g`
    case CATEGORY_HEAL: return `healed ${value} HP (HP: ${hpAfter})`
    case CATEGORY_BEAST_WIN: return `slew a beast, looted ${displayGold(value)}g`
    case CATEGORY_BEAST_LOSE: return `lost to a beast, took ${value} damage (HP: ${hpAfter})`
    case CATEGORY_INGREDIENT: return `found ${INGREDIENT_NAMES[value] ?? `ingredient #${value}`}`
    default: return `unknown event ${eventKind}`
  }
}

function formatEvent(modelName: string, values: Record<string, number>): LogEntry | null {
  switch (modelName) {
    case 'ExplorationEvent': {
      const zone = ZONE_NAMES[values.zone_id] ?? `Zone ${values.zone_id}`
      const detail = formatExplorationDetail(values.event_kind, values.value, values.hp_after)
      return { ts: Date.now(), text: `Hero ${values.hero_id} in ${zone} (depth ${values.depth}): ${detail}`, kind: 'exploration' }
    }
    case 'ExpeditionStarted': {
      return { ts: Date.now(), text: `Hero ${values.hero_id} departed on expedition`, kind: 'expedition' }
    }
    case 'LootClaimed': {
      return { ts: Date.now(), text: `Hero ${values.hero_id} claimed ${displayGold(values.gold)}g loot`, kind: 'loot' }
    }
    case 'RecipeDiscovered': {
      const a = INGREDIENT_NAMES[values.ingredient_a - 1] ?? '?'
      const b = INGREDIENT_NAMES[values.ingredient_b - 1] ?? '?'
      const effect = EFFECT_NAMES[values.effect_type - 1] ?? '?'
      return { ts: Date.now(), text: `Discovered: ${a} + ${b} → ${effect} (${values.discovered_count}/30)`, kind: 'recipe' }
    }
    case 'HeroRecruited': {
      return { ts: Date.now(), text: `Hero ${values.hero_id} recruited for ${displayGold(values.cost)}g`, kind: 'recruit' }
    }
    case 'PotionApplied': {
      const effect = EFFECT_NAMES[values.effect_type - 1] ?? '?'
      return { ts: Date.now(), text: `Hero ${values.hero_id} consumed potion: ${effect} +${values.effect_value}`, kind: 'potion' }
    }
    default:
      return null
  }
}

const MAX_LOG = 200

export function useExplorationLog(gameId: number | null) {
  const { toriiClient } = useDojo()
  const [logs, setLogs] = useState<LogEntry[]>([])
  const subRef = useRef<{ cancel: () => void } | null>(null)

  const append = useCallback((entry: LogEntry) => {
    setLogs((prev) => [...prev.slice(-(MAX_LOG - 1)), entry])
  }, [])

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
          const entry = formatEvent(shortName, values)
          if (entry) {
            console.debug('[ExplorationLog]', shortName, values, '->', entry.text)
            append(entry)
          }
        }
      },
    ).then((sub) => {
      if (cancelled) { sub.cancel(); return }
      subRef.current = sub
      console.log('[ExplorationLog] Subscription active for game', gameId, 'key:', hexGameId)
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
    }
  }, [gameId, toriiClient, append])

  return { logs, pushInfo }
}
