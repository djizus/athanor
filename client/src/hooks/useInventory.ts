import { useMemo } from 'react'
import { useComponentValue } from '@dojoengine/react'
import { toEntityId } from '@/dojo/entityId'
import { useDojo } from '@/dojo/useDojo'

const TOTAL_INGREDIENTS = 9

export function useInventory(gameId: number | null) {
  const { contractComponents } = useDojo()

  const keys = useMemo(
    () =>
      Array.from({ length: TOTAL_INGREDIENTS }, (_, i) =>
        gameId != null ? toEntityId([BigInt(gameId), BigInt(i)]) : undefined,
      ),
    [gameId],
  )

  const i0 = useComponentValue(contractComponents.IngredientBalance, keys[0])
  const i1 = useComponentValue(contractComponents.IngredientBalance, keys[1])
  const i2 = useComponentValue(contractComponents.IngredientBalance, keys[2])
  const i3 = useComponentValue(contractComponents.IngredientBalance, keys[3])
  const i4 = useComponentValue(contractComponents.IngredientBalance, keys[4])
  const i5 = useComponentValue(contractComponents.IngredientBalance, keys[5])
  const i6 = useComponentValue(contractComponents.IngredientBalance, keys[6])
  const i7 = useComponentValue(contractComponents.IngredientBalance, keys[7])
  const i8 = useComponentValue(contractComponents.IngredientBalance, keys[8])

  return useMemo(
    () =>
      [i0, i1, i2, i3, i4, i5, i6, i7, i8].map((item, index) => ({
        ingredient_id: index,
        quantity: item?.quantity ?? 0,
      })),
    [i0, i1, i2, i3, i4, i5, i6, i7, i8],
  )
}
