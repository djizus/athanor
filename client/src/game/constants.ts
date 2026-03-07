export const ZONE_COUNT = 5
export const INGREDIENTS_PER_ZONE = 5
export const TOTAL_INGREDIENTS = 25
export const TOTAL_EFFECTS = 30
export const MAX_HEROES = 3

export const ZONE_NAMES = [
  'Amber Hollows', 'Ember Cavern', 'Aether Spire', 'Sunken Abyss', 'Crystalveil Reach',
] as const

export const ZONE_COLORS = ['#c8a040', '#b85030', '#9e4a9e', '#2a5a8a', '#2a8a6a'] as const

export const ZONE_BG_KEYS = [
  'zone-hollows', 'zone-cavern', 'zone-spire', 'zone-abyss', 'zone-crystalveil',
] as const

export const ZONE_DEPTHS = [0, 20, 40, 60, 90] as const

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

export function getZoneForDepth(depth: number): number {
  for (let i = ZONE_DEPTHS.length - 1; i >= 0; i--) {
    if (depth >= ZONE_DEPTHS[i]) return i
  }
  return 0
}

export function getZoneForIngredient(ingredientId: number): number {
  return Math.floor(ingredientId / INGREDIENTS_PER_ZONE)
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
