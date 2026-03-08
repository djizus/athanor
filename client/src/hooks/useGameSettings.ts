import { useMemo } from 'react'
import { useComponentValue } from '@dojoengine/react'
import { toEntityId } from '@/dojo/entityId'
import { useDojo } from '@/dojo/useDojo'

// Fallback defaults matching contract constants (contracts/src/constants.cairo)
const DEFAULTS = {
  zone_count: 5,
  ingredients_per_zone: 5,
  recipes_to_discover: 30,
  max_heroes: 3,
  hero_base_hp: 10000,     // x100 fixed-point → 100.00 HP
  hero_base_power: 500,    // x100 → 5.00
  hero_base_regen: 100,    // x100 → 1.00 HP/s
  hint_base_cost: 1000,    // x100 → 10.00 gold
  hint_cost_multiplier: 3,
  soup_gold_value: 1,
  progressive_cap: 8000,   // x10000 → 0.80
} as const

export interface GameSettingsData {
  zoneCount: number
  ingredientsPerZone: number
  totalIngredients: number
  recipesToDiscover: number
  maxHeroes: number
  heroBaseHp: number
  heroBasePower: number
  heroBaseRegen: number
  hintBaseCost: number
  hintCostMultiplier: number
  soupGoldValue: number
  progressiveCap: number
}

const FP100 = 100

export function useGameSettings(settingsId = 0): GameSettingsData {
  const { contractComponents } = useDojo()

  const entityId = useMemo(
    () => toEntityId([BigInt(settingsId)]),
    [settingsId],
  )

  const raw = useComponentValue(contractComponents.GameSettings, entityId)

  return useMemo(() => {
    const s = raw ?? DEFAULTS
    const zoneCount = s.zone_count
    const ingredientsPerZone = s.ingredients_per_zone
    return {
      zoneCount,
      ingredientsPerZone,
      totalIngredients: zoneCount * ingredientsPerZone,
      recipesToDiscover: s.recipes_to_discover,
      maxHeroes: s.max_heroes,
      heroBaseHp: s.hero_base_hp / FP100,
      heroBasePower: s.hero_base_power / FP100,
      heroBaseRegen: s.hero_base_regen / FP100,
      hintBaseCost: s.hint_base_cost / FP100,
      hintCostMultiplier: s.hint_cost_multiplier,
      soupGoldValue: s.soup_gold_value,
      progressiveCap: s.progressive_cap / 10000,
    }
  }, [raw])
}
