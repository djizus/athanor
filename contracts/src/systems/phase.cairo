pub const PHASE_EXPLORE: u8 = 0;
pub const PHASE_PLAYER_TURN: u8 = 1;
pub const PHASE_ENEMY_TURN: u8 = 2;
pub const PHASE_COMPLETE: u8 = 3;
pub const PHASE_FAILED: u8 = 4;
pub const PHASE_GAME_OVER: u8 = 5;

pub const FACTION_PLAYER: u8 = 0;
pub const FACTION_ENEMY: u8 = 1;

pub const ARCHETYPE_HERO: u8 = 0;
pub const ARCHETYPE_BRUTE: u8 = 1;
pub const ARCHETYPE_CASTER: u8 = 2;
pub const ARCHETYPE_FLANKER: u8 = 3;
pub const ARCHETYPE_HEAVY: u8 = 4;
pub const ARCHETYPE_PULLER: u8 = 5;
// Drainer: telegraphs a 3x3 STAMINA_DRAIN zone on the player. No HP damage,
// but siphons stamina on resolve. Fits in the 3-bit packed archetype field.
pub const ARCHETYPE_DRAINER: u8 = 6;
// Marksman: ranged single-tile shot on the player's location if a clear
// cardinal lane exists. Obstacles block the shot.
pub const ARCHETYPE_MARKSMAN: u8 = 7;

pub const ABILITY_STRIKE: u8 = 0;
pub const ABILITY_DASH: u8 = 1;
pub const ABILITY_HEAL: u8 = 2;
pub const ABILITY_SHOVE: u8 = 3;
pub const ABILITY_SLAM: u8 = 4;

pub const TARGET_SINGLE: u8 = 0;
pub const TARGET_DIRECTIONAL: u8 = 1;
pub const TARGET_POSITIONAL: u8 = 2;
pub const TARGET_SELF: u8 = 3;

pub const SHAPE_SINGLE_TILE: u8 = 0;
pub const SHAPE_LINE: u8 = 1;
pub const SHAPE_CONE: u8 = 2;
pub const SHAPE_CIRCLE: u8 = 3;
pub const SHAPE_CROSS: u8 = 4;

pub const TELEGRAPH_TYPE_DAMAGE: u8 = 0;
pub const TELEGRAPH_TYPE_PULL: u8 = 1;
// Drainer telegraph: subtracts stamina from any player inside the zone on
// resolve. Packed into 2 bits alongside DAMAGE/PULL (see telegraph_state).
pub const TELEGRAPH_TYPE_STAMINA_DRAIN: u8 = 2;
