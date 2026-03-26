use athanor::helpers::bitmap;
use athanor::systems::movement;

pub fn choose_step_toward(
    from_x: u8,
    from_y: u8,
    to_x: u8,
    to_y: u8,
    blocked: u64,
    occupancy_without_self: u64,
) -> (u8, u8, bool) {
    let dx = movement::abs_diff_u8(to_x, from_x);
    let dy = movement::abs_diff_u8(to_y, from_y);

    if movement::manhattan_distance(from_x, from_y, to_x, to_y) <= 1 {
        return (from_x, from_y, false);
    };

    let prefer_x = dx >= dy;
    if prefer_x {
        let (x1, y1, ok1) = toward_x(from_x, from_y, to_x);
        if ok1 && can_move_to(x1, y1, blocked, occupancy_without_self) {
            return (x1, y1, true);
        };

        let (x2, y2, ok2) = toward_y(from_x, from_y, to_y);
        if ok2 && can_move_to(x2, y2, blocked, occupancy_without_self) {
            return (x2, y2, true);
        };
    } else {
        let (x1, y1, ok1) = toward_y(from_x, from_y, to_y);
        if ok1 && can_move_to(x1, y1, blocked, occupancy_without_self) {
            return (x1, y1, true);
        };

        let (x2, y2, ok2) = toward_x(from_x, from_y, to_x);
        if ok2 && can_move_to(x2, y2, blocked, occupancy_without_self) {
            return (x2, y2, true);
        };
    };

    (from_x, from_y, false)
}

pub fn choose_step_toward_exact(
    from_x: u8,
    from_y: u8,
    to_x: u8,
    to_y: u8,
    blocked: u64,
    occupancy_without_self: u64,
) -> (u8, u8, bool) {
    let dx = movement::abs_diff_u8(to_x, from_x);
    let dy = movement::abs_diff_u8(to_y, from_y);
    let prefer_x = dx >= dy;

    if prefer_x {
        let (x1, y1, ok1) = toward_x(from_x, from_y, to_x);
        if ok1 && can_move_to(x1, y1, blocked, occupancy_without_self) {
            return (x1, y1, true);
        };

        let (x2, y2, ok2) = toward_y(from_x, from_y, to_y);
        if ok2 && can_move_to(x2, y2, blocked, occupancy_without_self) {
            return (x2, y2, true);
        };
    } else {
        let (x1, y1, ok1) = toward_y(from_x, from_y, to_y);
        if ok1 && can_move_to(x1, y1, blocked, occupancy_without_self) {
            return (x1, y1, true);
        };

        let (x2, y2, ok2) = toward_x(from_x, from_y, to_x);
        if ok2 && can_move_to(x2, y2, blocked, occupancy_without_self) {
            return (x2, y2, true);
        };
    };

    (from_x, from_y, false)
}

pub fn choose_step_away(
    from_x: u8,
    from_y: u8,
    player_x: u8,
    player_y: u8,
    blocked: u64,
    occupancy_without_self: u64,
) -> (u8, u8, bool) {
    let dx = movement::abs_diff_u8(player_x, from_x);
    let dy = movement::abs_diff_u8(player_y, from_y);
    let dist = movement::manhattan_distance(from_x, from_y, player_x, player_y);

    if dist >= 3 {
        return (from_x, from_y, false);
    };

    let prefer_x = dx >= dy;
    if prefer_x {
        let (x1, y1, ok1) = away_x(from_x, from_y, player_x);
        if ok1 && can_move_to(x1, y1, blocked, occupancy_without_self) {
            return (x1, y1, true);
        };

        let (x2, y2, ok2) = away_y(from_x, from_y, player_y);
        if ok2 && can_move_to(x2, y2, blocked, occupancy_without_self) {
            return (x2, y2, true);
        };
    } else {
        let (x1, y1, ok1) = away_y(from_x, from_y, player_y);
        if ok1 && can_move_to(x1, y1, blocked, occupancy_without_self) {
            return (x1, y1, true);
        };

        let (x2, y2, ok2) = away_x(from_x, from_y, player_x);
        if ok2 && can_move_to(x2, y2, blocked, occupancy_without_self) {
            return (x2, y2, true);
        };
    };

    (from_x, from_y, false)
}

fn can_move_to(x: u8, y: u8, blocked: u64, occupancy: u64) -> bool {
    movement::in_bounds(x, y) && !bitmap::get_bit(blocked, x, y) && !bitmap::get_bit(occupancy, x, y)
}

fn toward_x(from_x: u8, from_y: u8, to_x: u8) -> (u8, u8, bool) {
    if to_x > from_x {
        if from_x >= 7 {
            return (from_x, from_y, false);
        };
        return (from_x + 1, from_y, true);
    };

    if to_x < from_x {
        if from_x == 0 {
            return (from_x, from_y, false);
        };
        return (from_x - 1, from_y, true);
    };

    (from_x, from_y, false)
}

fn toward_y(from_x: u8, from_y: u8, to_y: u8) -> (u8, u8, bool) {
    if to_y > from_y {
        if from_y >= 7 {
            return (from_x, from_y, false);
        };
        return (from_x, from_y + 1, true);
    };

    if to_y < from_y {
        if from_y == 0 {
            return (from_x, from_y, false);
        };
        return (from_x, from_y - 1, true);
    };

    (from_x, from_y, false)
}

fn away_x(from_x: u8, from_y: u8, player_x: u8) -> (u8, u8, bool) {
    if from_x >= player_x {
        if from_x >= 7 {
            return (from_x, from_y, false);
        };
        return (from_x + 1, from_y, true);
    };

    if from_x > 0 {
        return (from_x - 1, from_y, true);
    };

    (from_x, from_y, false)
}

fn away_y(from_x: u8, from_y: u8, player_y: u8) -> (u8, u8, bool) {
    if from_y >= player_y {
        if from_y >= 7 {
            return (from_x, from_y, false);
        };
        return (from_x, from_y + 1, true);
    };

    if from_y > 0 {
        return (from_x, from_y - 1, true);
    };

    (from_x, from_y, false)
}
