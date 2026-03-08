import { useMemo } from 'react'
import { Has, getComponentValue } from '@dojoengine/recs'
import { useEntityQuery } from '@dojoengine/react'
import { useDojo } from '@/dojo/useDojo'
import { bitmapPopcount } from '@/game/packer'

export function usePlayerRank(playerGameIds: number[]): number | null {
  const { contractComponents } = useDojo()
  const allGameEntities = useEntityQuery([Has(contractComponents.Game)])

  return useMemo(() => {
    if (playerGameIds.length === 0) return null

    const allCompleted: { id: number; discoveredCount: number; duration: number }[] = []
    for (const entity of allGameEntities) {
      const game = getComponentValue(contractComponents.Game, entity)
      if (!game || game.ended_at <= 0) continue
      allCompleted.push({
        id: game.id,
        discoveredCount: bitmapPopcount(game.grimoire),
        duration: game.ended_at - game.started_at,
      })
    }

    allCompleted.sort((a, b) => {
      if (b.discoveredCount !== a.discoveredCount) return b.discoveredCount - a.discoveredCount
      return a.duration - b.duration
    })

    const ids = new Set(playerGameIds)
    for (let i = 0; i < allCompleted.length; i++) {
      if (ids.has(allCompleted[i].id)) return i + 1
    }
    return null
  }, [allGameEntities, contractComponents.Game, playerGameIds])
}
