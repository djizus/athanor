import { useMemo } from 'react'
import { Has, getComponentValue } from '@dojoengine/recs'
import { useEntityQuery } from '@dojoengine/react'
import { useDojo } from '@/dojo/useDojo'

export type GameToken = {
  game_id: number
  discovered_count: number
  game_over: boolean
  started_at: number
}

export function useGameTokens(playerAddress: string | undefined) {
  const { contractComponents } = useDojo()
  const entities = useEntityQuery([Has(contractComponents.GameSession)])

  return useMemo(() => {
    if (!playerAddress) return []

    const normalizedPlayer = BigInt(playerAddress)
    const result: GameToken[] = []

    for (const entity of entities) {
      const data = getComponentValue(contractComponents.GameSession, entity)
      if (!data) continue
      if (BigInt(data.player) !== normalizedPlayer) continue

      result.push({
        game_id: Number(data.game_id),
        discovered_count: data.discovered_count,
        game_over: data.game_over,
        started_at: Number(data.started_at),
      })
    }

    return result.sort((a, b) => b.started_at - a.started_at)
  }, [contractComponents.GameSession, entities, playerAddress])
}
