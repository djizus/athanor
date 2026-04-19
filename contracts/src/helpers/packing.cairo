// Bit-manipulation helpers for packed Dojo storage. Cairo 2.x doesn't expose
// a clean `<<`/`>>` on u64 by default, so we emulate via multiplication /
// division with a power-of-two lookup. The pattern matches
// `athanor::helpers::bitmap::pow2` — kept as a separate module so packing
// helpers can be reused by any packed model without pulling in bitmap's
// tile-oriented signatures.

pub fn shl64(value: u64, bits: u8) -> u64 {
    value * pow2_u64(bits)
}

pub fn shr64(value: u64, bits: u8) -> u64 {
    value / pow2_u64(bits)
}

pub fn pow2_u64(n: u8) -> u64 {
    if n == 0 {
        return 1;
    }
    let mut result: u64 = 1;
    let mut i: u8 = 0;
    while i < n {
        result = result * 2;
        i += 1;
    };
    result
}
