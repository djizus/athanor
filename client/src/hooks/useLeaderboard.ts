import { useMemo } from 'react'
import { Has, getComponentValue } from '@dojoengine/recs'
import { useEntityQuery } from '@dojoengine/react'
import { useDojo } from '@/dojo/useDojo'
import { bitmapPopcount } from '@/game/packer'

export type LeaderboardEntry = {
  id: number
  discoveredCount: number
  duration: number
}

export function useLeaderboard() {
  const { contractComponents } = useDojo()
  const allGameEntities = useEntityQuery([Has(contractComponents.Game)])

  const sorted = useMemo(() => {
    const entries: LeaderboardEntry[] = []
    for (const entity of allGameEntities) {
      const game = getComponentValue(contractComponents.Game, entity)
      if (!game || game.ended_at <= 0) continue
      entries.push({
        id: game.id,
        discoveredCount: bitmapPopcount(game.grimoire),
        duration: game.ended_at - game.started_at,
      })
    }
    entries.sort((a, b) => {
      if (b.discoveredCount !== a.discoveredCount) return b.discoveredCount - a.discoveredCount
      return a.duration - b.duration
    })
    return entries
  }, [allGameEntities, contractComponents.Game])

  const rankByGameId = useMemo(() => {
    const map = new Map<number, number>()
    for (let i = 0; i < sorted.length; i++) {
      map.set(sorted[i].id, i + 1)
    }
    return map
  }, [sorted])

  return { sorted, rankByGameId }
}

export function usePlayerRank(playerGameIds: number[]): number | null {
  const { rankByGameId } = useLeaderboard()

  return useMemo(() => {
    if (playerGameIds.length === 0) return null
    let best: number | null = null
    for (const id of playerGameIds) {
      const rank = rankByGameId.get(id)
      if (rank != null && (best === null || rank < best)) best = rank
    }
    return best
  }, [rankByGameId, playerGameIds])
}
