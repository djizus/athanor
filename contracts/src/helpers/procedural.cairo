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

/// Tier band for a given room. Tiers shape archetype weight tables and stat
/// multipliers below.
pub fn room_tier(room_id: u8) -> u8 {
    if room_id <= 2 {
        0
    } else if room_id <= 6 {
        1
    } else if room_id <= 11 {
        2
    } else if room_id <= 17 {
        3
    } else {
        4
    }
}

/// Weights for (Brute, Caster, Flanker, Heavy, Puller) — always sum to 100.
/// Tier 0 shelters the player from Heavy/Puller; tier 4 is mean-heavy.
pub fn archetype_weights(tier: u8) -> (u8, u8, u8, u8, u8) {
    if tier == 0 {
        (60, 30, 10, 0, 0)
    } else if tier == 1 {
        (40, 25, 20, 15, 0)
    } else if tier == 2 {
        (25, 20, 25, 15, 15)
    } else if tier == 3 {
        (15, 20, 25, 20, 20)
    } else {
        (10, 15, 25, 25, 25)
    }
}

fn weighted_pick(roll: u8, wb: u8, wc: u8, wf: u8, wh: u8, wp: u8) -> u8 {
    let _ = wp;
    if roll < wb {
        ARCH_BRUTE
    } else if roll < wb + wc {
        ARCH_CASTER
    } else if roll < wb + wc + wf {
        ARCH_FLANKER
    } else if roll < wb + wc + wf + wh {
        ARCH_HEAVY
    } else {
        ARCH_PULLER
    }
}

/// Roll an archetype honoring the tier weight table and per-room caps:
/// at most 2 Pullers and 2 Heavies per room. Rerolls with a rotated seed up
/// to 3 times; falls back to Brute if the caps consistently win.
pub fn roll_archetype_capped(
    seed: felt252,
    room_id: u8,
    slot_index: u8,
    pullers_so_far: u8,
    heavies_so_far: u8,
) -> u8 {
    let tier = room_tier(room_id);
    let (wb, wc, wf, wh, wp) = archetype_weights(tier);

    let mut attempt: u32 = 0;
    let mut result: u8 = ARCH_BRUTE;
    let mut decided: bool = false;
    while attempt < 4 && !decided {
        let h = poseidon_hash_span(
            array![
                seed, room_id.into(), 'arch', slot_index.into(), attempt.into(),
            ]
                .span(),
        );
        let v: u256 = h.into();
        let roll: u8 = (v.low % 100).try_into().unwrap();
        let candidate = weighted_pick(roll, wb, wc, wf, wh, wp);
        let reject = (candidate == ARCH_PULLER && pullers_so_far >= 2)
            || (candidate == ARCH_HEAVY && heavies_so_far >= 2);
        if !reject {
            result = candidate;
            decided = true;
        } else {
            attempt += 1;
        };
    };
    result
}

/// Unscaled base stats — (hp, offense, defense, speed, is_immovable).
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

/// Piecewise stat multiplier as a percentage (100 = 1.00x baseline). Hits
/// 220% by room 5, 390% by room 10, 610% by room 15, then +60% per room past
/// room 17 (unbounded — endless).
pub fn stat_mult(room_id: u8) -> u16 {
    let r: u16 = room_id.into();
    if room_id <= 2 {
        100 + r * 15
    } else if room_id <= 6 {
        145 + (r - 2) * 25
    } else if room_id <= 11 {
        270 + (r - 6) * 30
    } else if room_id <= 17 {
        450 + (r - 11) * 40
    } else {
        690 + (r - 17) * 60
    }
}

/// Scaled base stats for an archetype at a given room. HP and offense scale
/// by stat_mult; defense / speed / immovable are unchanged (preserves combat
/// identity — only the "meat" of the enemy grows, not its movement profile).
pub fn scaled_archetype_stats(archetype: u8, room_id: u8) -> (u16, u8, u8, u8, bool) {
    let (base_hp, base_off, def, speed, immovable) = archetype_base_stats(archetype);
    let mult: u16 = stat_mult(room_id);

    let hp_u32: u32 = base_hp.into() * mult.into() / 100;
    let scaled_hp: u16 = if hp_u32 > 65535 {
        65535
    } else {
        hp_u32.try_into().unwrap()
    };

    let off_u32: u32 = base_off.into() * mult.into() / 100;
    let scaled_off: u8 = if off_u32 > 255 {
        255
    } else {
        off_u32.try_into().unwrap()
    };

    (scaled_hp, scaled_off, def, speed, immovable)
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
