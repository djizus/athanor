import { useCallback, useMemo, useRef, useState } from 'react'

export interface HeroPosition {
  zoneIndex: number
  returning: boolean
}

interface HeroExpedition {
  lastKnownZone: number
}

export function useExpeditionTracker(
  heroes: Array<{ id: number; available_at: number }>,
  now: number,
) {
  const expeditions = useRef(new Map<number, HeroExpedition>())
  const [version, setVersion] = useState(0)

  const onExpeditionStart = useCallback((heroId: number, zoneId: number = 0) => {
    expeditions.current.set(heroId, { lastKnownZone: zoneId })
    setVersion(v => v + 1)
  }, [])

  const onExplorationZoneUpdate = useCallback((heroId: number, zoneId: number) => {
    const expedition = expeditions.current.get(heroId)
    if (expedition) {
      expedition.lastKnownZone = zoneId
      setVersion(v => v + 1)
    }
  }, [])

  const heroPositions = useMemo(() => {
    const activeHeroes = new Set<number>()
    const positions = new Map<number, HeroPosition>()

    for (const hero of heroes) {
      const availableAt = Number(hero.available_at)
      const isExploring = availableAt > now

      if (isExploring) {
        activeHeroes.add(hero.id)
        if (!expeditions.current.has(hero.id)) {
          expeditions.current.set(hero.id, { lastKnownZone: 0 })
        }
      }

      if (!isExploring) {
        expeditions.current.delete(hero.id)
        positions.set(hero.id, { zoneIndex: -1, returning: false })
        continue
      }

      const expedition = expeditions.current.get(hero.id)
      positions.set(hero.id, {
        zoneIndex: expedition?.lastKnownZone ?? 0,
        returning: false,
      })
    }

    for (const heroId of expeditions.current.keys()) {
      if (!activeHeroes.has(heroId)) {
        expeditions.current.delete(heroId)
      }
    }

    return positions
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [heroes, now, version])

  return { heroPositions, onExpeditionStart, onExplorationZoneUpdate }
}
