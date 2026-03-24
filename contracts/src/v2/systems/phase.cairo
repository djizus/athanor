pub const PHASE_EXPLORE: u8 = 0;
pub const PHASE_PLAYER_TURN: u8 = 1;
pub const PHASE_ENEMY_TURN: u8 = 2;
pub const PHASE_COMPLETE: u8 = 3;
pub const PHASE_FAILED: u8 = 4;

pub const FACTION_PLAYER: u8 = 0;
pub const FACTION_ENEMY: u8 = 1;

pub const ARCHETYPE_HERO: u8 = 0;
pub const ARCHETYPE_BRUTE: u8 = 1;
pub const ARCHETYPE_CASTER: u8 = 2;

pub const ABILITY_STRIKE: u8 = 0;
pub const ABILITY_DASH: u8 = 1;
pub const ABILITY_CLEAVE: u8 = 2;
pub const ABILITY_FIREBALL: u8 = 3;
pub const ABILITY_GUARD: u8 = 4;

pub const TARGET_SINGLE: u8 = 0;
pub const TARGET_DIRECTIONAL: u8 = 1;
pub const TARGET_POSITIONAL: u8 = 2;
pub const TARGET_SELF: u8 = 3;

pub const SHAPE_SINGLE_TILE: u8 = 0;
pub const SHAPE_LINE: u8 = 1;
pub const SHAPE_CONE: u8 = 2;
pub const SHAPE_CIRCLE: u8 = 3;
