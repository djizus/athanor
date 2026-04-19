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

#[cfg(test)]
mod tests {
    use super::{
        ARCH_BRUTE, ARCH_CASTER, ARCH_FLANKER, ARCH_HEAVY, ARCH_PULLER, archetype_base_stats,
        archetype_weights, enemy_count, obstacle_count, room_tier,
        roll_archetype_capped, scaled_archetype_stats, stat_mult,
    };

    // --- stat_mult curve ---

    #[test]
    fn test_stat_mult_table() {
        // Reference values from the design doc.
        assert!(stat_mult(0) == 100, "room 0");
        assert!(stat_mult(2) == 130, "room 2");
        assert!(stat_mult(3) == 170, "room 3");
        assert!(stat_mult(5) == 220, "room 5");
        assert!(stat_mult(6) == 245, "room 6");
        assert!(stat_mult(7) == 300, "room 7");
        assert!(stat_mult(10) == 390, "room 10");
        assert!(stat_mult(11) == 420, "room 11");
        assert!(stat_mult(12) == 490, "room 12");
        assert!(stat_mult(15) == 610, "room 15");
        assert!(stat_mult(17) == 690, "room 17");
        assert!(stat_mult(18) == 750, "room 18");
        assert!(stat_mult(20) == 870, "room 20");
    }

    #[test]
    fn test_stat_mult_monotonic() {
        // Ramp must be strictly increasing.
        let mut prev: u16 = 0;
        let mut r: u8 = 0;
        while r < 25 {
            let current = stat_mult(r);
            assert!(current > prev, "stat_mult not monotonic");
            prev = current;
            r += 1;
        };
    }

    // --- enemy_count ---

    #[test]
    fn test_enemy_count_bands() {
        assert!(enemy_count(0) == 3, "room 0");
        assert!(enemy_count(2) == 3, "room 2");
        assert!(enemy_count(3) == 4, "room 3");
        assert!(enemy_count(5) == 4, "room 5");
        assert!(enemy_count(6) == 5, "room 6");
        assert!(enemy_count(9) == 5, "room 9");
        assert!(enemy_count(10) == 6, "room 10");
        assert!(enemy_count(13) == 6, "room 13");
        assert!(enemy_count(14) == 7, "room 14");
        assert!(enemy_count(17) == 7, "room 17");
        assert!(enemy_count(18) == 8, "room 18");
        assert!(enemy_count(100) == 8, "room 100 capped");
    }

    // --- obstacle_count ---

    #[test]
    fn test_obstacle_count() {
        assert!(obstacle_count(0) == 6, "room 0");
        assert!(obstacle_count(4) == 8, "room 4");
        assert!(obstacle_count(10) == 11, "room 10");
        assert!(obstacle_count(20) == 16, "room 20 at cap");
        assert!(obstacle_count(100) == 16, "room 100 capped");
    }

    // --- tier bands ---

    #[test]
    fn test_room_tier_bands() {
        assert!(room_tier(0) == 0 && room_tier(2) == 0, "tier 0");
        assert!(room_tier(3) == 1 && room_tier(6) == 1, "tier 1");
        assert!(room_tier(7) == 2 && room_tier(11) == 2, "tier 2");
        assert!(room_tier(12) == 3 && room_tier(17) == 3, "tier 3");
        assert!(room_tier(18) == 4 && room_tier(100) == 4, "tier 4");
    }

    // --- archetype weights sum to 100 ---

    #[test]
    fn test_archetype_weights_sum_to_100() {
        let mut tier: u8 = 0;
        while tier < 5 {
            let (b, c, f, h, p) = archetype_weights(tier);
            let sum: u16 = b.into() + c.into() + f.into() + h.into() + p.into();
            assert!(sum == 100, "weights don't sum to 100");
            tier += 1;
        };
    }

    #[test]
    fn test_archetype_weights_tier_0_no_hard_archetypes() {
        // Tier 0 must shield the player from Heavy + Puller while they learn.
        let (_b, _c, _f, h, p) = archetype_weights(0);
        assert!(h == 0, "tier 0 Heavy weight");
        assert!(p == 0, "tier 0 Puller weight");
    }

