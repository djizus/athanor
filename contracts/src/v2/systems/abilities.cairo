use athanor::v2::constants::{
    STRIKE_COST, STRIKE_COOLDOWN, DASH_COST, DASH_COOLDOWN, HEAL_COST, HEAL_COOLDOWN, SHOVE_COST,
    SHOVE_COOLDOWN, SLAM_COST, SLAM_COOLDOWN,
};
use athanor::v2::systems::phase::{
    ABILITY_STRIKE, ABILITY_DASH, ABILITY_HEAL, ABILITY_SHOVE, ABILITY_SLAM, TARGET_SINGLE,
    TARGET_DIRECTIONAL, TARGET_SELF,
};

pub fn ability_cost(ability_id: u8) -> u16 {
    if ability_id == ABILITY_STRIKE {
        return STRIKE_COST;
    };
    if ability_id == ABILITY_DASH {
        return DASH_COST;
    };
    if ability_id == ABILITY_HEAL {
        return HEAL_COST;
    };
    if ability_id == ABILITY_SHOVE {
        return SHOVE_COST;
    };
    if ability_id == ABILITY_SLAM {
        return SLAM_COST;
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
    if ability_id == ABILITY_HEAL {
        return HEAL_COOLDOWN;
    };
    if ability_id == ABILITY_SHOVE {
        return SHOVE_COOLDOWN;
    };
    if ability_id == ABILITY_SLAM {
        return SLAM_COOLDOWN;
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
    if ability_id == ABILITY_HEAL {
        return TARGET_SELF;
    };
    if ability_id == ABILITY_SHOVE {
        return TARGET_SINGLE;
    };
    TARGET_SELF
}

pub fn compute_damage_with_stats(
    base_damage: u16, attacker_offense: u8, target_defense: u8,
) -> u16 {
    let offense_u16: u16 = attacker_offense.into();
    let defense_u16: u16 = target_defense.into();
    let damage = if base_damage + offense_u16 > defense_u16 {
        base_damage + offense_u16 - defense_u16
    } else {
        1_u16
    };

    if damage == 0 {
        1
    } else {
        damage
    }
}

pub fn compute_telegraph_damage(base_damage: u16, target_defense: u8) -> u16 {
    let defense_u16: u16 = target_defense.into();
    let damage = if base_damage > defense_u16 {
        base_damage - defense_u16
    } else {
        1_u16
    };

    if damage == 0 {
        1
    } else {
        damage
    }
}
