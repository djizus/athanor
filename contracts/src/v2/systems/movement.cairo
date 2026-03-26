use athanor::v2::helpers::bitmap;

pub fn abs_diff_u8(a: u8, b: u8) -> u8 {
    if a >= b {
        a - b
    } else {
        b - a
    }
}

pub fn manhattan_distance(ax: u8, ay: u8, bx: u8, by: u8) -> u8 {
    abs_diff_u8(ax, bx) + abs_diff_u8(ay, by)
}

pub fn in_bounds(x: u8, y: u8) -> bool {
    bitmap::is_in_bounds(x, y)
}

pub fn step_in_direction(x: u8, y: u8, direction: u8) -> (u8, u8, bool) {
    if direction == 0 {
        if y == 0 {
            return (x, y, false);
        };
        return (x, y - 1, true);
    };

    if direction == 1 {
        if x >= 7 {
            return (x, y, false);
        };
        return (x + 1, y, true);
    };

    if direction == 2 {
        if y >= 7 {
            return (x, y, false);
        };
        return (x, y + 1, true);
    };

    if direction == 3 {
        if x == 0 {
            return (x, y, false);
        };
        return (x - 1, y, true);
    };

    (x, y, false)
}
