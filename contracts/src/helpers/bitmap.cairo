pub fn get_bit(bitmap: u64, x: u8, y: u8) -> bool {
    if !is_in_bounds(x, y) {
        return false;
    };

    let bit_index: u64 = y.into() * 8_u64 + x.into();
    let mask: u64 = shl(1_u64, bit_index);
    bitmap & mask != 0
}

pub fn set_bit(bitmap: u64, x: u8, y: u8) -> u64 {
    if !is_in_bounds(x, y) {
        return bitmap;
    };

    let bit_index: u64 = y.into() * 8_u64 + x.into();
    let mask: u64 = shl(1_u64, bit_index);
    bitmap | mask
}

pub fn clear_bit(bitmap: u64, x: u8, y: u8) -> u64 {
    if !is_in_bounds(x, y) {
        return bitmap;
    };

    let bit_index: u64 = y.into() * 8_u64 + x.into();
    let mask: u64 = shl(1_u64, bit_index);
    let inv_mask: u64 = mask ^ 0xFFFFFFFFFFFFFFFF;
    bitmap & inv_mask
}

pub fn is_in_bounds(x: u8, y: u8) -> bool {
    x < 8 && y < 8
}

fn shl(value: u64, bits: u64) -> u64 {
    value * pow2(bits)
}

fn pow2(n: u64) -> u64 {
    if n == 0 {
        1
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
