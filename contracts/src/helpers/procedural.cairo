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
pub const ARCH_DRAINER: u8 = 6;
pub const ARCH_MARKSMAN: u8 = 7;

/// Number of enemies to spawn in a room (capped at 8).
pub fn enemy_count(room_id: u8) -> u8 {
    if room_id == 0 {
        3
    } else if room_id <= 2 {
        4
    } else if room_id <= 5 {
        5
    } else if room_id <= 9 {
        6
    } else if room_id <= 13 {
        7
    } else {
        8
    }
}

/// Number of static obstacles (capped at 16).
pub fn obstacle_count(room_id: u8) -> u8 {
    let n: u16 = 4 + room_id.into() / 2;
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
    if room_id == 0 {
        0
    } else if room_id <= 4 {
        1
    } else if room_id <= 9 {
        2
    } else if room_id <= 15 {
        3
    } else {
        4
    }
}

/// Weights for (Brute, Caster, Flanker, Heavy, Puller, Drainer, Marksman) — always sum to 100.
/// Tier 0 shelters the player from Heavy/Puller/Drainer while still allowing
/// ranged pressure via Caster/Marksman.
pub fn archetype_weights(tier: u8) -> (u8, u8, u8, u8, u8, u8, u8) {
    if tier == 0 {
        (30, 25, 20, 0, 0, 0, 25)
    } else if tier == 1 {
        (20, 20, 15, 10, 10, 0, 25)
    } else if tier == 2 {
        // Drainer introduced at tier 2 once room pressure is already established.
        (10, 15, 15, 15, 15, 10, 20)
    } else if tier == 3 {
        (5, 10, 15, 15, 15, 15, 25)
    } else {
        (5, 8, 12, 15, 18, 17, 25)
    }
}

fn weighted_pick(roll: u8, wb: u8, wc: u8, wf: u8, wh: u8, wp: u8, wd: u8, wm: u8) -> u8 {
    let _ = wm;
    if roll < wb {
        ARCH_BRUTE
    } else if roll < wb + wc {
        ARCH_CASTER
    } else if roll < wb + wc + wf {
        ARCH_FLANKER
    } else if roll < wb + wc + wf + wh {
        ARCH_HEAVY
    } else if roll < wb + wc + wf + wh + wp {
        ARCH_PULLER
    } else if roll < wb + wc + wf + wh + wp + wd {
        ARCH_DRAINER
    } else {
        ARCH_MARKSMAN
    }
}

