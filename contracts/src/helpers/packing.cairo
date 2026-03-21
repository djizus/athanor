/// Pack up to 4 mob HPs into a u64.
/// mob 0 = bits 0-15, mob 1 = bits 16-31, mob 2 = bits 32-47, mob 3 = bits 48-63
pub fn pack_mob_healths(mob_count: u8, initial_hp: u16) -> u64 {
    let hp: u64 = initial_hp.into();
    let mut packed: u64 = 0;
    let mut i: u8 = 0;
    while i < mob_count {
        let shift: u64 = (i.into() * 16_u64);
        packed = packed | shl(hp, shift);
        i += 1;
    };
    packed
}

/// Get a single mob's HP from the packed u64.
pub fn get_mob_health(packed: u64, mob_id: u8) -> u16 {
    let shift: u64 = mob_id.into() * 16_u64;
    let mask: u64 = 0xFFFF;
    let val = shr(packed, shift) & mask;
    val.try_into().unwrap()
}

/// Set a single mob's HP in the packed u64.
pub fn set_mob_health(packed: u64, mob_id: u8, hp: u16) -> u64 {
    let shift: u64 = mob_id.into() * 16_u64;
    let mask: u64 = shl(0xFFFF_u64, shift);
    let inv_mask: u64 = mask ^ 0xFFFFFFFFFFFFFFFF;
    let cleared = packed & inv_mask;
    let new_val: u64 = shl(hp.into(), shift);
    cleared | new_val
}

/// Count alive mobs (HP > 0).
pub fn count_alive_mobs(packed: u64, mob_count: u8) -> u8 {
    let mut alive: u8 = 0;
    let mut i: u8 = 0;
    while i < mob_count {
        if get_mob_health(packed, i) > 0 {
            alive += 1;
        };
        i += 1;
    };
    alive
}

// --- Bit shift helpers ---
// Cairo doesn't have << >> operators on u64, so we use multiplication/division by powers of 2.

fn shl(value: u64, bits: u64) -> u64 {
    value * pow2(bits)
}

fn shr(value: u64, bits: u64) -> u64 {
    value / pow2(bits)
}

fn pow2(n: u64) -> u64 {
    if n == 0 {
        1
    } else if n == 16 {
        0x10000
    } else if n == 32 {
        0x100000000
    } else if n == 48 {
        0x1000000000000
    } else {
        let mut result: u64 = 1;
        let mut i: u64 = 0;
        while i < n {
            result = result * 2;
            i += 1;
        };
        result
    }
}


