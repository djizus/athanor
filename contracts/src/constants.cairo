// --- Player defaults ---
pub const MAX_HEALTH: u16 = 100;
pub const MAX_STAMINA: u16 = 100;
pub const POWER: u16 = 10;

// --- Mob defaults ---
pub const MOB_HEALTH: u16 = 20;
pub const MOB_POWER: u16 = 5;

// --- Skill costs ---
pub const AA_COST: u16 = 30;

// --- Dungeon ---
pub const ZONE_COUNT: u8 = 5;
pub const NO_EXIT: u8 = 0xFF;

/// Returns the number of mobs in a given zone.
pub fn zone_mob_count(zone_id: u8) -> u8 {
    match zone_id {
        0 => 0, // Spawn
        1 => 1,
        2 => 1,
        3 => 2,
        4 => 4, // Final
        _ => 0,
    }
}

/// Returns (left_child, right_child) for a zone.
/// NO_EXIT (0xFF) means no child in that direction.
pub fn zone_children(zone_id: u8) -> (u8, u8) {
    match zone_id {
        0 => (1, 2),           // Fork: player chooses
        1 => (3, NO_EXIT),     // Single exit: auto-advance
        2 => (3, NO_EXIT),     // Single exit: auto-advance
        3 => (4, NO_EXIT),     // Single exit: auto-advance
        _ => (NO_EXIT, NO_EXIT), // Terminal or invalid
    }
}

/// Returns true if the zone is a fork (two valid exits).
pub fn is_fork(zone_id: u8) -> bool {
    let (left, right) = zone_children(zone_id);
    left != NO_EXIT && right != NO_EXIT && left != right
}

/// Returns true if the zone has a single exit.
pub fn has_single_exit(zone_id: u8) -> bool {
    let (left, right) = zone_children(zone_id);
    left != NO_EXIT && right == NO_EXIT
}
