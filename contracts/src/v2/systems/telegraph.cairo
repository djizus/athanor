use athanor::v2::systems::movement;
use athanor::v2::systems::phase::{SHAPE_SINGLE_TILE, SHAPE_LINE, SHAPE_CONE, SHAPE_CIRCLE};

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
        return tile_in_circle_cross(param_a, param_b, x, y);
    };

    false
}

pub fn tile_in_circle_cross(center_x: u8, center_y: u8, x: u8, y: u8) -> bool {
    if x == center_x && y == center_y {
        return true;
    };

    if center_x > 0 && x + 1 == center_x && y == center_y {
        return true;
    };
    if center_x < 7 && x == center_x + 1 && y == center_y {
        return true;
    };
    if center_y > 0 && y + 1 == center_y && x == center_x {
        return true;
    };
    if center_y < 7 && y == center_y + 1 && x == center_x {
        return true;
    };

    false
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
