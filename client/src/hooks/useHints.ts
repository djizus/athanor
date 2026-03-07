import { useMemo } from 'react'
import { Has, getComponentValue } from '@dojoengine/recs'
import { useEntityQuery } from '@dojoengine/react'
import { useDojo } from '@/dojo/useDojo'
import { bitmapGet, EFFECT_COUNT } from '@/game/packer'

export function useHints(gameId: number | null): Map<number, number[]> {
  const { contractComponents } = useDojo()
  const entities = useEntityQuery([Has(contractComponents.Hint)])

  return useMemo(() => {
    const result = new Map<number, number[]>()
    if (gameId == null) return result

    for (const entity of entities) {
      const data = getComponentValue(contractComponents.Hint, entity)
      if (!data || data.game_id !== gameId) continue

      const ingredient = data.ingredient - 1
      for (let i = 0; i < EFFECT_COUNT; i++) {
        if (bitmapGet(data.recipes, i)) {
          const list = result.get(i) ?? []
          list.push(ingredient)
          result.set(i, list)
        }
      }
    }
    return result
  }, [contractComponents.Hint, entities, gameId])
}
