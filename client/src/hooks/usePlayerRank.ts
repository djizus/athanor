import { useMemo } from 'react'
import { Has, getComponentValue } from '@dojoengine/recs'
import { useEntityQuery } from '@dojoengine/react'
import { useDojo } from '@/dojo/useDojo'

export function usePlayerRank(address: string | undefined): number | null {
  const { contractComponents } = useDojo()
  const entities = useEntityQuery([Has(contractComponents.GameSession)])

  return useMemo(() => {
    if (!address) return null

    const playerBigInt = BigInt(address)

    type Row = { player: bigint; discoveredCount: number; startedAt: number }
    const completed: Row[] = []

    for (const entity of entities) {
      const session = getComponentValue(contractComponents.GameSession, entity)
      if (!session || !session.game_over) continue

      completed.push({
        player: BigInt(session.player),
        discoveredCount: session.discovered_count,
        startedAt: Number(session.started_at),
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
  }, [address, contractComponents.GameSession, entities])
}