/// Roll an archetype honoring the tier weight table and per-room caps:
/// at most 2 Pullers, 2 Heavies, and 2 Drainers per room. Rerolls with a
/// rotated seed up to 3 times; falls back to Brute if the caps consistently win.
pub fn roll_archetype_capped(
    seed: felt252,
    room_id: u8,
    slot_index: u8,
    pullers_so_far: u8,
    heavies_so_far: u8,
    drainers_so_far: u8,
) -> u8 {
    let tier = room_tier(room_id);
    let (wb, wc, wf, wh, wp, wd, wm) = archetype_weights(tier);

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
        let candidate = weighted_pick(roll, wb, wc, wf, wh, wp, wd, wm);
        let reject = (candidate == ARCH_PULLER && pullers_so_far >= 2)
            || (candidate == ARCH_HEAVY && heavies_so_far >= 2)
            || (candidate == ARCH_DRAINER && drainers_so_far >= 2);
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
/// POC cuts so strikes feel decisive. Drainer has zero offense: it deals no
/// HP damage, only stamina drain via telegraph resolution.
pub fn archetype_base_stats(archetype: u8) -> (u16, u8, u8, u8, bool) {
    if archetype == ARCH_BRUTE {
        (30, 15, 8, 5, false)
    } else if archetype == ARCH_CASTER {
        (20, 20, 3, 8, false)
    } else if archetype == ARCH_FLANKER {
        (25, 12, 4, 7, false)
    } else if archetype == ARCH_HEAVY {
        (45, 15, 10, 3, true)
    } else if archetype == ARCH_PULLER {
        (22, 0, 5, 6, false)
    } else if archetype == ARCH_DRAINER {
        (22, 0, 4, 6, false)
    } else {
        (18, 20, 2, 7, false) // Marksman (and fallback)
    }
}

/// Piecewise stat multiplier as a percentage (100 = 1.00x baseline). Tuned for
/// short, high-pressure runs: room 10 should already feel like an achievement.
pub fn stat_mult(room_id: u8) -> u16 {
    let r: u16 = room_id.into();
    if room_id <= 2 {
        100 + r * 30
    } else if room_id <= 5 {
        160 + (r - 2) * 55
    } else if room_id <= 9 {
        325 + (r - 5) * 70
    } else if room_id <= 14 {
        605 + (r - 9) * 85
    } else if room_id <= 17 {
        1030 + (r - 14) * 110
    } else {
        1470 + (r - 18) * 140
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
        ARCH_BRUTE, ARCH_CASTER, ARCH_FLANKER, ARCH_HEAVY, ARCH_PULLER, ARCH_DRAINER,
        ARCH_MARKSMAN,
        archetype_base_stats, archetype_weights, enemy_count, obstacle_count, room_tier,
        roll_archetype_capped, scaled_archetype_stats, stat_mult,
    };

    // --- stat_mult curve ---

    #[test]
    fn test_stat_mult_table() {
        // Reference values from the design doc.
        assert!(stat_mult(0) == 100, "room 0");
        assert!(stat_mult(2) == 160, "room 2");
        assert!(stat_mult(3) == 215, "room 3");
        assert!(stat_mult(5) == 325, "room 5");
        assert!(stat_mult(6) == 395, "room 6");
        assert!(stat_mult(7) == 465, "room 7");
        assert!(stat_mult(10) == 690, "room 10");
        assert!(stat_mult(11) == 775, "room 11");
        assert!(stat_mult(12) == 860, "room 12");
        assert!(stat_mult(15) == 1140, "room 15");
        assert!(stat_mult(17) == 1360, "room 17");
        assert!(stat_mult(18) == 1470, "room 18");
        assert!(stat_mult(20) == 1750, "room 20");
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
        assert!(enemy_count(1) == 4 && enemy_count(2) == 4, "rooms 1-2");
        assert!(enemy_count(3) == 5 && enemy_count(5) == 5, "rooms 3-5");
        assert!(enemy_count(6) == 6 && enemy_count(9) == 6, "rooms 6-9");
        assert!(enemy_count(10) == 7 && enemy_count(13) == 7, "rooms 10-13");
        assert!(enemy_count(18) == 8, "room 18");
        assert!(enemy_count(100) == 8, "room 100 capped");
    }

    // --- obstacle_count ---

    #[test]
    fn test_obstacle_count() {
        assert!(obstacle_count(0) == 4, "room 0");
        assert!(obstacle_count(4) == 6, "room 4");
        assert!(obstacle_count(10) == 9, "room 10");
        assert!(obstacle_count(20) == 16, "room 20 at cap");
        assert!(obstacle_count(100) == 16, "room 100 capped");
    }

    // --- tier bands ---

    #[test]
    fn test_room_tier_bands() {
        assert!(room_tier(0) == 0, "tier 0");
        assert!(room_tier(1) == 1 && room_tier(4) == 1, "tier 1");
        assert!(room_tier(5) == 2 && room_tier(9) == 2, "tier 2");
        assert!(room_tier(10) == 3 && room_tier(15) == 3, "tier 3");
        assert!(room_tier(16) == 4 && room_tier(100) == 4, "tier 4");
    }

    // --- archetype weights sum to 100 ---

    #[test]
    fn test_archetype_weights_sum_to_100() {
        let mut tier: u8 = 0;
        while tier < 5 {
        let (b, c, f, h, p, d, m) = archetype_weights(tier);
        let sum: u16 = b.into() + c.into() + f.into() + h.into() + p.into() + d.into() + m.into();
        assert!(sum == 100, "weights don't sum to 100");
            tier += 1;
        };
    }

    #[test]
    fn test_archetype_weights_tier_0_no_hard_archetypes() {
        // Tier 0 must shield the player from Heavy + Puller + Drainer while
        // they learn. Brute/Caster/Flanker only.
        let (_b, _c, _f, h, p, d, _m) = archetype_weights(0);
        assert!(h == 0, "tier 0 Heavy weight");
        assert!(p == 0, "tier 0 Puller weight");
        assert!(d == 0, "tier 0 Drainer weight");
    }

    #[test]
    fn test_archetype_weights_tier_1_introduces_marksman_and_puller() {
        // Tier 1 introduces Heavy, Puller, and steady ranged pressure.
        let (_b, _c, _f, h, p, d, m) = archetype_weights(1);
        assert!(h > 0, "tier 1 Heavy present");
        assert!(p > 0, "tier 1 Puller present");
        assert!(d == 0, "tier 1 Drainer still absent");
        assert!(m > 0, "tier 1 Marksman present");
    }

    #[test]
    fn test_archetype_weights_tier_2_introduces_drainer() {
        // Drainer debuts at tier 2 once the player already handles Pullers.
        let (_b, _c, _f, _h, p, d, m) = archetype_weights(2);
        assert!(p > 0, "tier 2 Puller present");
        assert!(d > 0, "tier 2 Drainer present");
        assert!(m > 0, "tier 2 Marksman present");
    }

    // --- roll_archetype_capped honors caps ---

    #[test]
    fn test_roll_archetype_capped_respects_puller_cap() {
        // If we've already placed 2 Pullers this room, rolling again at
        // high-tier seeds must NOT return another Puller.
        let seed: felt252 = 'test_seed';
        let mut slot: u8 = 0;
        while slot < 20 {
            let result = roll_archetype_capped(seed, 20, slot, 2, 0, 0);
            assert!(result != ARCH_PULLER, "rolled Puller despite cap");
            slot += 1;
        };
    }

    #[test]
    fn test_roll_archetype_capped_respects_heavy_cap() {
        let seed: felt252 = 'test_seed';
        let mut slot: u8 = 0;
        while slot < 20 {
            let result = roll_archetype_capped(seed, 20, slot, 0, 2, 0);
            assert!(result != ARCH_HEAVY, "rolled Heavy despite cap");
            slot += 1;
        };
    }

    #[test]
    fn test_roll_archetype_capped_respects_drainer_cap() {
        let seed: felt252 = 'test_seed';
        let mut slot: u8 = 0;
        while slot < 20 {
            let result = roll_archetype_capped(seed, 20, slot, 0, 0, 2);
            assert!(result != ARCH_DRAINER, "rolled Drainer despite cap");
            slot += 1;
        };
    }

    // --- archetype_base_stats covers all 6 ---

    #[test]
    fn test_archetype_base_stats_all() {
        // POC HP: Brute 30 / Caster 20 / Flanker 25 / Heavy 45 / Puller 22 / Drainer 22 / Marksman 18.
        let (brute_hp, _, _, brute_speed, brute_im) = archetype_base_stats(ARCH_BRUTE);
        assert!(brute_hp == 30 && brute_speed == 5 && !brute_im, "brute");

        let (caster_hp, _, _, caster_speed, _) = archetype_base_stats(ARCH_CASTER);
        assert!(caster_hp == 20 && caster_speed == 8, "caster");

        let (flanker_hp, _, _, flanker_speed, _) = archetype_base_stats(ARCH_FLANKER);
        assert!(flanker_hp == 25 && flanker_speed == 7, "flanker");

        let (heavy_hp, _, heavy_def, _, heavy_im) = archetype_base_stats(ARCH_HEAVY);
        assert!(heavy_hp == 45 && heavy_def == 10 && heavy_im, "heavy immovable");

        let (puller_hp, puller_off, _, _, _) = archetype_base_stats(ARCH_PULLER);
        assert!(puller_hp == 22 && puller_off == 0, "puller zero offense");

        let (drainer_hp, drainer_off, _, _, drainer_im) = archetype_base_stats(ARCH_DRAINER);
        // Drainer deals stamina drain via telegraph, not HP damage: offense=0.
        assert!(drainer_hp == 22 && drainer_off == 0 && !drainer_im, "drainer");

        let (marksman_hp, marksman_off, marksman_def, marksman_speed, marksman_im) = archetype_base_stats(ARCH_MARKSMAN);
        assert!(marksman_hp == 18 && marksman_off == 20 && marksman_def == 2 && marksman_speed == 7 && !marksman_im, "marksman");
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
        // Brute @ room 15 with POC base 30 hp / 15 off: stat_mult = 1140% →
        // hp = 30 * 1140 / 100 = 342, offense = 15 * 1140 / 100 = 171.
        let (hp, off, _, _, _) = scaled_archetype_stats(ARCH_BRUTE, 15);
        assert!(hp == 342, "brute hp room 15");
        assert!(off == 171, "brute offense room 15");
    }

    #[test]
    fn test_scaled_stats_offense_u8_cap() {
        // Puller has 0 base offense → stays 0 at any room.
        let (_, off, _, _, _) = scaled_archetype_stats(ARCH_PULLER, 50);
        assert!(off == 0, "puller offense stays 0");

        // Caster @ room 50: stat_mult = 1470 + 32*140 = 5950, offense = 14 * 5950 / 100 = 833 → clamped to 255.
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
