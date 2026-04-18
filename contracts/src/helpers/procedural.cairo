// Procedural room generation for Athanor:Ascend.
//
// Pure helpers that derive obstacles, enemy archetypes, and spawn positions
// deterministically from a single per-run seed + the current room_id. No store
// access here — callers (actions.cairo) write models based on these outputs.

use core::poseidon::poseidon_hash_span;

// Archetype constants must match athanor::systems::phase
pub const ARCH_BRUTE: u8 = 1;
pub const ARCH_CASTER: u8 = 2;
pub const ARCH_FLANKER: u8 = 3;
pub const ARCH_HEAVY: u8 = 4;
pub const ARCH_PULLER: u8 = 5;

/// Number of enemies to spawn in a room (capped at 8).
pub fn enemy_count(room_id: u8) -> u8 {
    if room_id <= 2 {
        3
    } else if room_id <= 5 {
        4
    } else if room_id <= 9 {
        5
    } else if room_id <= 13 {
        6
    } else if room_id <= 17 {
        7
    } else {
        8
    }
}

/// Number of static obstacles (capped at 16).
pub fn obstacle_count(room_id: u8) -> u8 {
    let n: u16 = 6 + room_id.into() / 2;
    if n > 16 {
        16
    } else {
        n.try_into().unwrap()
    }
}

#[inline]
fn manhattan_close(x1: u8, y1: u8, x2: u8, y2: u8) -> bool {
    let dx = if x1 > x2 {
        x1 - x2
    } else {
        x2 - x1
    };
    let dy = if y1 > y2 {
        y1 - y2
    } else {
        y2 - y1
    };
    dx <= 1 && dy <= 1
}

/// Deterministically pick obstacle tiles for a room. Respects the player entry
/// tile (and its 8-neighborhood) so the player never spawns inside an obstacle
/// or is boxed in at the start.
pub fn generate_blocked_bitmap(
    seed: felt252, room_id: u8, entry_x: u8, entry_y: u8,
) -> u64 {
    let count = obstacle_count(room_id);
    let mut blocked: u64 = 0;
    let mut placed: u8 = 0;
    let mut attempt: u32 = 0;
    let max_attempts: u32 = 200;

    while placed < count && attempt < max_attempts {
        let h = poseidon_hash_span(
            array![seed, room_id.into(), 'obst', attempt.into()].span(),
        );
        let v: u256 = h.into();
        let tile: u8 = (v.low % 64).try_into().unwrap();
        attempt += 1;

        let x: u8 = tile % 8;
        let y: u8 = tile / 8;

        if manhattan_close(x, y, entry_x, entry_y) {
            continue;
        }

        let bit: u64 = 1_u64 * pow2_u64(tile);
        if blocked & bit != 0 {
            continue;
        }

        blocked = blocked | bit;
        placed += 1;
    };

    blocked
}

/// Pick a valid spawn position for an enemy. Rejection-samples against the
/// blocked bitmap, current occupancy, the entry tile, and the entry corner
/// neighborhood (so enemies don't spawn on top of the player).
pub fn pick_enemy_position(
    seed: felt252,
    room_id: u8,
    slot_index: u8,
    blocked: u64,
    occupancy: u64,
    entry_x: u8,
    entry_y: u8,
) -> (u8, u8) {
    let mut attempt: u32 = 0;
    let max_attempts: u32 = 64;
    let occupied = blocked | occupancy;

    while attempt < max_attempts {
        let h = poseidon_hash_span(
            array![
                seed, room_id.into(), 'enemy', slot_index.into(), attempt.into(),
            ]
                .span(),
        );
        let v: u256 = h.into();
        let tile: u8 = (v.low % 64).try_into().unwrap();
        attempt += 1;

        let x: u8 = tile % 8;
        let y: u8 = tile / 8;

        if manhattan_close(x, y, entry_x, entry_y) {
            continue;
        }

        let bit: u64 = pow2_u64(tile);
        if occupied & bit != 0 {
            continue;
        }
        return (x, y);
    };

    // Fallback — give up and return (7, 7); caller treats as a warning. Since
    // the grid is 8x8 with 16 obstacles max and at most 8 enemies, there are
    // always ample free tiles in practice.
    (7, 7)
}

/// Uniform-weight archetype roll for step 6. Archetype tier-weights come in
/// step 7 (replaces this function).
pub fn roll_archetype(seed: felt252, room_id: u8, slot_index: u8) -> u8 {
    let h = poseidon_hash_span(
        array![seed, room_id.into(), 'arch', slot_index.into()].span(),
    );
    let v: u256 = h.into();
    let roll: u8 = (v.low % 5).try_into().unwrap();
    roll + 1
}

/// Base stats per archetype — (hp, offense, defense, speed, is_immovable).
/// No scaling here; step 7 layers stat_mult on top.
pub fn archetype_base_stats(archetype: u8) -> (u16, u8, u8, u8, bool) {
    if archetype == ARCH_BRUTE {
        (40, 15, 8, 5, false)
    } else if archetype == ARCH_CASTER {
        (25, 20, 3, 8, false)
    } else if archetype == ARCH_FLANKER {
        (40, 12, 4, 7, false)
    } else if archetype == ARCH_HEAVY {
        (70, 15, 10, 3, true)
    } else {
        (35, 0, 5, 6, false) // Puller (and fallback)
    }
}

fn pow2_u64(n: u8) -> u64 {
    let mut result: u64 = 1;
    let mut i: u8 = 0;
    while i < n {
        result = result * 2;
        i += 1;
    };
    result
}
