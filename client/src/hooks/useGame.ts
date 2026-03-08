import { useMemo } from 'react'
import { useComponentValue } from '@dojoengine/react'
import { toEntityId } from '@/dojo/entityId'
import { useDojo } from '@/dojo/useDojo'

export function useGame(gameId: bigint | null) {
  const { contractComponents } = useDojo()

  const entityId = useMemo(
    () => (gameId != null ? toEntityId([gameId]) : undefined),
    [gameId],
  )

  const game = useComponentValue(contractComponents.Game, entityId)

  return { game }
}
