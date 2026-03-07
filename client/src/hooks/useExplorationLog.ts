import { useEffect, useRef, useState, useCallback } from 'react'
import { useDojo } from '@/dojo/useDojo'
import {
  ROLE_NAMES,
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

const EVENT_KINDS: Record<number, string> = {
  0: 'found gold',
  1: 'found ingredient',
  2: 'took damage',
  3: 'found nothing',
}

function heroName(heroId: number): string {
  return ROLE_NAMES[heroId] ?? `Hero ${heroId}`
}

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

function formatEvent(modelName: string, values: Record<string, number>): LogEntry | null {
  switch (modelName) {
    case 'ExplorationEvent': {
      const name = heroName(values.hero_id)
      const zone = ZONE_NAMES[values.zone_id] ?? `Zone ${values.zone_id}`
      const kind = EVENT_KINDS[values.event_kind] ?? `event ${values.event_kind}`
      const detail = values.event_kind === 1
        ? `found ${INGREDIENT_NAMES[values.value] ?? `ingredient #${values.value}`}`
        : values.event_kind === 0
          ? `found ${displayGold(values.value)}g`
          : values.event_kind === 2
            ? `took ${values.value} damage (HP: ${values.hp_after})`
            : kind
      return { ts: Date.now(), text: `${name} in ${zone} (depth ${values.depth}): ${detail}`, kind: 'exploration' }
    }
    case 'ExpeditionStarted': {
      const name = heroName(values.hero_id)
      return { ts: Date.now(), text: `${name} departed on expedition`, kind: 'expedition' }
    }
    case 'LootClaimed': {
      const name = heroName(values.hero_id)
      return { ts: Date.now(), text: `${name} claimed ${displayGold(values.gold)}g loot`, kind: 'loot' }
    }
    case 'RecipeDiscovered': {
      const a = INGREDIENT_NAMES[values.ingredient_a] ?? '?'
      const b = INGREDIENT_NAMES[values.ingredient_b] ?? '?'
      const effect = EFFECT_NAMES[values.effect_type] ?? '?'
      return { ts: Date.now(), text: `Discovered: ${a} + ${b} → ${effect} (${values.discovered_count}/30)`, kind: 'recipe' }
    }
    case 'HeroRecruited': {
      const name = heroName(values.hero_id)
      return { ts: Date.now(), text: `${name} recruited for ${displayGold(values.cost)}g`, kind: 'recruit' }
    }
    case 'PotionApplied': {
      const name = heroName(values.hero_id)
      const effect = EFFECT_NAMES[values.effect_type] ?? '?'
      return { ts: Date.now(), text: `${name} consumed potion: ${effect} +${values.effect_value}`, kind: 'potion' }
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
      (_entityId: string, entityData: unknown) => {
        if (cancelled) return

        let models: Record<string, Record<string, unknown>>
        const data = entityData as Record<string, unknown>
        if (data && typeof data === 'object' && 'models' in data && typeof data.models === 'object') {
          models = data.models as Record<string, Record<string, unknown>>
        } else if (data && typeof data === 'object') {
          models = data as Record<string, Record<string, unknown>>
        } else {
          console.warn('[ExplorationLog] Unexpected entityData shape:', entityData)
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