    #[test]
    fn test_archetype_weights_tier_1_no_puller() {
        // Tier 1 introduces Heavy, Puller still absent.
        let (_b, _c, _f, h, p) = archetype_weights(1);
        assert!(h > 0, "tier 1 Heavy present");
        assert!(p == 0, "tier 1 Puller still absent");
    }

    // --- roll_archetype_capped honors caps ---

    #[test]
    fn test_roll_archetype_capped_respects_puller_cap() {
        // If we've already placed 2 Pullers this room, rolling again at
        // high-tier seeds must NOT return another Puller.
        let seed: felt252 = 'test_seed';
        let mut slot: u8 = 0;
        while slot < 20 {
            let result = roll_archetype_capped(seed, 20, slot, 2, 0);
            assert!(result != ARCH_PULLER, "rolled Puller despite cap");
            slot += 1;
        };
    }

    #[test]
    fn test_roll_archetype_capped_respects_heavy_cap() {
        let seed: felt252 = 'test_seed';
        let mut slot: u8 = 0;
        while slot < 20 {
            let result = roll_archetype_capped(seed, 20, slot, 0, 2);
            assert!(result != ARCH_HEAVY, "rolled Heavy despite cap");
            slot += 1;
        };
    }

    // --- archetype_base_stats covers all 5 ---

    #[test]
    fn test_archetype_base_stats_all() {
        let (brute_hp, _, _, brute_speed, brute_im) = archetype_base_stats(ARCH_BRUTE);
        assert!(brute_hp == 40 && brute_speed == 5 && !brute_im, "brute");

        let (caster_hp, _, _, caster_speed, _) = archetype_base_stats(ARCH_CASTER);
        assert!(caster_hp == 25 && caster_speed == 8, "caster");

        let (flanker_hp, _, _, flanker_speed, _) = archetype_base_stats(ARCH_FLANKER);
        assert!(flanker_hp == 40 && flanker_speed == 7, "flanker");

        let (heavy_hp, _, heavy_def, _, heavy_im) = archetype_base_stats(ARCH_HEAVY);
        assert!(heavy_hp == 70 && heavy_def == 10 && heavy_im, "heavy immovable");

        let (puller_hp, puller_off, _, _, _) = archetype_base_stats(ARCH_PULLER);
        assert!(puller_hp == 35 && puller_off == 0, "puller zero offense");
    }

    // --- scaled_archetype_stats — hp and offense scale, others don't ---

    #[test]
    fn test_scaled_stats_preserves_identity() {
        // defense/speed/immovable must NOT scale with room.
        let (_, _, def0, sp0, im0) = scaled_archetype_stats(ARCH_HEAVY, 0);
        let (_, _, def20, sp20, im20) = scaled_archetype_stats(ARCH_HEAVY, 20);
        assert!(def0 == def20, "defense scaled (bug)");
        assert!(sp0 == sp20, "speed scaled (bug)");
        assert!(im0 == im20, "immovable scaled (bug)");
        assert!(im0, "Heavy should stay immovable");
    }

    #[test]
    fn test_scaled_stats_hp_offense_at_room_15() {
        // Brute @ room 15: stat_mult = 610% → hp=244, offense=91.
        let (hp, off, _, _, _) = scaled_archetype_stats(ARCH_BRUTE, 15);
        assert!(hp == 244, "brute hp room 15");
        assert!(off == 91, "brute offense room 15");
    }

    #[test]
    fn test_scaled_stats_offense_u8_cap() {
        // Puller has 0 base offense → stays 0 at any room.
        let (_, off, _, _, _) = scaled_archetype_stats(ARCH_PULLER, 50);
        assert!(off == 0, "puller offense stays 0");

        // Caster @ room 50: stat_mult = 690 + 33*60 = 2670, offense = 20 * 2670 / 100 = 534 → clamped to 255.
        let (_, caster_off, _, _, _) = scaled_archetype_stats(ARCH_CASTER, 50);
        assert!(caster_off == 255, "offense clamped at u8 max");
    }

    // --- generate_blocked_bitmap sanity ---

    use super::{generate_blocked_bitmap, pick_enemy_position};
    use athanor::helpers::bitmap;

