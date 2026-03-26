use athanor::v2::systems::movement;
use athanor::v2::systems::phase::{
    SHAPE_SINGLE_TILE, SHAPE_LINE, SHAPE_CONE, SHAPE_CIRCLE, SHAPE_CROSS,
};

pub fn tile_in_shape(
    shape_type: u8,
    param_a: u8,
    param_b: u8,
    param_c: u8,
    x: u8,
    y: u8,
) -> bool {
    if shape_type == SHAPE_SINGLE_TILE {
        return x == param_a && y == param_b;
    };

    if shape_type == SHAPE_LINE {
        return tile_in_line(param_a, param_b, param_c, 3, x, y);
    };

    if shape_type == SHAPE_CONE {
        return tile_in_cone(param_a, param_b, param_c, x, y);
    };

    if shape_type == SHAPE_CIRCLE {
        return tile_in_square_3x3(param_a, param_b, x, y);
    };

    if shape_type == SHAPE_CROSS {
        return tile_in_cross(param_a, param_b, x, y);
    };

    false
}

pub fn tile_in_circle_cross(center_x: u8, center_y: u8, x: u8, y: u8) -> bool {
    tile_in_cross(center_x, center_y, x, y)
}

pub fn tile_in_cross(center_x: u8, center_y: u8, test_x: u8, test_y: u8) -> bool {
    if test_x == center_x && test_y == center_y {
        return true;
    };

    if center_x > 0 && test_x + 1 == center_x && test_y == center_y {
        return true;
    };
    if center_x < 7 && test_x == center_x + 1 && test_y == center_y {
        return true;
    };
    if center_y > 0 && test_y + 1 == center_y && test_x == center_x {
        return true;
    };
    if center_y < 7 && test_y == center_y + 1 && test_x == center_x {
        return true;
    };

    false
}

pub fn tile_in_square_3x3(center_x: u8, center_y: u8, x: u8, y: u8) -> bool {
    let min_x = if center_x > 0 { center_x - 1 } else { center_x };
    let max_x = if center_x < 7 { center_x + 1 } else { center_x };
    let min_y = if center_y > 0 { center_y - 1 } else { center_y };
    let max_y = if center_y < 7 { center_y + 1 } else { center_y };

    x >= min_x && x <= max_x && y >= min_y && y <= max_y
}

pub fn tile_in_line(origin_x: u8, origin_y: u8, direction: u8, max_len: u8, x: u8, y: u8) -> bool {
    let mut cur_x = origin_x;
    let mut cur_y = origin_y;
    let mut step: u8 = 0;

    while step < max_len {
        let (next_x, next_y, ok) = movement::step_in_direction(cur_x, cur_y, direction);
        if !ok {
            break;
        };

        if next_x == x && next_y == y {
            return true;
        };

        cur_x = next_x;
        cur_y = next_y;
        step += 1;
    };

    false
}

pub fn tile_in_cone(origin_x: u8, origin_y: u8, direction: u8, x: u8, y: u8) -> bool {
    if direction == 0 {
        if origin_y == 0 {
            return false;
        };
        let y1 = origin_y - 1;
        if x == origin_x && y == y1 {
            return true;
        };
        if origin_x > 0 && x + 1 == origin_x && y == y1 {
            return true;
        };
        if origin_x < 7 && x == origin_x + 1 && y == y1 {
            return true;
        };
        return false;
    };

    if direction == 1 {
        if origin_x >= 7 {
            return false;
        };
        let x1 = origin_x + 1;
        if x == x1 && y == origin_y {
            return true;
        };
        if origin_y > 0 && x == x1 && y + 1 == origin_y {
            return true;
        };
        if origin_y < 7 && x == x1 && y == origin_y + 1 {
            return true;
        };
        return false;
    };

    if direction == 2 {
        if origin_y >= 7 {
            return false;
        };
        let y1 = origin_y + 1;
        if x == origin_x && y == y1 {
            return true;
        };
        if origin_x > 0 && x + 1 == origin_x && y == y1 {
            return true;
        };
        if origin_x < 7 && x == origin_x + 1 && y == y1 {
            return true;
        };
        return false;
    };

    if direction == 3 {
        if origin_x == 0 {
            return false;
        };
        let x1 = origin_x - 1;
        if x == x1 && y == origin_y {
            return true;
        };
        if origin_y > 0 && x == x1 && y + 1 == origin_y {
            return true;
        };
        if origin_y < 7 && x == x1 && y == origin_y + 1 {
            return true;
        };
        return false;
    };

    false
}
