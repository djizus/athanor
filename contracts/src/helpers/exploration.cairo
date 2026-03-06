use athanor::constants;
use athanor::helpers::random::{Random, RandomTrait};
use athanor::types;

#[derive(Copy, Drop)]
pub struct TickEvent {
    pub depth: u16,
    pub zone_id: u8,
    pub event_kind: u8,
    pub value: u16,
    pub hp_after: u16,
}

#[derive(Drop)]
pub struct ExpeditionResult {
    pub death_depth: u16,
    pub gold: u32,
    pub events: Array<TickEvent>,
    pub ingredient_counts: Array<u16>,
    pub remaining_hp: u16,
}

fn get_zone(depth: u16) -> u8 {
    if depth < constants::ZONE_1_DEPTH {
        0
    } else if depth < constants::ZONE_2_DEPTH {
        1
    } else {
        2
    }
}

fn get_drain(zone_id: u8) -> u32 {
    if zone_id == 0 {
        constants::ZONE_0_DRAIN.into()
    } else if zone_id == 1 {
        constants::ZONE_1_DRAIN.into()
    } else {
        constants::ZONE_2_DRAIN.into()
    }
}

fn get_event_thresholds(zone_id: u8) -> (u16, u16, u16, u16) {
    if zone_id == 0 {
        let trap = constants::ZONE_0_TRAP;
        let gold = trap + constants::ZONE_0_GOLD;
        let heal = gold + constants::ZONE_0_HEAL;
        let beast = heal + constants::ZONE_0_BEAST;
        (trap, gold, heal, beast)
    } else if zone_id == 1 {
        let trap = constants::ZONE_1_TRAP;
        let gold = trap + constants::ZONE_1_GOLD;
        let heal = gold + constants::ZONE_1_HEAL;
        let beast = heal + constants::ZONE_1_BEAST;
        (trap, gold, heal, beast)
    } else {
        let trap = constants::ZONE_2_TRAP;
        let gold = trap + constants::ZONE_2_GOLD;
        let heal = gold + constants::ZONE_2_HEAL;
        let beast = heal + constants::ZONE_2_BEAST;
        (trap, gold, heal, beast)
    }
}

fn get_drop_chance(zone_id: u8) -> u16 {
    if zone_id == 0 {
        constants::ZONE_0_DROP
    } else if zone_id == 1 {
        constants::ZONE_1_DROP
    } else {
        constants::ZONE_2_DROP
    }
}

fn trap_damage_range(zone_id: u8) -> (u32, u32) {
    if zone_id == 0 {
        (300, 800)
    } else if zone_id == 1 {
        (500, 1200)
    } else {
        (800, 1800)
    }
}

fn gold_reward_range(zone_id: u8) -> (u32, u32) {
    if zone_id == 0 {
        (200, 500)
    } else if zone_id == 1 {
        (400, 1000)
    } else {
        (600, 1500)
    }
}

fn heal_amount_range(zone_id: u8) -> (u32, u32) {
    if zone_id == 0 {
        (300, 600)
    } else if zone_id == 1 {
        (400, 800)
    } else {
        (500, 1000)
    }
}

fn beast_power_range(zone_id: u8) -> (u32, u32) {
    if zone_id == 0 {
        (200, 500)
    } else if zone_id == 1 {
        (500, 1000)
    } else {
        (800, 1600)
    }
}

fn beast_loot_range(zone_id: u8) -> (u32, u32) {
    if zone_id == 0 {
        (500, 1000)
    } else if zone_id == 1 {
        (800, 1800)
    } else {
        (1200, 2500)
    }
}

fn roll_range(ref rng: Random, min: u32, max: u32) -> u32 {
    if max <= min {
        return min;
    }
    min + rng.next_bounded(max - min + 1)
}

fn clamp_u16(val: u32) -> u16 {
    if val > 0xFFFF {
        0xFFFF
    } else {
        val.try_into().unwrap()
    }
}

fn set_at(arr: Array<u16>, index: u32, value: u16) -> Array<u16> {
    let mut result: Array<u16> = array![];
    let len = arr.len();
    let mut i: u32 = 0;
    loop {
        if i >= len {
            break;
        }
        if i == index {
            result.append(value);
        } else {
            result.append(*arr.at(i));
        }
        i += 1;
    };
    result
}

