import { useCallback, useMemo, useRef, useState } from 'react'
import { getZoneForDepth, ZONE_DEPTHS } from '@/game/constants'

export interface HeroPosition {
  zoneIndex: number
  returning: boolean
}

interface HeroExpedition {
  startTime: number
  lastKnownZone: number
}

export function useExpeditionTracker(
  heroes: Array<{ id: number; health: number; available_at: number }>,
  now: number,
) {
  const expeditions = useRef(new Map<number, HeroExpedition>())
  const [version, setVersion] = useState(0)

  const onExpeditionStart = useCallback((heroId: number) => {
    expeditions.current.set(heroId, {
      startTime: Math.floor(Date.now() / 1000),
      lastKnownZone: 0,
    })
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
      const isExploring = availableAt > now && hero.health > 0

      if (isExploring) {
        activeHeroes.add(hero.id)
        if (!expeditions.current.has(hero.id)) {
          expeditions.current.set(hero.id, { startTime: now, lastKnownZone: 0 })
        }
      }

      if (!isExploring) {
        expeditions.current.delete(hero.id)
        positions.set(hero.id, { zoneIndex: -1, returning: false })
        continue
      }

      const expedition = expeditions.current.get(hero.id)
      if (expedition) {
        const totalTime = availableAt - expedition.startTime
        const forwardTime = Math.floor(totalTime * 2 / 3)
        const elapsed = now - expedition.startTime

        if (elapsed >= forwardTime) {
          positions.set(hero.id, { zoneIndex: expedition.lastKnownZone, returning: true })
        } else {
          const currentDepth = Math.min(elapsed, forwardTime)
          const computedZone = getZoneForDepth(currentDepth)
          positions.set(hero.id, {
            zoneIndex: Math.max(computedZone, expedition.lastKnownZone),
            returning: false,
          })
        }
      } else {
        const remaining = availableAt - now
        const maxDepth = ZONE_DEPTHS[ZONE_DEPTHS.length - 1]
        const maxExpeditionTime = Math.floor(3 * maxDepth / 2)
        const estimatedTotal = Math.min(remaining * 3, maxExpeditionTime * 3)
        const estimatedForward = Math.floor(estimatedTotal * 2 / 3)
        const estimatedElapsed = estimatedTotal - remaining

        if (estimatedElapsed >= estimatedForward) {
          positions.set(hero.id, { zoneIndex: 4, returning: true })
        } else {
          const depth = Math.min(estimatedElapsed, estimatedForward)
          positions.set(hero.id, { zoneIndex: getZoneForDepth(depth), returning: false })
        }
      }
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
