use dojo::model::ModelStorage;
use dojo::world::WorldStorage;
use athanor::models::recipe::Recipe;
use athanor::helpers::random::{Random, RandomTrait};
use athanor::constants;

// combo_key for a sorted pair (a < b): a * TOTAL_INGREDIENTS + b
// Max value: 8 * 9 + 8 = 80, fits in u16
fn combo_key(a: u8, b: u8) -> u16 {
    a.into() * constants::TOTAL_INGREDIENTS.into() + b.into()
}

fn effect_value_for_type(ref rng: Random, effect_type: u8) -> u8 {
    match effect_type {
        0 => 5 + rng.next_bounded(16).try_into().unwrap(), // max_hp: 5-20
        1 => 1 + rng.next_bounded(5).try_into().unwrap(),  // power: 1-5
        2 => 1 + rng.next_bounded(3).try_into().unwrap(),  // regen: 1-3
        _ => 1,
    }
}

// Generate 10 recipes deterministically from seed and write them to the world.
//
// Phase 1 (pinned): 1 recipe per zone using intra-zone ingredients.
//   Guarantees every zone must be explored to complete the grimoire.
// Phase 2 (fill): 7 random cross-zone-biased pairs to reach 10 total.
//   Effect types cycle through max_hp/power/regen with 70% deterministic bias.
pub fn generate_recipes(ref world: WorldStorage, game_id: u64, seed: felt252) {
    let mut rng = Random { seed, nonce: 0 };
    let mut recipe_count: u8 = 0;

    // Track used pairs via a simple array (max 10 entries, linear scan is fine)
    let mut used_keys: Array<u16> = array![];

    // Phase 1: one pinned recipe per zone (3 recipes)
    let mut zone: u8 = 0;
    while zone < constants::ZONE_COUNT {
        let base: u8 = zone * constants::INGREDIENTS_PER_ZONE;

        // Pick two distinct ingredients within this zone
        let offset_a = rng.next_bounded(constants::INGREDIENTS_PER_ZONE.into()).try_into().unwrap();
        let mut offset_b = rng
            .next_bounded(constants::INGREDIENTS_PER_ZONE.into())
            .try_into()
            .unwrap();
        if offset_a == offset_b {
            offset_b = (offset_a + 1) % constants::INGREDIENTS_PER_ZONE;
        }

        let raw_a: u8 = base + offset_a;
        let raw_b: u8 = base + offset_b;
        let (a, b) = if raw_a < raw_b {
            (raw_a, raw_b)
        } else {
            (raw_b, raw_a)
        };

        let key = combo_key(a, b);
        used_keys.append(key);

        let effect_type: u8 = recipe_count % 3;
        let effect_value = effect_value_for_type(ref rng, effect_type);

        world
            .write_model(
                @Recipe {
                    game_id,
                    recipe_id: recipe_count,
                    ingredient_a: a,
                    ingredient_b: b,
                    effect_type,
                    effect_value,
                    discovered: false,
                },
            );

        recipe_count += 1;
        zone += 1;
    };

    // Phase 2: fill remaining 7 recipes with random (cross-zone biased) pairs
    let mut attempts: u16 = 0;
    while recipe_count < constants::RECIPES_TO_DISCOVER && attempts < 500 {
        attempts += 1;

        let a_raw: u8 = rng.next_bounded(constants::TOTAL_INGREDIENTS.into()).try_into().unwrap();
        let b_raw: u8 = rng.next_bounded(constants::TOTAL_INGREDIENTS.into()).try_into().unwrap();
        if a_raw == b_raw {
            continue;
        }

        let (a, b) = if a_raw < b_raw {
            (a_raw, b_raw)
        } else {
            (b_raw, a_raw)
        };

        let key = combo_key(a, b);

        // Check if already used
        if is_key_used(@used_keys, key) {
            continue;
        }

        // Bias toward cross-zone: skip same-zone pairs 50% of the time
        let zone_a = a / constants::INGREDIENTS_PER_ZONE;
        let zone_b = b / constants::INGREDIENTS_PER_ZONE;
        if zone_a == zone_b && rng.next_bounded(2) == 0 {
            continue;
        }

        used_keys.append(key);

        // Effect type: 70% cycled, 30% random
        let base_type: u8 = recipe_count % 3;
        let effect_type = if rng.next_bounded(10) < 7 {
            base_type
        } else {
            rng.next_bounded(3).try_into().unwrap()
        };
        let effect_value = effect_value_for_type(ref rng, effect_type);

        world
            .write_model(
                @Recipe {
                    game_id,
                    recipe_id: recipe_count,
                    ingredient_a: a,
                    ingredient_b: b,
                    effect_type,
                    effect_value,
                    discovered: false,
                },
            );

        recipe_count += 1;
    };

    assert!(
        recipe_count == constants::RECIPES_TO_DISCOVER,
        "Failed to generate all recipes (got {}, need {})",
        recipe_count,
        constants::RECIPES_TO_DISCOVER,
    );
}

fn is_key_used(keys: @Array<u16>, key: u16) -> bool {
    let mut i: u32 = 0;
    let len = keys.len();
    loop {
        if i >= len {
            break false;
        }
        if *keys.at(i) == key {
            break true;
        }
        i += 1;
    }
}
