pub fn NAMESPACE() -> ByteArray {
    "ATHANOR"
}

// --- Default values ---
pub const DEFAULT_INGREDIENTS: felt252 =
    0x1004010040100401004010040100401004010040100401004010040100401; // 1 of each ingredient
pub const ENOUGH_INGREDIENTS: felt252 =
    0x18060180601806018060180601806018060180601806018060180601806018; // 24 of each ingredient
pub const DEFAULT_HINT_COST: u32 = 10;
pub const DEFAULT_HINT_MULTIPLIER: u8 = 3;
pub const DEFAULT_MAX_HEROES: u8 = 3;
pub const DEFAULT_RECIPE_COUNT: u8 = 30;
pub const DEFAULT_INGREDIENT_COUNT: u8 = 10;
pub const DEFAULT_HERO_COSTS: [u32; 3] = [0, 80, 200];
pub const TIME_TOLERANCE: u64 = 5;

// --- Zone configuration ---

pub const ZONE_COUNT: u8 = 5;
pub const INGREDIENTS_PER_ZONE: u8 = 5;
pub const TOTAL_INGREDIENTS: u8 = 25;
pub const RECIPES_TO_DISCOVER: u8 = 30;
// C(9, 2) = 9 * 8 / 2 = 36 unique sorted pairs
pub const TOTAL_COMBOS: u16 = 36;

// Zone 0: Amber Hollows
pub const ZONE_0_DEPTH: u16 = 0;
pub const ZONE_0_DRAIN: u16 = 100; // 1.00 HP/s (x100)

// Zone 1: Ember Cavern
pub const ZONE_1_DEPTH: u16 = 20;
pub const ZONE_1_DRAIN: u16 = 200; // 2.00 HP/s (x100)

// Zone 2: Aether Spire
pub const ZONE_2_DEPTH: u16 = 40;
pub const ZONE_2_DRAIN: u16 = 300; // 3.00 HP/s (x100)

// Zone 3: Sunken Abyss
pub const ZONE_3_DEPTH: u16 = 60;
pub const ZONE_3_DRAIN: u16 = 400; // 4.00 HP/s (x100)

// Zone 4: Crystalveil Reach
pub const ZONE_4_DEPTH: u16 = 90;
pub const ZONE_4_DRAIN: u16 = 500; // 5.00 HP/s (x100)

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
pub const SOUP_GOLD_VALUE: u8 = 1;
pub const PROGRESSIVE_CAP: u16 = 8000; // 0.80 (x10000)

// --- Event probabilities (x10000) ---
//                          Trap   Gold   Heal   Beast  Drop
// Zone 0 (Hollows):        500   1000    800    300   2500
// Zone 1 (Ember):          750    850    650    500   2150
// Zone 2 (Spire):         1000    700    500    700   1800
// Zone 3 (Abyss):         1200    600    400    950   1500
// Zone 4 (Crystalveil):   1400    500    300    1200  1200

pub const ZONE_0_TRAP: u16 = 500;
pub const ZONE_0_GOLD: u16 = 1000;
pub const ZONE_0_HEAL: u16 = 800;
pub const ZONE_0_BEAST: u16 = 300;
pub const ZONE_0_DROP: u16 = 2500;

pub const ZONE_1_TRAP: u16 = 750;
pub const ZONE_1_GOLD: u16 = 850;
pub const ZONE_1_HEAL: u16 = 650;
pub const ZONE_1_BEAST: u16 = 500;
pub const ZONE_1_DROP: u16 = 2150;

pub const ZONE_2_TRAP: u16 = 1000;
pub const ZONE_2_GOLD: u16 = 700;
pub const ZONE_2_HEAL: u16 = 500;
pub const ZONE_2_BEAST: u16 = 700;
pub const ZONE_2_DROP: u16 = 1800;

pub const ZONE_3_TRAP: u16 = 1200;
pub const ZONE_3_GOLD: u16 = 600;
pub const ZONE_3_HEAL: u16 = 400;
pub const ZONE_3_BEAST: u16 = 950;
pub const ZONE_3_DROP: u16 = 1500;

pub const ZONE_4_TRAP: u16 = 1400;
pub const ZONE_4_GOLD: u16 = 500;
pub const ZONE_4_HEAL: u16 = 300;
pub const ZONE_4_BEAST: u16 = 1200;
pub const ZONE_4_DROP: u16 = 1200;
