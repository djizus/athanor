import { useMemo } from 'react'
import { useComponentValue } from '@dojoengine/react'
import { toEntityId } from '@/dojo/entityId'
import { useDojo } from '@/dojo/useDojo'

export function useGame(gameId: number | null) {
  const { contractComponents } = useDojo()

  const entityId = useMemo(
    () => (gameId != null ? toEntityId([BigInt(gameId)]) : undefined),
    [gameId],
  )

  const game = useComponentValue(contractComponents.Game, entityId)
  const session = useComponentValue(contractComponents.GameSession, entityId)

  return { game, session }
}
