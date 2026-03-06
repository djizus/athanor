#[starknet::interface]
pub trait ICraftingSystem<T> {
    fn craft(ref self: T, game_id: u64, ingredient_a: u8, ingredient_b: u8);
    fn craft_recipe(ref self: T, game_id: u64, recipe_id: u8);
    fn buy_hint(ref self: T, game_id: u64);
}

#[dojo::contract]
pub mod crafting_system {
    use athanor::constants::{self, DEFAULT_NS};
    use athanor::helpers::random::{Random, RandomImpl, RandomTrait};
    use athanor::models::crafting::FailedCombo;
    use athanor::models::game::GameSessionAssertTrait;
    use athanor::models::inventory::PotionItem;
    use athanor::store::{Store, StoreImpl, StoreTrait};
    use core::poseidon::poseidon_hash_span;
    use game_components_minigame::libs::{assert_token_ownership, post_action, pre_action};
    use game_components_token::core::interface::{
        IMinigameTokenDispatcher, IMinigameTokenDispatcherTrait,
    };
    use game_components_token::libs::LifecycleTrait;
    use starknet::get_block_timestamp;
    use super::ICraftingSystem;

    // No Storage needed — token_address and vrf_address come from Config via Store

    fn combo_key(a: u8, b: u8) -> u16 {
        let (lo, hi) = if a < b {
            (a, b)
        } else {
            (b, a)
        };
        lo.into() * constants::TOTAL_INGREDIENTS.into() + hi.into()
    }

    fn check_win(ref store: Store, game_id: u64, timestamp: u64) {
        let mut session = store.session(game_id);
        if session.discovered_count >= constants::RECIPES_TO_DISCOVER {
            session.game_over = true;
            let completion_time = timestamp - session.started_at;
            store.set_session(@session);

            let mut player_meta = store.player(session.player);
            player_meta.total_recipes_discovered += session.discovered_count.into();
            if player_meta.best_time == 0 || completion_time < player_meta.best_time {
                player_meta.best_time = completion_time;
            }
            store.set_player(@player_meta);

            store.emit_grimoire_completed(game_id, session.player, completion_time);
        }
    }

    #[abi(embed_v0)]
    impl CraftingSystemImpl of ICraftingSystem<ContractState> {
        fn craft(ref self: ContractState, game_id: u64, ingredient_a: u8, ingredient_b: u8) {
            let mut store = StoreImpl::new(self.world(@DEFAULT_NS()));
            let token_address = store.token_address();
            let timestamp = get_block_timestamp();

            pre_action(token_address, game_id);

            let token_dispatcher = IMinigameTokenDispatcher { contract_address: token_address };
            assert!(
                token_dispatcher.token_metadata(game_id).lifecycle.is_playable(timestamp),
                "Game not playable",
            );
            assert_token_ownership(token_address, game_id);

            let mut session = store.session(game_id);
            session.assert_not_over();

            assert!(ingredient_a != ingredient_b, "Same ingredient");
            assert!(
                ingredient_a < constants::TOTAL_INGREDIENTS
                    && ingredient_b < constants::TOTAL_INGREDIENTS,
                "Invalid ingredient",
            );

            let (lo, hi) = if ingredient_a < ingredient_b {
                (ingredient_a, ingredient_b)
            } else {
                (ingredient_b, ingredient_a)
            };

            let mut bal_a = store.ingredient(game_id, lo);
            let mut bal_b = store.ingredient(game_id, hi);
            assert!(bal_a.quantity > 0 && bal_b.quantity > 0, "Not enough ingredients");

            bal_a.quantity -= 1;
            bal_b.quantity -= 1;
            store.set_ingredient(@bal_a);
            store.set_ingredient(@bal_b);

            session.craft_attempts += 1;

            let key = combo_key(lo, hi);

            let mut found_recipe: bool = false;
            let mut found_id: u8 = 0;
            let mut r_idx: u8 = 0;
            while r_idx < constants::RECIPES_TO_DISCOVER {
                let recipe = store.recipe(game_id, r_idx);
                if !recipe.discovered && recipe.ingredient_a == lo && recipe.ingredient_b == hi {
                    found_recipe = true;
                    found_id = r_idx;
                    break;
                }
                r_idx += 1;
            }

            if found_recipe {
                let mut recipe = store.recipe(game_id, found_id);
                recipe.discovered = true;
                store.set_recipe(@recipe);

                session.discovered_count += 1;

                let potion_idx = session.potion_count;
                session.potion_count += 1;
                store
                    .set_potion(
                        @PotionItem {
                            game_id,
                            potion_index: potion_idx,
                            recipe_id: found_id,
                            effect_type: recipe.effect_type,
                            effect_value: recipe.effect_value,
                        },
                    );

                store
                    .emit_recipe_discovered(
                        game_id, found_id, lo, hi, recipe.effect_type, session.discovered_count,
                    );

                store.set_session(@session);
                check_win(ref store, game_id, timestamp);
            } else {
                let failed = store.failed_combo(game_id, key);
                if !failed.attempted {
                    store
                        .set_failed_combo(
                            @FailedCombo { game_id, combo_key: key, attempted: true },
                        );
                }

                session.gold += constants::SOUP_GOLD_VALUE.into();
                store.set_session(@session);
            }

            post_action(token_address, game_id);
        }

