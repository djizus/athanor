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

function parseModelValues(model: Record<string, unknown>): Record<string, number> {
  const out: Record<string, number> = {}
  for (const [key, val] of Object.entries(model)) {
    if (typeof val === 'number') out[key] = val
    else if (typeof val === 'string') out[key] = Number(val)
    else if (typeof val === 'bigint') out[key] = Number(val)
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

  const pushLog = useCallback((entry: LogEntry) => {
    setLogs((prev) => [...prev.slice(-(MAX_LOG - 1)), entry])
  }, [])

  const pushInfo = useCallback((text: string) => {
    pushLog({ ts: Date.now(), text, kind: 'info' })
  }, [pushLog])

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

    const clause = {
      Keys: {
        keys: [String(gameId)],
        pattern_matching: 'VariableLen' as const,
        models: eventModels,
      },
    }

    toriiClient.onEventMessageUpdated(clause, null, (_entityId: string, entityData: Record<string, Record<string, unknown>>) => {
      for (const [fullModelName, modelValues] of Object.entries(entityData)) {
        const shortName = fullModelName.includes('-') ? fullModelName.split('-').pop()! : fullModelName
        const values = parseModelValues(modelValues as Record<string, unknown>)
        const entry = formatEvent(shortName, values)
        if (entry) pushLog(entry)
      }
    }).then((sub) => {
      subRef.current = sub
    }).catch((err) => {
      console.error('Event subscription failed:', err)
    })

    return () => {
      subRef.current?.cancel()
      subRef.current = null
    }
  }, [gameId, toriiClient, pushLog])

  return { logs, pushInfo }
}