pub fn simulate_expedition(
    hp: u16, max_hp: u16, power: u16, seed: felt252,
) -> ExpeditionResult {
    let mut rng = Random { seed, nonce: 0 };
    let mut current_hp: u32 = hp.into();
    let hero_max_hp: u32 = max_hp.into();
    let hero_power: u32 = power.into();
    let mut depth: u16 = 0;
    let mut gold: u32 = 0;
    let mut events: Array<TickEvent> = array![];
    let mut ingredient_counts: Array<u16> = array![0, 0, 0, 0, 0, 0, 0, 0, 0];

    let max_depth: u16 = 300;

    loop {
        if depth >= max_depth {
            break;
        }

        let zone_id = get_zone(depth);
        let drain = get_drain(zone_id);

        if current_hp <= drain {
            events
                .append(
                    TickEvent {
                        depth, zone_id, event_kind: types::EVENT_NOTHING, value: 0, hp_after: 0,
                    },
                );
            break;
        }
        current_hp -= drain;

        let event_roll: u16 = rng.next_bounded(10000).try_into().unwrap();
        let (trap_t, gold_t, heal_t, beast_t) = get_event_thresholds(zone_id);

        let mut event_kind: u8 = types::EVENT_NOTHING;
        let mut event_value: u16 = 0;

        if event_roll < trap_t {
            let (tmin, tmax) = trap_damage_range(zone_id);
            let dmg = roll_range(ref rng, tmin, tmax);
            if current_hp <= dmg {
                current_hp = 0;
            } else {
                current_hp -= dmg;
            }
            event_kind = types::EVENT_TRAP;
            event_value = clamp_u16(dmg);
        } else if event_roll < gold_t {
            let (gmin, gmax) = gold_reward_range(zone_id);
            let amount = roll_range(ref rng, gmin, gmax);
            gold += amount;
            event_kind = types::EVENT_GOLD;
            event_value = clamp_u16(amount);
        } else if event_roll < heal_t {
            let (hmin, hmax) = heal_amount_range(zone_id);
            let amount = roll_range(ref rng, hmin, hmax);
            current_hp += amount;
            if current_hp > hero_max_hp {
                current_hp = hero_max_hp;
            }
            event_kind = types::EVENT_HEAL;
            event_value = clamp_u16(amount);
        } else if event_roll < beast_t {
            let (bmin, bmax) = beast_power_range(zone_id);
            let beast_pow = roll_range(ref rng, bmin, bmax);

            if hero_power >= beast_pow {
                let (lmin, lmax) = beast_loot_range(zone_id);
                let loot = roll_range(ref rng, lmin, lmax);
                gold += loot;
                let combat_dmg = loot / 5;
                if current_hp <= combat_dmg {
                    current_hp = 0;
                } else {
                    current_hp -= combat_dmg;
                }
                event_kind = types::EVENT_BEAST_WIN;
                event_value = clamp_u16(loot);
            } else {
                let dmg = beast_pow - hero_power;
                if current_hp <= dmg {
                    current_hp = 0;
                } else {
                    current_hp -= dmg;
                }
                event_kind = types::EVENT_BEAST_LOSE;
                event_value = clamp_u16(dmg);
            }
        }

        let hp_after = clamp_u16(current_hp);

        if event_kind != types::EVENT_NOTHING {
            events
                .append(TickEvent { depth, zone_id, event_kind, value: event_value, hp_after });
        }

        let drop_roll: u16 = rng.next_bounded(10000).try_into().unwrap();
        let drop_chance = get_drop_chance(zone_id);

        if drop_roll < drop_chance {
            let zone_base: u8 = zone_id * constants::INGREDIENTS_PER_ZONE;
            let offset: u8 = rng
                .next_bounded(constants::INGREDIENTS_PER_ZONE.into())
                .try_into()
                .unwrap();
            let ingredient_id: u8 = zone_base + offset;

            let current_qty = *ingredient_counts.at(ingredient_id.into());
            ingredient_counts = set_at(ingredient_counts, ingredient_id.into(), current_qty + 1);

            events
                .append(
                    TickEvent {
                        depth,
                        zone_id,
                        event_kind: types::EVENT_INGREDIENT,
                        value: ingredient_id.into(),
                        hp_after,
                    },
                );
        }

        if current_hp == 0 {
            break;
        }

        depth += 1;
    };

    ExpeditionResult {
        death_depth: depth, gold, events, ingredient_counts, remaining_hp: clamp_u16(current_hp),
    }
}
