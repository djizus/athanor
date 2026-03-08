export const DEFAULT_ZONE_COUNT = 5
export const DEFAULT_INGREDIENTS_PER_ZONE = 5
export const DEFAULT_TOTAL_INGREDIENTS = 25
export const DEFAULT_TOTAL_EFFECTS = 30
export const DEFAULT_MAX_HEROES = 3

export const ZONE_NAMES = [
  'Amber Hollows', 'Ember Cavern', 'Aether Spire', 'Sunken Abyss', 'Crystalveil Reach',
] as const

export const ZONE_COLORS = ['#c8a040', '#b85030', '#9e4a9e', '#4a90d9', '#2a8a6a'] as const

export const ZONE_BG_KEYS = [
  'zone-hollows', 'zone-cavern', 'zone-spire', 'zone-abyss', 'zone-crystalveil',
] as const

export const INGREDIENT_NAMES = [
  'Amber Sap', 'Copper Dust', 'Fog Essence', 'Iron Filing', 'Moonpetal',
  'Nightberry', 'Crystal Shard', 'Drake Moss', 'Sulfur Bloom', 'Dragon Scale',
  'Aether Core', 'Titan Blood', 'Void Salt', 'Aether Bloom', 'Star Dust',
  'Cave Pearl', 'River Clay', 'Echo Moss', 'Dripstone', 'Starfall',
  'Echoleaf', 'Crystalbloom', 'Feather', 'Frostbloom', 'Gemstone',
] as const

export const INGREDIENT_KEYS = [
  'amber-sap', 'copper-dust', 'fog-essence', 'iron-filing', 'moonpetal',
  'nightberry', 'crystal-shard', 'drake-moss', 'sulfur-bloom', 'dragon-scale',
  'aether-core', 'titan-blood', 'void-salt', 'aether-bloom', 'star-dust',
  'cave-pearl', 'river-clay', 'echo-moss', 'dripstone', 'starfall',
  'echoleaf', 'crystalbloom', 'feather', 'frostbloom', 'gemstone',
] as const

export const EFFECT_NAMES = [
  'Blue', 'Green', 'Red', 'Yellow', 'Purple',
  'Orange', 'Pink', 'Brown', 'Gray', 'Black',
  'White', 'Cyan', 'Magenta', 'Lime', 'Teal',
  'Maroon', 'Navy', 'Indigo', 'Violet', 'Gold',
  'Silver', 'Copper', 'Mauve', 'Ruby', 'Sapphire',
  'Emerald', 'Diamond', 'Amethyst', 'Topaz', 'Aquamarine',
] as const

export const EFFECT_CATEGORIES = [
  'health', 'health', 'health', 'health', 'health',
  'health', 'health', 'health', 'health', 'health',
  'power', 'power', 'power', 'power', 'power',
  'power', 'power', 'power', 'power', 'power',
  'regen', 'regen', 'regen', 'regen', 'regen',
  'regen', 'regen', 'regen', 'regen', 'regen',
] as const

export const EFFECT_COLORS: Record<string, string> = {
  health: '#d04050',
  power: '#4080d0',
  regen: '#40c060',
}

export const ROLE_NAMES = ['Mage', 'Rogue', 'Warrior'] as const

export const ROLE_KEYS = ['role-mage', 'role-rogue', 'role-warrior'] as const

export const ROLE_STATS = [
  { maxHealth: 50, power: 20, regen: 1 },
  { maxHealth: 100, power: 5, regen: 5 },
  { maxHealth: 150, power: 5, regen: 2 },
] as const

export const HERO_RECRUIT_COSTS = [0, 80, 200] as const

export const EFFECT_MULTIPLIERS = [
  5, 5, 5, 10, 10, 10, 15, 15, 15, 20,
  1, 1, 1, 2, 2, 3, 3, 4, 4, 5,
  1, 1, 1, 1, 2, 2, 2, 2, 3, 3,
] as const

export function effectStatLabel(effectIdx: number): string {
  const mult = EFFECT_MULTIPLIERS[effectIdx]
  const cat = EFFECT_CATEGORIES[effectIdx]
  if (cat === 'health') return `+${mult} HP`
  if (cat === 'power') return `+${mult} PWR`
  if (cat === 'regen') return `+${mult}/s`
  return ''
}

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

export function getZoneForIngredient(ingredientId: number, ingredientsPerZone = DEFAULT_INGREDIENTS_PER_ZONE): number {
  return Math.floor(ingredientId / ingredientsPerZone)
}

export function displayHp(hp: number): string {
  return String(hp)
}

export function displayGold(gold: number): string {
  return String(gold)
}

export function ingredientAssetUrl(ingredientId: number): string {
  return `/assets/ingredients/${INGREDIENT_KEYS[ingredientId]}.webp`
}

export function roleAssetUrl(roleIndex: number): string {
  return `/assets/heroes/${ROLE_KEYS[roleIndex]}.webp`
}

export function effectAssetUrl(effectIndex: number): string {
  const category = EFFECT_CATEGORIES[effectIndex]
  return `/assets/potions/potion-${category}.webp`
}

export function zoneBackgroundUrl(zoneId: number): string {
  return `/assets/backgrounds/${ZONE_BG_KEYS[zoneId]}.png`
}

/**
 * Convert a felt252 game ID (bigint) to a short, human-friendly display string.
 * Small IDs (<=99999) are shown as-is. Larger felt252 IDs are hashed into a
 * 5-digit decimal number (10000–99999) via FNV-1a.
 */
export function formatGameId(id: bigint | number): string {
  const n = BigInt(id)
  if (n <= 99999n) return String(Number(n))
  const hex = n.toString(16)
  let hash = 0x811c9dc5 // FNV-1a offset basis
  for (let i = 0; i < hex.length; i++) {
    hash ^= hex.charCodeAt(i)
    hash = Math.imul(hash, 0x01000193) // FNV prime
  }
  return String(((hash >>> 0) % 89999) + 10000)
}
