// Hero status: 0=Idle, 1=Exploring, 2=Returning
pub const HERO_STATUS_IDLE: u8 = 0;
pub const HERO_STATUS_EXPLORING: u8 = 1;
pub const HERO_STATUS_RETURNING: u8 = 2;

// Event kinds for ExplorationEvent
pub const EVENT_NOTHING: u8 = 0;
pub const EVENT_TRAP: u8 = 1;
pub const EVENT_GOLD: u8 = 2;
pub const EVENT_HEAL: u8 = 3;
pub const EVENT_BEAST_WIN: u8 = 4;
pub const EVENT_BEAST_LOSE: u8 = 5;
pub const EVENT_INGREDIENT: u8 = 6;

// Effect types for potions/recipes
pub const EFFECT_MAX_HP: u8 = 0;
pub const EFFECT_POWER: u8 = 1;
pub const EFFECT_REGEN: u8 = 2;
