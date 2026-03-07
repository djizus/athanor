import { useMemo } from 'react'
import { Has, getComponentValue } from '@dojoengine/recs'
import { useEntityQuery } from '@dojoengine/react'
import { useDojo } from '@/dojo/useDojo'

export type DiscoveryData = {
  ingredient_a: number
  ingredient_b: number
  effect: number
  discovered: boolean
}

export function useDiscoveries(gameId: number | null) {
  const { contractComponents } = useDojo()
  const entities = useEntityQuery([Has(contractComponents.Discovery)])

  return useMemo(() => {
    if (gameId == null) return []

    const result: DiscoveryData[] = []

    for (const entity of entities) {
      const data = getComponentValue(contractComponents.Discovery, entity)
      if (!data) continue
      if (data.game_id !== gameId) continue

      result.push({
        ingredient_a: data.ingredient_a,
        ingredient_b: data.ingredient_b,
        effect: data.effect,
        discovered: data.discovered,
      })
    }

    return result
  }, [contractComponents.Discovery, entities, gameId])
}

export { useDiscoveries as useRecipes }
