use athanor::v2::constants::{
    STRIKE_COST, STRIKE_COOLDOWN, DASH_COST, DASH_COOLDOWN, CLEAVE_COST, CLEAVE_COOLDOWN,
    FIREBALL_COST, FIREBALL_COOLDOWN, GUARD_COST, GUARD_COOLDOWN,
};
use athanor::v2::systems::phase::{
    ABILITY_STRIKE, ABILITY_DASH, ABILITY_CLEAVE, ABILITY_FIREBALL, ABILITY_GUARD, TARGET_SINGLE,
    TARGET_DIRECTIONAL, TARGET_POSITIONAL, TARGET_SELF,
};

pub fn ability_cost(ability_id: u8) -> u16 {
    if ability_id == ABILITY_STRIKE {
        return STRIKE_COST;
    };
    if ability_id == ABILITY_DASH {
        return DASH_COST;
    };
    if ability_id == ABILITY_CLEAVE {
        return CLEAVE_COST;
    };
    if ability_id == ABILITY_FIREBALL {
        return FIREBALL_COST;
    };
    if ability_id == ABILITY_GUARD {
        return GUARD_COST;
    };
    0
}

pub fn ability_cooldown(ability_id: u8) -> u8 {
    if ability_id == ABILITY_STRIKE {
        return STRIKE_COOLDOWN;
    };
    if ability_id == ABILITY_DASH {
        return DASH_COOLDOWN;
    };
    if ability_id == ABILITY_CLEAVE {
        return CLEAVE_COOLDOWN;
    };
    if ability_id == ABILITY_FIREBALL {
        return FIREBALL_COOLDOWN;
    };
    if ability_id == ABILITY_GUARD {
        return GUARD_COOLDOWN;
    };
    0
}

pub fn expected_target_mode(ability_id: u8) -> u8 {
    if ability_id == ABILITY_STRIKE {
        return TARGET_SINGLE;
    };
    if ability_id == ABILITY_DASH {
        return TARGET_DIRECTIONAL;
    };
    if ability_id == ABILITY_CLEAVE {
        return TARGET_DIRECTIONAL;
    };
    if ability_id == ABILITY_FIREBALL {
        return TARGET_POSITIONAL;
    };
    TARGET_SELF
}

pub fn compute_damage_with_stats(
    base_damage: u16, attacker_offense: u8, target_defense: u8, target_guard_active: bool,
) -> u16 {
    let offense_u16: u16 = attacker_offense.into();
    let defense_u16: u16 = target_defense.into();
    let mut damage = if base_damage + offense_u16 > defense_u16 {
        base_damage + offense_u16 - defense_u16
    } else {
        1_u16
    };

    if target_guard_active {
        damage = damage / 2;
        if damage == 0 {
            damage = 1;
        };
    };

    if damage == 0 {
        1
    } else {
        damage
    }
}

pub fn compute_telegraph_damage(base_damage: u16, target_defense: u8, target_guard_active: bool) -> u16 {
    let defense_u16: u16 = target_defense.into();
    let mut damage = if base_damage > defense_u16 {
        base_damage - defense_u16
    } else {
        1_u16
    };

    if target_guard_active {
        damage = damage / 2;
        if damage == 0 {
            damage = 1;
        };
    };

    if damage == 0 {
        1
    } else {
        damage
    }
}
