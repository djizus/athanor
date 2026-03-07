import { useMemo } from 'react'
import { Has, getComponentValue } from '@dojoengine/recs'
import { useEntityQuery } from '@dojoengine/react'
import { useDojo } from '@/dojo/useDojo'
import { bitmapPopcount } from '@/game/packer'

export function usePlayerRank(address: string | undefined): number | null {
  const { contractComponents } = useDojo()
  const sessionEntities = useEntityQuery([Has(contractComponents.GameSession)])
  const gameEntities = useEntityQuery([Has(contractComponents.Game)])

  return useMemo(() => {
    if (!address) return null

    const playerBigInt = BigInt(address)

    type Row = { player: bigint; discoveredCount: number; startedAt: number }
    const completed: Row[] = []

    for (const entity of sessionEntities) {
      const session = getComponentValue(contractComponents.GameSession, entity)
      if (!session) continue

      const gameId = Number(session.game_id)

      // Look up the Game model for authoritative ended_at / grimoire data
      const game = gameEntities
        .map((e) => getComponentValue(contractComponents.Game, e))
        .find((g) => g && Number(g.id) === gameId)

      const isOver = game ? Number(game.ended_at) > 0 : session.game_over
      if (!isOver) continue

      const discoveredCount = game ? bitmapPopcount(game.grimoire) : session.discovered_count

      completed.push({
        player: BigInt(session.player),
        discoveredCount,
        startedAt: game ? Number(game.started_at) : Number(session.started_at),
      })
    }

    completed.sort((a, b) => {
      if (b.discoveredCount !== a.discoveredCount) return b.discoveredCount - a.discoveredCount
      return a.startedAt - b.startedAt
    })

    const playerBest = completed.find((r) => r.player === playerBigInt)
    if (!playerBest) return null

    const rank = completed.indexOf(playerBest) + 1
    return rank
  }, [address, contractComponents.GameSession, contractComponents.Game, sessionEntities, gameEntities])
}
