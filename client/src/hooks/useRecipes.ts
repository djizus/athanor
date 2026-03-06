import { useMemo } from 'react'
import { useComponentValue } from '@dojoengine/react'
import { toEntityId } from '@/dojo/entityId'
import { useDojo } from '@/dojo/useDojo'

const RECIPES_TO_DISCOVER = 10

export function useRecipes(gameId: number | null) {
  const { contractComponents } = useDojo()

  const keys = useMemo(
    () =>
      Array.from({ length: RECIPES_TO_DISCOVER }, (_, i) =>
        gameId != null ? toEntityId([BigInt(gameId), BigInt(i)]) : undefined,
      ),
    [gameId],
  )

  const r0 = useComponentValue(contractComponents.Recipe, keys[0])
  const r1 = useComponentValue(contractComponents.Recipe, keys[1])
  const r2 = useComponentValue(contractComponents.Recipe, keys[2])
  const r3 = useComponentValue(contractComponents.Recipe, keys[3])
  const r4 = useComponentValue(contractComponents.Recipe, keys[4])
  const r5 = useComponentValue(contractComponents.Recipe, keys[5])
  const r6 = useComponentValue(contractComponents.Recipe, keys[6])
  const r7 = useComponentValue(contractComponents.Recipe, keys[7])
  const r8 = useComponentValue(contractComponents.Recipe, keys[8])
  const r9 = useComponentValue(contractComponents.Recipe, keys[9])

  return useMemo(
    () => [r0, r1, r2, r3, r4, r5, r6, r7, r8, r9].filter((r): r is NonNullable<typeof r> => r != null),
    [r0, r1, r2, r3, r4, r5, r6, r7, r8, r9],
  )
}
