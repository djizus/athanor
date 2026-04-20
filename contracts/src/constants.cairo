pub const GRID_WIDTH: u8 = 8;
pub const GRID_HEIGHT: u8 = 8;

pub const MOVE_COST_PER_TILE: u8 = 10;

pub const STRIKE_COST: u16 = 20;
pub const STRIKE_COOLDOWN: u8 = 0;
pub const STRIKE_DAMAGE: u16 = 15;

pub const DASH_COST: u16 = 20;
pub const DASH_COOLDOWN: u8 = 1;
pub const DASH_DAMAGE: u16 = 10;

pub const HEAL_COST: u16 = 25;
pub const HEAL_COOLDOWN: u8 = 3;
pub const HEAL_AMOUNT: u16 = 20;

pub const SHOVE_COST: u16 = 20;
pub const SHOVE_COOLDOWN: u8 = 1;
pub const SHOVE_DAMAGE: u16 = 5;
pub const SHOVE_PUSH_DISTANCE: u8 = 2;

pub const SLAM_COST: u16 = 35;
pub const SLAM_COOLDOWN: u8 = 2;
pub const SLAM_DAMAGE: u16 = 10;
pub const SLAM_PUSH_DISTANCE: u8 = 1;

pub const ORB_STAMINA_BONUS: u16 = 20;
pub const ORB_HP_BONUS: u16 = 10;
pub const STAMINA_DRAIN_AMOUNT: u16 = 20;

// HERO_HP removed: hero HP now comes from GameSettings.hero_hp (see
// models::config) so the single-source-of-truth for mode balance is the
// settings row written at deploy time.
pub const HERO_OFFENSE: u8 = 20;
pub const HERO_DEFENSE: u8 = 5;
pub const HERO_SPEED: u8 = 10;

// Archetype base HP — POC cuts so every ability lands meaningfully.
// Keep in sync with helpers::procedural::archetype_base_stats.
pub const BRUTE_HP: u16 = 30;
pub const BRUTE_OFFENSE: u8 = 15;
pub const BRUTE_DEFENSE: u8 = 8;
pub const BRUTE_SPEED: u8 = 5;

pub const CASTER_HP: u16 = 20;
pub const CASTER_OFFENSE: u8 = 20;
pub const CASTER_DEFENSE: u8 = 3;
pub const CASTER_SPEED: u8 = 8;

pub const FLANKER_HP: u16 = 25;
pub const FLANKER_OFFENSE: u8 = 12;
pub const FLANKER_DEFENSE: u8 = 4;
pub const FLANKER_SPEED: u8 = 7;

pub const HEAVY_HP: u16 = 45;
pub const HEAVY_OFFENSE: u8 = 15;
pub const HEAVY_DEFENSE: u8 = 10;
pub const HEAVY_SPEED: u8 = 3;

pub const PULLER_HP: u16 = 22;
pub const PULLER_OFFENSE: u8 = 0;
pub const PULLER_DEFENSE: u8 = 5;
pub const PULLER_SPEED: u8 = 6;

pub const DRAINER_HP: u16 = 22;
// Drainer telegraph subtracts STAMINA_DRAIN_AMOUNT from the player on resolve.
// No HP damage: it's a distinct threat type.
pub const DRAINER_OFFENSE: u8 = 0;
pub const DRAINER_DEFENSE: u8 = 4;
pub const DRAINER_SPEED: u8 = 6;
