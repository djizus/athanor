import { useMemo } from 'react'
import { Has, getComponentValue } from '@dojoengine/recs'
import { useEntityQuery } from '@dojoengine/react'
import { useDojo } from '@/dojo/useDojo'
import { bitmapPopcount } from '@/game/packer'

export type GameToken = {
  game_id: number
  discovered_count: number
  game_over: boolean
  started_at: number
}

export function useGameTokens(playerAddress: string | undefined) {
  const { contractComponents } = useDojo()
  const sessionEntities = useEntityQuery([Has(contractComponents.GameSession)])
  const gameEntities = useEntityQuery([Has(contractComponents.Game)])

  return useMemo(() => {
    if (!playerAddress) return []

    const normalizedPlayer = BigInt(playerAddress)
    const result: GameToken[] = []

    for (const entity of sessionEntities) {
      const session = getComponentValue(contractComponents.GameSession, entity)
      if (!session) continue
      if (BigInt(session.player) !== normalizedPlayer) continue

      const gameId = Number(session.game_id)
      const game = gameEntities
        .map((e) => getComponentValue(contractComponents.Game, e))
        .find((g) => g && Number(g.id) === gameId)

      result.push({
        game_id: gameId,
        discovered_count: game ? bitmapPopcount(game.grimoire) : session.discovered_count,
        game_over: game ? Number(game.ended_at) > 0 : session.game_over,
        started_at: game ? Number(game.started_at) : Number(session.started_at),
      })
    }

    return result.sort((a, b) => b.started_at - a.started_at)
  }, [contractComponents.GameSession, contractComponents.Game, sessionEntities, gameEntities, playerAddress])
}
