import { useMemo } from 'react'
import { useGame } from './useGame'
import { unpackIngredients, INGREDIENT_COUNT } from '@/game/packer'

export function useInventory(gameId: number | null) {
  const { game } = useGame(gameId)

  return useMemo(() => {
    if (!game) {
      return Array.from({ length: INGREDIENT_COUNT }, (_, i) => ({
        ingredient_id: i,
        quantity: 0,
      }))
    }

    const quantities = unpackIngredients(BigInt(game.ingredients))
    return quantities.map((quantity, index) => ({
      ingredient_id: index,
      quantity,
    }))
  }, [game])
}
