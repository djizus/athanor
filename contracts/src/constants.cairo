pub fn NAMESPACE() -> ByteArray {
    "ATHANOR"
}

pub fn DEFAULT_NS() -> ByteArray {
    "ATHANOR"
}

pub const DEFAULT_HINT_PRICE: u32 = 4;
pub const DEFAULT_RECIPE_COUNT: u8 = 30;
pub const DEFAULT_INGREDIENT_COUNT: u8 = 10;

// --- Zone configuration ---

pub const ZONE_COUNT: u8 = 3;
pub const INGREDIENTS_PER_ZONE: u8 = 3;
pub const TOTAL_INGREDIENTS: u8 = 9;
pub const RECIPES_TO_DISCOVER: u8 = 10;
// C(9, 2) = 9 * 8 / 2 = 36 unique sorted pairs
pub const TOTAL_COMBOS: u16 = 36;

// Zone 0: Verdant Meadow
pub const ZONE_0_DEPTH: u16 = 0;
pub const ZONE_0_DRAIN: u16 = 100; // 1.00 HP/s (x100)

// Zone 1: Crystal Cavern
pub const ZONE_1_DEPTH: u16 = 20;
pub const ZONE_1_DRAIN: u16 = 200; // 2.00 HP/s (x100)

// Zone 2: Aether Spire
pub const ZONE_2_DEPTH: u16 = 45;
pub const ZONE_2_DRAIN: u16 = 300; // 3.00 HP/s (x100)

// --- Hero configuration ---

pub const MAX_HEROES: u8 = 3;
pub const HERO_BASE_HP: u16 = 10000; // 100.00 HP (x100 fixed-point)
pub const HERO_BASE_POWER: u16 = 500; // 5.00 (x100)
pub const HERO_BASE_REGEN: u16 = 100; // 1.00 HP/s (x100)

pub const HERO_COST_0: u32 = 0;
pub const HERO_COST_1: u32 = 8000; // 80.00 gold (x100)
pub const HERO_COST_2: u32 = 20000; // 200.00 gold (x100)

// --- Crafting ---

pub const HINT_BASE_COST: u16 = 1000; // 10.00 gold (x100)
pub const HINT_COST_MULTIPLIER: u8 = 3;
pub const SOUP_GOLD_VALUE: u8 = 1;
pub const PROGRESSIVE_CAP: u16 = 8000; // 0.80 (x10000)

// --- Event probabilities (x10000) ---
//                          Trap   Gold   Heal   Beast  Drop
// Zone 0 (Meadow):         500   1000    800    300   2500
// Zone 1 (Cavern):        1000    700    500    700   1800
// Zone 2 (Spire):         1400    500    300   1200   1200

pub const ZONE_0_TRAP: u16 = 500;
pub const ZONE_0_GOLD: u16 = 1000;
pub const ZONE_0_HEAL: u16 = 800;
pub const ZONE_0_BEAST: u16 = 300;
pub const ZONE_0_DROP: u16 = 2500;

pub const ZONE_1_TRAP: u16 = 1000;
pub const ZONE_1_GOLD: u16 = 700;
pub const ZONE_1_HEAL: u16 = 500;
pub const ZONE_1_BEAST: u16 = 700;
pub const ZONE_1_DROP: u16 = 1800;

pub const ZONE_2_TRAP: u16 = 1400;
pub const ZONE_2_GOLD: u16 = 500;
pub const ZONE_2_HEAL: u16 = 300;
pub const ZONE_2_BEAST: u16 = 1200;
pub const ZONE_2_DROP: u16 = 1200;