    fn popcount_u64(mut b: u64) -> u8 {
        let mut count: u8 = 0;
        while b != 0 {
            if b & 1 == 1 {
                count += 1;
            };
            b = b / 2;
        };
        count
    }

    #[test]
    fn test_generate_blocked_bitmap_respects_entry() {
        // Entry (1, 1) and its 8-neighborhood must never be blocked.
        let seed: felt252 = 'stress_obst';
        let mut room_id: u8 = 0;
        while room_id < 20 {
            let bitmap = generate_blocked_bitmap(seed, room_id, 1, 1);
            // 8-neighborhood of (1,1): (0,0)..(2,2)
            let mut dx: u8 = 0;
            while dx < 3 {
                let mut dy: u8 = 0;
                while dy < 3 {
                    assert!(
                        !bitmap::get_bit(bitmap, dx, dy),
                        "obstacle placed near spawn",
                    );
                    dy += 1;
                };
                dx += 1;
            };
            room_id += 1;
        };
    }

    #[test]
    fn test_generate_blocked_bitmap_respects_count_cap() {
        // Obstacle count cannot exceed obstacle_count(room_id).
        let seed: felt252 = 'count_stress';
        let mut room_id: u8 = 0;
        while room_id < 25 {
            let bitmap = generate_blocked_bitmap(seed, room_id, 1, 1);
            let placed = popcount_u64(bitmap);
            let expected_cap = obstacle_count(room_id);
            assert!(placed <= expected_cap, "placed more than cap");
            room_id += 1;
        };
    }

    #[test]
    fn test_pick_enemy_position_avoids_blocked_and_spawn() {
        let seed: felt252 = 'place_test';
        let room_id: u8 = 10;
        let blocked = generate_blocked_bitmap(seed, room_id, 1, 1);
        let mut occupancy: u64 = 0;
        occupancy = bitmap::set_bit(occupancy, 1, 1); // player on entry tile

        let mut slot: u8 = 0;
        while slot < 8 {
            let (x, y) = pick_enemy_position(
                seed, room_id, slot, blocked, occupancy, 1, 1,
            );
            assert!(x < 8 && y < 8, "oob enemy spawn");
            assert!(!bitmap::get_bit(blocked, x, y), "enemy on blocked tile");
            assert!(!bitmap::get_bit(occupancy, x, y), "enemy on occupied tile");
            // Not on entry tile
            assert!(!(x == 1 && y == 1), "enemy on entry");
            occupancy = bitmap::set_bit(occupancy, x, y);
            slot += 1;
        };
    }

    // --- orb lifecycle simulation (bitmap semantics, no storage) ---

    #[test]
    fn test_orb_lifecycle_simulation() {
        // Turn N: enemy dies at (3, 4). orb fresh bit set.
        let mut orbs_fresh: u64 = 0;
        let mut orbs_aged: u64 = 0;
        orbs_fresh = bitmap::set_bit(orbs_fresh, 3, 4);
        assert!(bitmap::get_bit(orbs_fresh, 3, 4), "spawn bit set");

        // Same-turn pickup: orb IS collectable.
        let has_orb_n = bitmap::get_bit(orbs_fresh | orbs_aged, 3, 4);
        assert!(has_orb_n, "same-turn collectable");

        // End of enemy phase: rotate (orbs_aged = fresh, fresh = 0).
        orbs_aged = orbs_fresh;
        orbs_fresh = 0;
        assert!(bitmap::get_bit(orbs_aged, 3, 4), "aged after rotation");
        assert!(!bitmap::get_bit(orbs_fresh, 3, 4), "fresh cleared");

        // Turn N+1: still collectable (from aged).
        let has_orb_n1 = bitmap::get_bit(orbs_fresh | orbs_aged, 3, 4);
        assert!(has_orb_n1, "turn N+1 collectable");

        // End of enemy phase N+1: rotate again (no new kills).
        orbs_aged = orbs_fresh;
        orbs_fresh = 0;

        // Turn N+2: expired.
        let has_orb_n2 = bitmap::get_bit(orbs_fresh | orbs_aged, 3, 4);
        assert!(!has_orb_n2, "turn N+2 expired");
    }
}