        fn craft_recipe(ref self: ContractState, game_id: u64, recipe_id: u8) {
            let mut store = StoreImpl::new(self.world(@DEFAULT_NS()));
            let token_address = store.token_address();
            let timestamp = get_block_timestamp();

            pre_action(token_address, game_id);

            let token_dispatcher = IMinigameTokenDispatcher { contract_address: token_address };
            assert!(
                token_dispatcher.token_metadata(game_id).lifecycle.is_playable(timestamp),
                "Game not playable",
            );
            assert_token_ownership(token_address, game_id);

            let mut session = store.session(game_id);
            session.assert_not_over();

            let recipe = store.recipe(game_id, recipe_id);
            assert!(recipe.discovered, "Recipe not discovered");

            let mut bal_a = store.ingredient(game_id, recipe.ingredient_a);
            let mut bal_b = store.ingredient(game_id, recipe.ingredient_b);

            let max_brews = if bal_a.quantity < bal_b.quantity {
                bal_a.quantity
            } else {
                bal_b.quantity
            };
            assert!(max_brews > 0, "Not enough ingredients");

            bal_a.quantity -= max_brews;
            bal_b.quantity -= max_brews;
            store.set_ingredient(@bal_a);
            store.set_ingredient(@bal_b);

            let mut brewed: u16 = 0;
            while brewed < max_brews {
                let potion_idx = session.potion_count;
                session.potion_count += 1;
                store
                    .set_potion(
                        @PotionItem {
                            game_id,
                            potion_index: potion_idx,
                            recipe_id,
                            effect_type: recipe.effect_type,
                            effect_value: recipe.effect_value,
                        },
                    );
                brewed += 1;
            }

            store.set_session(@session);

            post_action(token_address, game_id);
        }

        fn buy_hint(ref self: ContractState, game_id: u64) {
            let mut store = StoreImpl::new(self.world(@DEFAULT_NS()));
            let token_address = store.token_address();
            let timestamp = get_block_timestamp();

            pre_action(token_address, game_id);

            let token_dispatcher = IMinigameTokenDispatcher { contract_address: token_address };
            assert!(
                token_dispatcher.token_metadata(game_id).lifecycle.is_playable(timestamp),
                "Game not playable",
            );
            assert_token_ownership(token_address, game_id);

            let mut session = store.session(game_id);
            session.assert_not_over();

            // Cost = hint_base_cost * hint_cost_multiplier^hints_used
            let mut cost: u32 = constants::HINT_BASE_COST.into();
            let mut i: u8 = 0;
            while i < session.hints_used {
                cost *= constants::HINT_COST_MULTIPLIER.into();
                i += 1;
            }
            assert!(session.gold >= cost, "Not enough gold");

            session.gold -= cost;
            session.hints_used += 1;

            // VRF per hint — unique salt from game_id + hints_used + timestamp
            let vrf_addr = store.vrf_address();
            let salt = poseidon_hash_span(
                array![game_id.into(), session.hints_used.into(), timestamp.into()].span(),
            );
            let random = RandomImpl::from_vrf_address(vrf_addr, salt);
            let mut rng = Random { seed: random.seed, nonce: 0 };

            let undiscovered_count = constants::RECIPES_TO_DISCOVER - session.discovered_count;
            assert!(undiscovered_count > 0, "All recipes discovered");

            let target_idx: u8 = rng.next_bounded(undiscovered_count.into()).try_into().unwrap();
            let mut skip: u8 = 0;
            let mut hinted_recipe_id: u8 = 0;
            let mut r_idx: u8 = 0;
            while r_idx < constants::RECIPES_TO_DISCOVER {
                let recipe = store.recipe(game_id, r_idx);
                if !recipe.discovered {
                    if skip == target_idx {
                        hinted_recipe_id = r_idx;
                        break;
                    }
                    skip += 1;
                }
                r_idx += 1;
            }

            let hinted = store.recipe(game_id, hinted_recipe_id);

            // Reveal ingredient_a (client shows this as the hint)
            store
                .emit_recipe_discovered(
                    game_id,
                    hinted_recipe_id,
                    hinted.ingredient_a,
                    255, // 255 = hidden (hint only reveals one ingredient)
                    hinted.effect_type,
                    session.discovered_count,
                );

            store.set_session(@session);

            post_action(token_address, game_id);
        }
    }
}
