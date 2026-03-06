// ── Zone Configuration ──────────────────────────────────────

export const ZONE_NAMES = ['Verdant Meadow', 'Crystal Cavern', 'Aether Spire'] as const

export const ZONE_COLORS = ['#4a9e4a', '#b8860b', '#9e4a9e'] as const

export const ZONE_BG_KEYS = ['zone-meadow', 'zone-cavern', 'zone-spire'] as const

// ── Ingredients (3 per zone, 9 total) ───────────────────────

export const INGREDIENT_NAMES = [
  // Zone 0 — Verdant Meadow
  'Moonpetal',
  'Dewmoss',
  'River Clay',
  // Zone 1 — Crystal Cavern
  'Crystal Shard',
  'Drake Moss',
  'Sulfur Bloom',
  // Zone 2 — Aether Spire
  'Dragon Scale',
  'Aether Core',
  'Titan Blood',
] as const

export const INGREDIENT_KEYS = [
  'moonpetal',
  'dewmoss',
  'river-clay',
  'crystal-shard',
  'drake-moss',
  'sulfur-bloom',
  'dragon-scale',
  'aether-core',
  'titan-blood',
] as const

export const INGREDIENTS_PER_ZONE = 3

// ── Heroes ──────────────────────────────────────────────────

export const HERO_NAMES = ['Alaric', 'Brynn', 'Cassiel'] as const

export const HERO_KEYS = ['hero-alaric', 'hero-brynn', 'hero-cassiel'] as const

export const HERO_RECRUIT_COSTS = [0, 8000, 20000] as const // x100 fixed-point

export const HERO_STATUS_IDLE = 0
export const HERO_STATUS_EXPLORING = 1
export const HERO_STATUS_RETURNING = 2

// ── Effects & Potions ───────────────────────────────────────

export const EFFECT_NAMES = ['Max HP', 'Power', 'Regen'] as const

export const EFFECT_COLORS = ['#d04050', '#4080d0', '#40c060'] as const

export const POTION_KEYS = ['potion-hp', 'potion-power', 'potion-regen', 'potion-soup'] as const

// Potion name generation (from alchemist)
export const POTION_ADJECTIVES = [
  'Luminous', 'Shadow', 'Crystal', 'Ember', 'Frost',
  'Void', 'Celestial', 'Ancient', 'Mystic', 'Storm',
  'Crimson', 'Azure', 'Golden', 'Silver', 'Verdant',
  'Obsidian', 'Ethereal', 'Arcane', 'Primal', 'Astral',
  'Infernal', 'Radiant', 'Twilight', 'Phantom', 'Spectral',
  'Abyssal', 'Divine', 'Feral', 'Molten', 'Glacial',
] as const

export const POTION_NOUNS = [
  'Elixir', 'Tonic', 'Brew', 'Draught', 'Philter',
  'Essence', 'Tincture', 'Serum', 'Nectar', 'Cordial',
  'Mixture', 'Solution', 'Potion', 'Balm', 'Salve',
  'Infusion', 'Concentrate', 'Decoction', 'Distillate', 'Remedy',
] as const

// ── Zone Depth Thresholds ───────────────────────────────────

export const ZONE_0_DEPTH = 0
export const ZONE_1_DEPTH = 20
export const ZONE_2_DEPTH = 45

export function getZoneForDepth(depth: number): number {
  if (depth >= ZONE_2_DEPTH) return 2
  if (depth >= ZONE_1_DEPTH) return 1
  return 0
}

export function getZoneForIngredient(ingredientId: number): number {
  return Math.floor(ingredientId / INGREDIENTS_PER_ZONE)
}

// ── Display Helpers ─────────────────────────────────────────

export function displayHp(hp: number): string {
  return (hp / 100).toFixed(0)
}

export function displayGold(gold: number): string {
  return (gold / 100).toFixed(0)
}

export function ingredientAssetUrl(ingredientId: number): string {
  return `/assets/ingredients/${INGREDIENT_KEYS[ingredientId]}.png`
}

export function heroAssetUrl(heroId: number): string {
  return `/assets/heroes/${HERO_KEYS[heroId]}.png`
}

export function potionAssetUrl(effectType: number): string {
  return `/assets/potions/${POTION_KEYS[effectType]}.png`
}

export function zoneBackgroundUrl(zoneId: number): string {
  return `/assets/backgrounds/${ZONE_BG_KEYS[zoneId]}.png`
}
