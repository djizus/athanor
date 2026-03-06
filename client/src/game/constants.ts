export const ZONE_NAMES = ['Verdant Meadow', 'Crystal Cavern', 'Aether Spire'] as const

export const INGREDIENT_NAMES = [
  'Moonpetal',
  'Dewdrop',
  'Thornberry',
  'Crystal Shard',
  'Echo Moss',
  'Cave Pearl',
  'Star Dust',
  'Void Salt',
  'Aether Bloom',
] as const

export const EFFECT_NAMES = ['Max HP', 'Power', 'Regen'] as const

export const HERO_STATUS_IDLE = 0
export const HERO_STATUS_EXPLORING = 1
export const HERO_STATUS_RETURNING = 2

export const ZONE_0_DEPTH = 0
export const ZONE_1_DEPTH = 20
export const ZONE_2_DEPTH = 45

export function getZoneForDepth(depth: number): number {
  if (depth >= ZONE_2_DEPTH) return 2
  if (depth >= ZONE_1_DEPTH) return 1
  return 0
}

export function displayHp(hp: number): string {
  return (hp / 100).toFixed(0)
}

export function displayGold(gold: number): string {
  return (gold / 100).toFixed(0)
}
